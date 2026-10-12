# Drawdown Management

Daily tubing-pressure drawdown monitoring for Haynesville wells, built on the
CYGNET_TRANSFORMATION common model. A Next.js app on Snowflake App Runtime
(service `CYGNET_TRANSFORMATION.APP.DRAWDOWN_MANAGEMENT_DAILY`) shows the well
list with the latest drawdown, per-well time series charts (LTTB-downsampled),
well attributes, and engineer commentary/annotations.

## Repository layout

```
app/                Next.js app (deployed with `snow app deploy`; manifest app/app.yml)
sql/01_tables/      App-owned tables in CORE_COMMON_MODEL (commentary, daily attributes)
sql/02_views/       CORE_COMMON_MODEL contextual views + APP drawdown views
sql/03_functions/   Drawdown calculation and LTTB time series functions
sql/04_procedures/  Daily drawdown load procedures
sql/05_tasks/       Daily drawdown task
sql/grants/         Privileges needed to deploy the app as CYGNET_ADMIN
docs/               Dependency map, object inventory, end-user permissions
```

Every file under `sql/` was exported with `GET_DDL` from TEST (OPJQICB-TEST)
on 2026-10-12 and is exactly what the deployed app runs against. Files are
fully qualified (`CYGNET_TRANSFORMATION.<schema>.<object>`) and use
`CREATE OR REPLACE`.

## Prerequisites in the target account

These are maintained by the common-model pipeline, not this repo, and must
already exist and be loading:

- `CYGNET_TRANSFORMATION.CORE_COMMON_MODEL` tables `ASSET`, `ASSET_ATTR`,
  `ATTR_DFNTN`, `TAG`, `TAG_VALUE`, `TAG_VALUE_CURRENT`, `TAG_VALUE_DAY`,
  `UNIT_OF_MEASUREMENT`, plus the CORE_CYGNET / CORE_COMMON_MODEL load tasks
- `EDW.ANALYTICS.DIM_WELL_COMPLETION_MASTER` (well master reference data)
- Role `CYGNET_ADMIN` owning `CYGNET_TRANSFORMATION`, warehouse `REPORTING_WH`
- Snowflake CLI 3.27+ for `snow app deploy`

See `docs/adamas-active-dependencies.md` for the full dependency chain.

## Deploy order

1. `sql/grants/app_service_grants.sql` (admin role; skip grants already held)
2. `sql/01_tables` → `02_views` → `03_functions` → `04_procedures` → `05_tasks`
   (within `02_views`, run `core_common_model.*` before `app.*`; the header view
   depends on the master, tag-value-current and attr-day-calculated-latest views)
3. Resume the task: `ALTER TASK CYGNET_TRANSFORMATION.APP.TASK_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN RESUME;`
4. Backfill drawdown history, e.g. one month at a time:
   `CALL CYGNET_TRANSFORMATION.APP.SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN_SET('2026-07-01', '2026-07-31');`
5. Deploy the app: `cd app && snow app deploy --connection <conn>`
6. Grant end users access per `docs/drawdown-app-user-permissions.md`

`01_tables` uses `CREATE OR REPLACE TABLE`. In an account where
`ASSET_COMMENTARY` or `ASSET_ATTR_DAY` already hold data, do not run those
files; compare the definitions instead.

## Production checklist (known issues as of 2026-10-12)

- **LTTB drawdown series not filtered by well.** In
  `FN_DRAWDOWN_WELL_VALUES_LTTB`, the `drawdown_daily` CTE ignores
  `P_WELL_ASSET_ID`, so it returns every well's DAILY_EST_DRAWDOWN. The app
  filters the result (`app/app/api/timeseries/route.ts`), so charts are
  correct; fix the function with
  `AND (p_well_asset_id IS NULL OR aad.asset_id = p_well_asset_id)`.
- **Per-well procedures are slow.** `SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN`
  loops over every active well (~1,700, ~2–3 s each) and reached the task's
  60-minute timeout on DEV and TEST. The task now calls the set-based
  `SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN_SET`; confirm its runtime on TEST before
  promoting, then consider retiring the per-well procedures.
- **Unused legacy procedure on DEV/TEST:** `APP.SP_EST_DAILY_DRAWDOWN` is not
  used by the app or task and is not included here; don't migrate it.
- **Drawdown history.** TEST holds very little DAILY_EST_DRAWDOWN history;
  backfill (step 4) before user acceptance testing.

## Environments

| Env | Account | App URL |
|---|---|---|
| DEV | OPJQICB-DEV | https://ayap2-opjqicb-dev.snowflakecomputing.app |
| TEST | OPJQICB-TEST | https://mw6o2-opjqicb-test.snowflakecomputing.app |

Design diagram (Lucid): https://lucid.app/lucidchart/d9a65d59-10e6-401b-bfa2-bc74549eba55/edit
