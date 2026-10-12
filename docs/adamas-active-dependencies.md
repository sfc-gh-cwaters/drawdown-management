# Drawdown Management App — Active Object Dependencies
**Account:** OPJQICB-DEV (Adamas) | **App:** DRAWDOWN_MANAGEMENT_DAILY | **Warehouse:** REPORTING_WH | **Updated:** 2026-10-12

Only objects used by the running app code (`app/` API routes) and everything they depend on, traced from the live definitions on the account. All objects are in the `CYGNET_TRANSFORMATION` database unless noted.

---

## Layer 1 — Queried directly by app API routes

| Object | Type | Schema | App route | SQL operations |
|---|---|---|---|---|
| VW_DRAWDOWN_WELL_HEADER | View | **APP** | `/api/drawdown-status` | SELECT |
| VW_DRAWDOWN_WELL_MASTER | View | **APP** | `/api/well-attributes` | SELECT |
| FN_DRAWDOWN_WELL_VALUES_LTTB | Table function (SQL) | **APP** | `/api/timeseries` | SELECT via TABLE() |
| ASSET_COMMENTARY | Table | CORE_COMMON_MODEL | `/api/commentary`, `/api/chart-annotations` | SELECT, INSERT, UPDATE, DELETE |
| ASSET | Table | CORE_COMMON_MODEL | `/api/commentary` | SELECT (in INSERT subquery) |

## Layer 2 — Referenced by Layer 1 views and functions

| Object | Type | Schema | Used by |
|---|---|---|---|
| VW_DRAWDOWN_WELL_MASTER | View | **APP** | VW_DRAWDOWN_WELL_HEADER (also Layer 1) |
| VW_DRAWDOWN_WELL_TAG_VALUES | View | **APP** | FN_DRAWDOWN_WELL_VALUES_LTTB |
| VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT | View | **APP** | VW_DRAWDOWN_WELL_HEADER |
| VW_ASSET_ATTR_DAY_CALCULATED_LATEST | View | CORE_COMMON_MODEL | VW_DRAWDOWN_WELL_HEADER |
| TAG_VALUE_DAY | Table | CORE_COMMON_MODEL | FN_DRAWDOWN_WELL_VALUES_LTTB |

## Layer 3 — Base views

| Object | Type | Schema | Used by |
|---|---|---|---|
| VW_ASSET_ATTR | View | CORE_COMMON_MODEL | VW_DRAWDOWN_WELL_MASTER, VW_DRAWDOWN_WELL_TAG_VALUES, VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT, FN_DRAWDOWN_WELL_VALUES_LTTB |
| VW_ASSET_ATTR_TAG_VALUE | View | CORE_COMMON_MODEL | VW_DRAWDOWN_WELL_TAG_VALUES |
| VW_ASSET_ATTR_TAG_VALUE_LATEST | View | CORE_COMMON_MODEL | VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT |
| DIM_WELL_COMPLETION_MASTER | View | **EDW.ANALYTICS** | VW_DRAWDOWN_WELL_MASTER |

## Layer 4 — Base tables (CORE_COMMON_MODEL)

| Table | Rows | Used by |
|---|---|---|
| ASSET | 46,832 | VW_ASSET_ATTR, VW_ASSET_ATTR_TAG_VALUE, VW_ASSET_ATTR_TAG_VALUE_LATEST, VW_ASSET_ATTR_DAY_CALCULATED_LATEST, VW_DRAWDOWN_WELL_HEADER, FN_DRAWDOWN_WELL_VALUES_LTTB, commentary route |
| ASSET_ATTR | 1,204,322 | VW_ASSET_ATTR, VW_ASSET_ATTR_TAG_VALUE, VW_ASSET_ATTR_TAG_VALUE_LATEST, FN_DRAWDOWN_WELL_VALUES_LTTB |
| ASSET_ATTR_DAY | 27,282 | VW_ASSET_ATTR_DAY_CALCULATED_LATEST, FN_DRAWDOWN_WELL_VALUES_LTTB |
| ASSET_COMMENTARY | 4 | App routes (direct CRUD) |
| ATTR_DFNTN | 340 | VW_ASSET_ATTR, VW_ASSET_ATTR_TAG_VALUE, VW_ASSET_ATTR_TAG_VALUE_LATEST, VW_ASSET_ATTR_DAY_CALCULATED_LATEST |
| TAG | 676,922 | VW_ASSET_ATTR, VW_ASSET_ATTR_TAG_VALUE, VW_ASSET_ATTR_TAG_VALUE_LATEST |
| TAG_VALUE | 835,235,938 | VW_ASSET_ATTR_TAG_VALUE |
| TAG_VALUE_CURRENT | 214,636 | VW_ASSET_ATTR_TAG_VALUE_LATEST |
| TAG_VALUE_DAY | 9,128,033 | FN_DRAWDOWN_WELL_VALUES_LTTB |
| UNIT | 42 | VW_ASSET_ATTR, VW_ASSET_ATTR_TAG_VALUE, VW_ASSET_ATTR_TAG_VALUE_LATEST, VW_ASSET_ATTR_DAY_CALCULATED_LATEST |

## External dependencies (outside CYGNET_TRANSFORMATION)

| Object | Type | Used by | Notes |
|---|---|---|---|
| EDW.ANALYTICS.DIM_WELL_COMPLETION_MASTER | View | APP.VW_DRAWDOWN_WELL_MASTER | Well and completion master attributes, joined on the Enertia well code |
| EDW.ANALYTICS.DIM_PROPERTY_MASTER_ALL_SYSTEMS | View | DIM_WELL_COMPLETION_MASTER | |
| MDM_RAW.ENERHUB_RAW.WELL | Source | DIM_WELL_COMPLETION_MASTER | Owned outside the drawdown project; not traced further |
| MDM_RAW.ENERHUB_RAW.COMPLETION | Source | DIM_WELL_COMPLETION_MASTER | Owned outside the drawdown project; not traced further |
| TRANSFORMATION.CROSS_REFERENCE.DT_303_PROPERTY_MASTER | Source | DIM_PROPERTY_MASTER_ALL_SYSTEMS | Owned outside the drawdown project; not traced further |

## Drawdown calculation (writes ASSET_ATTR_DAY — run separately from the app)

The app reads `DAILY_EST_DRAWDOWN` from `ASSET_ATTR_DAY`. Those values are produced by the load procedures below, not by the app.

| Object | Type | Schema | Role |
|---|---|---|---|
| TASK_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN | Task | APP | Daily 06:00 Central on REPORTING_WH; calls SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN_SET for the previous Central day |
| SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN_SET | Procedure | APP | Set-based load for every active well: one TAG_VALUE scan and one FN_EST_DAILY_DRAWDOWN_CORE call (partitioned by well) per chunk. Used by the task and for backfills |
| SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN | Procedure | APP | Older per-well loop over SP_LOAD_WELL_DAILY_DRAWDOWN; too slow for the task (~1,700 wells), kept for reference |
| SP_LOAD_WELL_DAILY_DRAWDOWN | Procedure | APP | Replaces DAILY_EST_DRAWDOWN rows in ASSET_ATTR_DAY for one well and date range (single-well reload) |
| FN_EST_DAILY_DRAWDOWN | Table function (SQL) | APP | Reads TUBING_PRESSURE from VW_ASSET_ATTR_TAG_VALUE for one well and passes it to FN_EST_DAILY_DRAWDOWN_CORE (used by SP_LOAD_WELL_DAILY_DRAWDOWN) |
| FN_EST_DAILY_DRAWDOWN_CORE | Table function (Python) | APP | Stable-decline algorithm: excludes surface excursions, derives daily drawdown |

Source: `sql/03_functions/`, `sql/04_procedures/`, `sql/05_tasks/`. The legacy `SP_EST_DAILY_DRAWDOWN` still exists on DEV/TEST but is unused and not in the repo.

## Changes since the 2026-10-02 version

- `ANALYTICS.VW_CM_WELL_MASTER` replaced by **`APP.VW_DRAWDOWN_WELL_MASTER`**.
- Well-to-meter matching now uses `ENERTIA_COMPLETION_ID`. **`ANALYTICS.VW_METER_WELL`** and the **`CODE`** table are no longer used.
- Drawdown in the well list now comes from **`VW_ASSET_ATTR_DAY_CALCULATED_LATEST`**, and shows the most recent day. The misspelled `..._CALCUATED_LATEST` view no longer exists.
- `FN_DRAWDOWN_WELL_VALUES_LTTB` reads `ASSET_ATTR_DAY` and `TAG_VALUE_DAY` directly.
- `EDW.ANALYTICS.DIM_WELL_COMPLETION_MASTER` is a **view**, not a table.
- App warehouse changed from `CYGNET_TRANSFORMING_WH` to **`REPORTING_WH`**.
- New section for the drawdown calculation objects. The drawdown functions are consolidated into `FN_EST_DAILY_DRAWDOWN` and `FN_EST_DAILY_DRAWDOWN_CORE`; the interim `_V2` functions were dropped.
- The task now calls the set-based `SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN_SET` (the per-well loop hit the 60-minute task timeout).

Note: the unused `/api/drawdown-daily` route (it read `DEV.CORE.V_WELL_DRAWDOWN_DAILY`, which doesn't exist on Adamas) was removed from the source on 2026-10-12.

## Summary

**Total objects the app depends on: 24**

- 5 APP objects: 4 views (VW_DRAWDOWN_WELL_HEADER, VW_DRAWDOWN_WELL_MASTER, VW_DRAWDOWN_WELL_TAG_VALUES, VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT) and 1 table function (FN_DRAWDOWN_WELL_VALUES_LTTB)
- 4 CORE_COMMON_MODEL views
- 10 CORE_COMMON_MODEL tables
- 2 EDW.ANALYTICS views
- 3 external source objects (MDM_RAW, TRANSFORMATION)

Plus 6 drawdown calculation objects in the repo (1 task, 3 procedures, 2 functions) that populate `ASSET_ATTR_DAY` outside the app.
