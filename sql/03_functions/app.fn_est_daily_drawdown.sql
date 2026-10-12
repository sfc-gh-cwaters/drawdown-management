CREATE OR REPLACE FUNCTION CYGNET_TRANSFORMATION.APP.FN_EST_DAILY_DRAWDOWN("P_WELL_ASSET_ID" VARCHAR, "P_START_DATE" DATE, "P_END_DATE" DATE)
RETURNS TABLE ("WELL_ASSET_ID" VARCHAR, "DATE_PERIOD" DATE, "STABLE_AVG_TUBING_PRESSURE" FLOAT, "DELTA_TUBING_PRESSURE" FLOAT, "STABLE_HOURS" FLOAT, "STABLE_SAMPLE_COUNT" NUMBER(38,0), "DELTA_METHOD" VARCHAR, "EXCLUDED_HOURS" FLOAT)
LANGUAGE SQL
COMMENT='Estimated daily drawdown for one well: day-over-day change in stable flowing tubing pressure, excluding surface-driven excursions (stable-decline algorithm).'
AS '
/********************************************************************************
Author:         Chris Waters
Description:    Calculates the estimated daily drawdown for one well. Reads TUBING_PRESSURE
                for one well, de-duplicates readings, converts to Central time and
                passes them to FN_EST_DAILY_DRAWDOWN_CORE (Python), which removes
                excursions (shut-ins, choke changes and their recovery) and derives
                the daily drawdown from stable flowing periods only.

                Sources:
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_TAG_VALUE
                  - CYGNET_TRANSFORMATION.APP.FN_EST_DAILY_DRAWDOWN_CORE
Create Date:    10/05/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
2026/10/06      Chris Waters
                Consolidated: replaces the earlier FN_EST_DAILY_DRAWDOWN (monotonic
                20-minute buckets) and the interim _V2 names. Used by
                SP_LOAD_WELL_DAILY_DRAWDOWN and SP_EST_DAILY_DRAWDOWN.
--------------------------------------------------------------------------------
Notes:
  - Reads 21 days before P_START_DATE (14-day rolling rate band, pre-event trend, prior-day
    level) and one UTC day after P_END_DATE (late Central hours).
  - Days are Central-time calendar days.
  - STABLE_AVG_TUBING_PRESSURE is the stable noon level, not a simple average.
  - DELTA_METHOD: LEVEL = noon-to-noon level change; SLOPE = within-run rate,
    used when a shut-in reset the baseline between the two noons.
  - EXCLUDED_HOURS: hours removed as part of an excursion.
--------------------------------------------------------------------------------
*********************************************************************************/
SELECT p_well_asset_id, c.date_period, c.stable_avg_tubing_pressure, c.delta_tubing_pressure,
       c.stable_hours, c.stable_sample_count, c.delta_method, c.excluded_hours
FROM (
    SELECT DISTINCT
        CONVERT_TIMEZONE(''UTC'', ''America/Chicago'', v.timestamp_utc::TIMESTAMP_NTZ) AS ts,
        v.value_number::FLOAT AS tp
    FROM cygnet_transformation.core_common_model.vw_asset_attr_tag_value v
    WHERE v.asset_id     = p_well_asset_id
      AND v.attr_id      = ''TUBING_PRESSURE''
      AND v.value_number IS NOT NULL
      AND v.date_utc BETWEEN p_start_date - 21 AND p_end_date + 1
) r,
TABLE(cygnet_transformation.app.fn_est_daily_drawdown_core(r.ts, r.tp, p_start_date, p_end_date)
      OVER (PARTITION BY 1 ORDER BY r.ts)) c
';
