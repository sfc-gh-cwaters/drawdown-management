# Drawdown Management — Web Application

Next.js 16 app deployed as the Snowflake App Runtime service
`CYGNET_TRANSFORMATION.APP.DRAWDOWN_MANAGEMENT_DAILY` (manifest: `app.yml`,
version 2; query warehouse `REPORTING_WH`).

## API routes

| Route | Methods | Snowflake object |
|---|---|---|
| `/api/drawdown-status` | GET | `APP.VW_DRAWDOWN_WELL_HEADER` — one row per well with latest drawdown, pressures, flows and reference data |
| `/api/timeseries` | GET | `APP.FN_DRAWDOWN_WELL_VALUES_LTTB` — downsampled series per attribute for one well (filtered to the well; see root README checklist) |
| `/api/well-attributes` | GET | `APP.VW_DRAWDOWN_WELL_MASTER` — fixed well attributes |
| `/api/commentary` | GET, POST, PUT, DELETE | `CORE_COMMON_MODEL.ASSET_COMMENTARY` (+ `ASSET` for business unit) |
| `/api/chart-annotations` | GET, POST | `CORE_COMMON_MODEL.ASSET_COMMENTARY` rows with `NOTE_JSON:signal` |
| `/api/version` | GET | none — returns `build-info.json` (git commit the deployed build came from) |

All object names are fully qualified with `CYGNET_TRANSFORMATION`.

## Layout

```
app/page.tsx                 renders the dashboard
app/api/*/route.ts           API routes above
components/drawdown-dashboard.tsx   well list
components/well-charts.tsx          ECharts time series + annotations
components/well-attributes.tsx      fixed attributes
components/commentary-panel.tsx     notes CRUD
components/ui/*              shadcn primitives
lib/snowflake.ts             connection + query helpers (SPCS OAuth token in the service, connections.toml locally)
lib/app-user.ts              resolves the signed-in user for note authorship
```

## Local development

```bash
npm ci
SNOWFLAKE_DEFAULT_CONNECTION_NAME=adamas_test npm run dev   # uses ~/.snowflake/connections.toml
npm test                                                    # vitest
npx tsc --noEmit
```

## Deploy

```bash
npm run deploy -- --connection <conn>
```

Always deploy through `npm run deploy`, not bare `snow app deploy`. It first
writes `build-info.json` (git commit, branch, dirty flag, timestamps), which
the Snowflake-side build cannot generate because `.git` is not uploaded. The
commit appears in the app header and at `/api/version`; a `-dirty` suffix
means uncommitted changes under `app/` were deployed.

The CLI uploads to `@APP.DRAWDOWN_MANAGEMENT_DAILY_CODE`, builds on the system
compute pool into `APP.DRAWDOWN_MANAGEMENT_DAILY_REPO`, and promotes a new
version. The deploy applies `app.yml` declaratively.
