# Drawdown Management App — Complete Object Inventory
**Account:** OPJQICB-DEV (Adamas) | **App:** DRAWDOWN_MANAGEMENT_DAILY | **Generated:** 2026-10-02

---

## CYGNET_TRANSFORMATION.ANALYTICS — App-Facing Layer

### Views (13)

| View | Used by App | Depends On |
|---|---|---|
| **VW_DRAWDOWN_WELL_HEADER** | Yes — `/api/drawdown-status` | ANALYTICS.VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT, ANALYTICS.VW_CM_WELL_MASTER, CCM.ASSET, CCM.VW_ASSET_ATTR_DAY_CALCUATED_LATEST |
| **VW_CM_WELL_MASTER** | Yes — `/api/well-attributes` | CCM.VW_ASSET_ATTR, **EDW.ANALYTICS.DIM_WELL_COMPLETION_MASTER** |
| **VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT** | Indirect (via VW_DRAWDOWN_WELL_HEADER) | CCM.VW_ASSET_ATTR, ANALYTICS.VW_METER_WELL, CCM.VW_ASSET_ATTR_TAG_VALUE_LATEST, CCM.ASSET |
| **VW_DRAWDOWN_WELL_TAG_VALUES** | Indirect (via FN_DRAWDOWN_WELL_VALUES_LTTB) | CCM.VW_ASSET_ATTR, ANALYTICS.VW_METER_WELL, CCM.VW_ASSET_ATTR_TAG_VALUE |
| **VW_METER_WELL** | Indirect (via tag value views + LTTB) | CCM.ASSET, CCM.ASSET_TYPE, CCM.ASSET_ATTR, CCM.CODE |
| **VW_DRAWDOWN_WELL_ATTR_ALL_VALUES** | No | ANALYTICS.VW_DRAWDOWN_WELL_ATTR_DAY_VALUES, ANALYTICS.VW_DRAWDOWN_WELL_TAG_VALUES |
| **VW_DRAWDOWN_WELL_ATTR_DAY_VALUES** | No | CCM.VW_ASSET_ATTR, CCM.ASSET_ATTR_DAY |
| VW_ADAMAS_WELL_ATTRIBUTES_10_MINUTE | No | (not in drawdown path) |
| VW_GAS_METER_FIXED_ATTRIBUTES | No | CCM.VW_ASSET_ATTR |
| VW_GAS_METER_READINGS | No | CCM.TAG_VALUE, CCM.ASSET_ATTR, CCM.ASSET |
| VW_GAS_METER_WELL | No | CCM.ASSET, CCM.ASSET_ATTR, CCM.CODE |
| VW_TMPL_WELL_BASE_TEMPLATE | No | ANALYTICS.TMPL_WELL_BASE_TEMPLATE |
| VW_WELLVIEW_TUBCOMP | No | **WELLVIEW_120_RAW.ADAMAS_WV120_CALC** |

### Table Functions (2)

| Function | Signature | Used by App | Depends On |
|---|---|---|---|
| **FN_DRAWDOWN_WELL_VALUES_LTTB** | (TIMESTAMP_NTZ, TIMESTAMP_NTZ, VARCHAR, NUMBER) → TABLE(WELL_ASSET_ID, ATTR_ID, TIMESTAMP_CENTRAL, VALUE_NUMBER) | Yes — `/api/timeseries` | CCM.VW_ASSET_ATTR, ANALYTICS.VW_METER_WELL, CCM.ASSET_ATTR, CCM.TAG_VALUE_DAY, ANALYTICS.VW_DRAWDOWN_WELL_TAG_VALUES, CCM.ASSET_ATTR_DAY |
| **FN_EST_DAILY_DRAWDOWN** | (VARCHAR, DATE, DATE) → TABLE(WELL_ASSET_ID, DATE_PERIOD, STABLE_AVG_TUBING_PRESSURE, DELTA_TUBING_PRESSURE, STABLE_HOURS, STABLE_SAMPLE_COUNT) | No (used by the daily drawdown load) | CCM.VW_ASSET_ATTR, CCM.VW_ASSET_ATTR_TAG_VALUE |

### Tables (1)

| Table | Rows | Notes |
|---|---|---|
| TMPL_WELL_BASE_TEMPLATE | 3,923,877 | Pre-pivoted well template data |

---

## CYGNET_TRANSFORMATION.CORE_COMMON_MODEL — IIoT Common Model

### Tables (36)

| Table | Rows | Key Role |
|---|---|---|
| **ASSET** | 46,801 | Core equipment entity (wells, meters, etc.) |
| **ASSET_ATTR** | 1,203,270 | Business attributes per asset (pressure, choke, API_NUMBER, etc.) |
| **ASSET_ATTR_DAY** | 47,772 | Daily attribute values (daily drawdown estimates) |
| **ASSET_COMMENTARY** | 3 | User notes and annotations (app CRUD) |
| **ASSET_TYPE** | 51 | Equipment type classification (WELL, MTRRUNG, etc.) |
| **ATTR_DFNTN** | 340 | Attribute definitions (names, categories, data types) |
| **CODE** | 323 | Lookup codes (facility attribute mappings) |
| **TAG** | 546,880 | Signal/sensor definitions |
| **TAG_VALUE** | 816,556,067 | Primary time series fact table (~817M rows) |
| **TAG_VALUE_CURRENT** | 213,267 | Most recent value per tag |
| **TAG_VALUE_DAY** | 8,900,904 | Daily first/last summaries per tag |
| **TAG_VALUE_MINUTE** | 9,540,517,862 | Minute-level summaries (~9.5B rows) |
| **UNIT** | 42 | Units of measure |
| UNIT_ALIAS | 82 | Unit name mappings |
| UNIT_CONVERSION | 17 | Unit conversion factors |
| ASSET_ALIAS | 0 | Asset alternate identifiers |
| ASSET_ATTR_MONTH | 0 | Monthly attribute values |
| ASSET_EVENT | 0 | Operational events |
| ASSET_EVENT_ATTR | 0 | Event attributes |
| ASSET_HIERARCHY | 0 | Named hierarchies |
| ASSET_HIERARCHY_ASSET | 0 | Parent-child asset relationships |
| ASSET_TYPE_ATTR_TEMPLATE | 1 | Template definitions |
| ASSET_TYPE_ATTR_TEMPLATE_ATTR | 6 | Template attribute members |
| ATTR_ALIAS | 0 | Attribute name mappings |
| ATTR_CALC | 0 | Derived calculation definitions |
| ATTR_CALC_GROUP | 0 | Calculation execution groups |
| ATTR_CALC_GROUP_ATTR | 0 | Calc group membership |
| CODE_TYPE | 4 | Code type categories |
| EVENT_TYPE | 0 | Event type definitions |
| IOT_GAPFILL_CORRECTION_LOG | 0 | Gap-fill corrections |
| IOT_PIPELINE_BATCH | 5,678 | Pipeline batch tracking |
| IOT_PIPELINE_CONFIG | 12 | Pipeline configuration |
| IOT_PIPELINE_WINDOWS | 213,556 | Pipeline time windows |
| IOT_TEMPLATE_WORKER_ASSIGNMENTS | 1 | Worker assignments |
| TAG_VALUE_AGGREGATE | 0 | Pre-computed aggregates |
| TAG_VALUE_INTERPOLATED | 0 | Gap-filled interpolated values |

### Views (12)

| View | Used by App (indirect) | Depends On |
|---|---|---|
| **VW_ASSET_ATTR** | Yes (widely used) | ASSET_ATTR, ASSET, ASSET_TYPE, ATTR_DFNTN, TAG, UNIT |
| **VW_ASSET_ATTR_TAG_VALUE** | Yes (via tag values views) | ASSET, ASSET_ATTR, TAG_VALUE, ASSET_TYPE |
| **VW_ASSET_ATTR_TAG_VALUE_LATEST** | Yes (via VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT) | ASSET, ASSET_ATTR, TAG_VALUE_CURRENT, ASSET_TYPE |
| **VW_ASSET_ATTR_DAY_CALCUATED_LATEST** | Yes (via VW_DRAWDOWN_WELL_HEADER) | ASSET_ATTR_DAY, ATTR_DFNTN (filtered to CALCULATED record_source) |
| VW_ASSET_ATTR_DAY_CALCULATED | No | ASSET_ATTR_DAY, ATTR_DFNTN |
| VW_ASSET_ATTR_DAY_CALCULATED_LATEST | No | ASSET_ATTR_DAY, ATTR_DFNTN |
| VW_ASSET_ATTR_TAG_VALUE_HOUR | No | ASSET, ASSET_ATTR, TAG_VALUE, ASSET_TYPE |
| VW_ASSET_ATTR_TAG_VALUE_HOUR_AVG | No | ASSET, ASSET_ATTR, TAG_VALUE, ASSET_TYPE |
| VW_ASSET_ATTR_TAG_VALUE_MINUTE | No | ASSET, ASSET_ATTR, TAG_VALUE_MINUTE, ASSET_TYPE |
| VW_ASSET_TEMPLATE_ATTR_TAG | No | ASSET_TYPE_ATTR_TEMPLATE, ASSET_TYPE_ATTR_TEMPLATE_ATTR, ATTR_DFNTN, ASSET, ASSET_ATTR, TAG |
| VW_DATA_COMPLETENESS_WELL | No | (data quality monitoring) |
| VW_TAG_VALUE_LATEST | No | CORE_CYGNET.VW_CYGNET_UIS |

### Table Functions (3)

| Function | Signature | Used by App | Depends On |
|---|---|---|---|
| FN_DRAWDOWN_WELL_VALUES | (TIMESTAMP_NTZ, TIMESTAMP_NTZ) → TABLE (pivoted 14-column) | No | (older version, all wells) |
| FN_DRAWDOWN_WELL_VALUES | (TIMESTAMP_NTZ, TIMESTAMP_NTZ, VARCHAR) → TABLE (pivoted 14-column) | No | (older version, single well) |
| FN_DRAWDOWN_WELL_VALUES_LTTB_PIVOT | (TIMESTAMP_NTZ, TIMESTAMP_NTZ, VARCHAR, NUMBER, NUMBER) → TABLE (pivoted 15-column incl DAILY_EST_DRAWDOWN) | No | (pivoted LTTB variant) |

---

## CYGNET_TRANSFORMATION.APPS — Duplicate Views (APPS schema)

These are copies of the ANALYTICS drawdown views that reference `_LATEST` base views directly. The app's API routes currently reference the ANALYTICS schema, not APPS.

| View | Equivalent ANALYTICS View |
|---|---|
| VW_DRAWDOWN_WELL_HEADER | ANALYTICS.VW_DRAWDOWN_WELL_HEADER |
| VW_DRAWDOWN_WELL_TAG_VALUES | ANALYTICS.VW_DRAWDOWN_WELL_TAG_VALUES |
| VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT | ANALYTICS.VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT |
| VW_DRAWDOWN_WELL_ATTR_ALL_VALUES | ANALYTICS.VW_DRAWDOWN_WELL_ATTR_ALL_VALUES |
| VW_DRAWDOWN_WELL_ATTR_DAY_VALUES | ANALYTICS.VW_DRAWDOWN_WELL_ATTR_DAY_VALUES |

---

## CYGNET_TRANSFORMATION.CORE_CYGNET — CygNet Source Views

| View | Notes |
|---|---|
| **VW_CYGNET_UIS** | Real-time CygNet UIS data feed — used by VW_TAG_VALUE_LATEST |
| VW_CYGNET_FACILITY | CygNet facility reference data |
| VW_CYGNET_HISTORY | CygNet historical data |
| VW_CYGNET_POINT | CygNet point metadata |

---

## External Database Dependencies

| Object | Database.Schema | Used By | Notes |
|---|---|---|---|
| **DIM_WELL_COMPLETION_MASTER** | EDW.ANALYTICS | VW_CM_WELL_MASTER | Enterprise well master (county, legal name, frac dates, reservoir, etc.) |
| WVT_WVWELLHEADER, WVT_WVTUB, WVT_WVTUBCOMP | WELLVIEW_120_RAW.ADAMAS_WV120_CALC | VW_WELLVIEW_TUBCOMP | Imported DB from Peloton WellView — not in app critical path |

---

## App Configuration

| Item | Value |
|---|---|
| App Name | DRAWDOWN_MANAGEMENT_DAILY |
| App Database.Schema | CYGNET_TRANSFORMATION.APP |
| Query Warehouse | REPORTING_WH |
| App Source (local) | app/ directory (deployed with `snow app deploy` from `app/app.yml`) |
| App Source (stage) | @CYGNET_TRANSFORMATION.APP.DRAWDOWN_MANAGEMENT_DAILY_CODE (created by the CLI at deploy time) |
