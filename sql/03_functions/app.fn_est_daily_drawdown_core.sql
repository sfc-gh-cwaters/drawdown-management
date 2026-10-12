CREATE OR REPLACE FUNCTION CYGNET_TRANSFORMATION.APP.FN_EST_DAILY_DRAWDOWN_CORE("TS" TIMESTAMP_NTZ(9), "TP" FLOAT, "P_START_DATE" DATE, "P_END_DATE" DATE)
RETURNS TABLE ("DATE_PERIOD" DATE, "STABLE_AVG_TUBING_PRESSURE" FLOAT, "DELTA_TUBING_PRESSURE" FLOAT, "STABLE_HOURS" FLOAT, "STABLE_SAMPLE_COUNT" NUMBER(38,0), "DELTA_METHOD" VARCHAR, "EXCLUDED_HOURS" FLOAT)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'StableDeclineDrawdown'
COMMENT='Core of FN_EST_DAILY_DRAWDOWN. Call one partition per well, ordered by TS (Central). Excludes surface-driven excursions from tubing pressure, then derives daily drawdown from the stable flowing decline.'
AS '
"""
Author:       Chris Waters
Create Date:  10/05/2026
Description:  Stable-decline daily drawdown estimator (one well per partition).

  1. Hourly level   - median TP per clock hour (Central); hours with < 3 samples dropped.
  2. Rate band      - an hour is "normal" when its change from the previous hour is within
                      median +/- max(K_MAD * MAD, RATE_FLOOR) of the well''s hourly changes over
                      the BAND_DAYS days before that hour''s day (rolling, so results do not
                      depend on the requested date range).
  3. Excursions     - abnormal hours within MERGE_H of each other form one event. Hours are
                      excluded from event start until pressure is back within LEVEL_TOL of the
                      pre-event trend ("recovered") or has held a normal rate for REBASE_H hours
                      ("rebased" - new baseline). Exclusion then continues through the
                      recovery tail: until the trailing TAIL_WIN_H-hour slope is back within
                      max(TAIL_RATE_TOL x |pre-event rate|, TAIL_RATE_FLOOR) of the pre-event
                      rate (capped at TAIL_MAX_H after settling), plus SETTLE_H hours.
  4. Clean hours    - normal-rate, non-excluded hours. Runs < MIN_RUN_H, or runs rising faster
                      than MAX_RUN_SLOPE psi/hr, are dropped.
  5. Daily level    - Theil-Sen line through the day''s clean hours evaluated at 12:00
                      (STABLE_AVG_TUBING_PRESSURE). Needs >= MIN_DAY_H clean hours.
  6. Daily delta    - DELTA_METHOD = ''LEVEL'': prior noon level - today''s noon level, used only
                      when no rebasing event starts between the first clean hour behind the
                      prior level and the last clean hour behind today''s (same baseline).
                      Otherwise ''SLOPE'': -24 x pooled within-run slope of today''s clean runs,
                      only when its standard error <= SLOPE_MAX_SE psi/day (else NULL).
                      Positive = pressure decline.

  Callers should supply ~21 days of readings before P_START_DATE so the rolling rate band,
  pre-event trend and the prior-day level are available. Every date P_START_DATE..P_END_DATE
  is returned; value columns are NULL when the day has insufficient clean data.
"""
import statistics as st
from collections import defaultdict
from datetime import datetime, timedelta

K_MAD, RATE_FLOOR = 4.0, 3.0
BAND_DAYS, BAND_MIN_RATES = 14, 48       # rolling rate band: days of history, min hourly changes
MERGE_H, SETTLE_H = 6, 2
LEVEL_TOL, REBASE_H = 25.0, 12
MIN_RUN_H, MAX_RUN_SLOPE = 4, 0.5
MIN_DAY_H = 10
TAIL_WIN_H, TAIL_MAX_H = 12, 72       # recovery tail: trailing slope window, max hours after settling
TAIL_RATE_TOL, TAIL_RATE_FLOOR = 1.0, 1.0  # tail ends when |slope - pre-event rate| <= max(100% of rate, 1 psi/hr)
SLOPE_MAX_SE = 10.0                   # SLOPE method rejected when its standard error > 10 psi/day
ONE_H = timedelta(hours=1)


def _slope(xs, ys):
    mx, my = st.mean(xs), st.mean(ys)
    sxx = sum((x - mx) ** 2 for x in xs)
    return 0.0 if sxx == 0 else sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sxx


class StableDeclineDrawdown:
    def __init__(self):
        self.samples = defaultdict(list)
        self.start = self.end = None

    def process(self, ts, tp, p_start_date, p_end_date):
        self.start, self.end = p_start_date, p_end_date
        if ts is not None and tp is not None:
            self.samples[ts.replace(minute=0, second=0, microsecond=0)].append(tp)

    def end_partition(self):
        if self.start is None:
            return
        days = [self.start + timedelta(days=i) for i in range((self.end - self.start).days + 1)]
        empty = lambda d: (d, None, None, None, None, None, None)

        lvl_h = {h: st.median(v) for h, v in self.samples.items() if len(v) >= 3}
        cnt_h = {h: len(self.samples[h]) for h in lvl_h}
        hours = sorted(lvl_h)
        if len(hours) < 24:
            for d in days:
                yield empty(d)
            return
        t0 = hours[0]
        x = lambda h: (h - t0).total_seconds() / 3600.0

        # 2. rate band
        rate = {b: lvl_h[b] - lvl_h[a] for a, b in zip(hours, hours[1:]) if b - a == ONE_H}
        if len(rate) < 24:
            for d in days:
                yield empty(d)
            return
        # rolling band: each day uses the hourly changes from the BAND_DAYS before it, so a
        # day''s result does not depend on how wide a date range the caller asked for
        rate_days = defaultdict(list)
        for h, r in rate.items():
            rate_days[h.date()].append(r)
        all_rates = list(rate.values())
        day_med, day_band = {}, {}
        for d in sorted({h.date() for h in hours}):
            rv = [r for k in range(1, BAND_DAYS + 1) for r in rate_days.get(d - timedelta(days=k), [])]
            if len(rv) < BAND_MIN_RATES:
                rv = all_rates
            m = st.median(rv)
            day_med[d] = m
            day_band[d] = max(K_MAD * st.median(abs(r - m) for r in rv), RATE_FLOOR)
        normal = {h: (h in rate and abs(rate[h] - day_med[h.date()]) <= day_band[h.date()]) for h in hours}

        # 3. excursion events
        events = []
        for h in hours:
            if h in rate and not normal[h]:
                if events and h - events[-1][1] <= timedelta(hours=MERGE_H):
                    events[-1][1] = h
                else:
                    events.append([h, h])

        excluded, rebases = set(), []
        last_trend = None  # (slope, x0, y0) of the last genuinely stable pre-event period
        for ev_start, ev_last in events:
            # pre-event trend from clean hours only, so back-to-back events are judged against
            # the well''s last stable behaviour rather than the previous event''s recovery
            pre = [h for h in hours
                   if ev_start - timedelta(hours=24) <= h < ev_start and normal[h] and h not in excluded]
            if len(pre) >= 6:
                b = _slope([x(h) for h in pre], [lvl_h[h] for h in pre])
                x0, y0 = x(pre[-1]), lvl_h[pre[-1]]
                last_trend = (b, x0, y0)
            elif last_trend is not None:
                b, x0, y0 = last_trend
            else:
                b, x0, y0 = day_med[ev_start.date()], x(ev_start), lvl_h[ev_start]
            streak, settled, kind = 0, None, "rebased"
            for h in hours:
                if h < ev_start:
                    continue
                excluded.add(h)
                if h <= ev_last:
                    streak = 0
                    continue
                streak = streak + 1 if normal[h] else 0
                if abs(lvl_h[h] - (y0 + b * (x(h) - x0))) <= LEVEL_TOL:
                    settled, kind = h, "recovered"
                    break
                if streak >= REBASE_H:
                    settled = h
                    break
            if settled is not None:
                # recovery tail: stay excluded until the trailing decline rate is back near the
                # pre-event rate (a slow post-event decay passes the hourly band but is not drawdown)
                ref = b
                tol = max(abs(ref) * TAIL_RATE_TOL, TAIL_RATE_FLOOR)
                cap = settled + timedelta(hours=TAIL_MAX_H)
                for h in hours:
                    if h <= settled:
                        continue
                    if h > cap:
                        break
                    win = [k for k in hours if h - timedelta(hours=TAIL_WIN_H - 1) <= k <= h]
                    if len(win) >= TAIL_WIN_H * 2 // 3 and \\
                            abs(_slope([x(k) for k in win], [lvl_h[k] for k in win]) - ref) <= tol:
                        break
                    excluded.add(h)
                    settled = h
                for k in range(1, SETTLE_H + 1):
                    excluded.add(settled + k * ONE_H)
            if kind == "rebased":
                rebases.append(ev_start)

        # 4. clean runs (contiguous, same Central day)
        runs, cur = [], []
        for h in hours:
            ok = normal[h] and h not in excluded
            if ok and cur and h - cur[-1] == ONE_H and h.date() == cur[-1].date():
                cur.append(h)
            else:
                if len(cur) >= MIN_RUN_H:
                    runs.append(cur)
                cur = [h] if ok else []
        if len(cur) >= MIN_RUN_H:
            runs.append(cur)
        runs = [r for r in runs if _slope([x(h) for h in r], [lvl_h[h] for h in r]) <= MAX_RUN_SLOPE]

        runs_by_day = defaultdict(list)
        for r in runs:
            runs_by_day[r[0].date()].append(r)

        # 5. noon level per day (Theil-Sen)
        def noon_level(day):
            hs = [h for r in runs_by_day.get(day, []) for h in r]
            if len(hs) < MIN_DAY_H:
                return None
            xs = [x(h) for h in hs]
            ys = [lvl_h[h] for h in hs]
            sl = st.median([(ys[j] - ys[i]) / (xs[j] - xs[i])
                            for i in range(len(xs)) for j in range(i + 1, len(xs))])
            xn = x(datetime.combine(day, datetime.min.time()) + timedelta(hours=12))
            return st.median([y - sl * (xi - xn) for xi, y in zip(xs, ys)])

        def run_slope_rate(day):
            rs = runs_by_day.get(day, [])
            n = sum(len(r) for r in rs)
            if n < MIN_DAY_H:
                return None
            sxy = sxx = 0.0
            centred = []
            for r in rs:
                xs = [x(h) for h in r]
                ys = [lvl_h[h] for h in r]
                mx, my = st.mean(xs), st.mean(ys)
                centred.append([(a - mx, c - my) for a, c in zip(xs, ys)])
                sxy += sum(a * c for a, c in centred[-1])
                sxx += sum(a * a for a, _ in centred[-1])
            if sxx == 0:
                return None
            b = sxy / sxx
            # standard error of the pooled slope (one intercept per run); reject noisy estimates
            dof = n - len(rs) - 1
            if dof <= 0:
                return None
            ssr = sum((c - b * a) ** 2 for run in centred for a, c in run)
            if 24.0 * (ssr / dof / sxx) ** 0.5 > SLOPE_MAX_SE:
                return None
            return -24.0 * b

        excluded_by_day = defaultdict(int)
        for h in excluded:
            if h in lvl_h:
                excluded_by_day[h.date()] += 1

        levels = {}
        for d in [self.start - timedelta(days=1)] + days:
            levels[d] = noon_level(d)

        # 6. daily delta
        def clean_hours(day):
            return [h for r in runs_by_day.get(day, []) for h in r]

        for d in days:
            hs = clean_hours(d)
            prev_hs = clean_hours(d - timedelta(days=1))
            lvl, prev = levels.get(d), levels.get(d - timedelta(days=1))
            delta, method = None, None
            if lvl is not None and prev is not None:
                # both levels must come from the same baseline: no rebasing event anywhere
                # between the first clean hour behind yesterday''s level and the last behind today''s
                lo_h, hi_h = min(prev_hs), max(hs)
                if not any(lo_h <= r <= hi_h for r in rebases):
                    delta, method = prev - lvl, "LEVEL"
            if delta is None:
                s = run_slope_rate(d)
                if s is not None:
                    delta, method = s, "SLOPE"
            yield (
                d,
                lvl,
                delta,
                float(len(hs)) if hs else None,
                sum(cnt_h[h] for h in hs) if hs else None,
                method,
                float(excluded_by_day.get(d, 0)),
            )
';
