# Drawdown Management App — User Access Permissions

**Account:** OPJQICB-DEV (Adamas) · **App:** `CYGNET_TRANSFORMATION.APP.DRAWDOWN_MANAGEMENT_DAILY` · **Updated:** 2026-10-06

The app runs with **owner's rights**: every query and comment write executes as the app's owning role, `CYGNET_ADMIN`. Users therefore need **no access to the underlying data** — only the three grants below on the role they use.

## Permissions required for a user's role

| # | Privilege | Object | Object type | Why it is needed |
|---|---|---|---|---|
| 1 | USAGE | `CYGNET_TRANSFORMATION` | Database | Resolve the app's database |
| 2 | USAGE | `CYGNET_TRANSFORMATION.APP` | Schema | Resolve the app's schema |
| 3 | USAGE | `CYGNET_TRANSFORMATION.APP.DRAWDOWN_MANAGEMENT_DAILY` | Application service | Open the app URL and use all features (view wells and charts, add / edit / delete comments and annotations) |

Grant script (replace `<ROLE>`):

```sql
GRANT USAGE ON DATABASE CYGNET_TRANSFORMATION TO ROLE <ROLE>;
GRANT USAGE ON SCHEMA CYGNET_TRANSFORMATION.APP TO ROLE <ROLE>;
GRANT USAGE ON APPLICATION SERVICE CYGNET_TRANSFORMATION.APP.DRAWDOWN_MANAGEMENT_DAILY TO ROLE <ROLE>;
GRANT ROLE <ROLE> TO USER <USER>;   -- if the user does not already have the role
```

## Not required for users

| Item | Reason |
|---|---|
| Warehouse USAGE | Queries run on the app's warehouse (`REPORTING_WH`) as `CYGNET_ADMIN` |
| SELECT on views, tables or functions | Data is read by `CYGNET_ADMIN`, not the user |
| INSERT / UPDATE / DELETE on `ASSET_COMMENTARY` | Comment writes run as `CYGNET_ADMIN`; the signed-in user is recorded as the author |
| Access to `EDW` database | Read by `CYGNET_ADMIN` through `VW_DRAWDOWN_WELL_MASTER` |

## Current role access (as of 2026-10-06)

| Role | App USAGE | Database USAGE | Schema USAGE | Can open the app |
|---|---|---|---|---|
| `CYGNET_ADMIN` | Owner | Yes | Yes | Yes |
| `EDW_OPERATIONS_RO` | Yes | Yes | Yes | Yes |
| `EDW_PLANNING_RO` | Yes | Not granted directly | Not granted directly | Only if inherited from another role — otherwise grant #1 and #2 |

## Notes

- Any user who can open the app sees all wells and can add, edit or delete any comment. Access is controlled only by who holds the three grants above.
- Users who can't reach the app usually have the role without grants #1–#2, or are signed in with a different default role.
- Optional operations roles: **OPERATE** on the service (suspend / resume / upgrade) and **MONITOR** (status and logs). Redeploys must use `CYGNET_ADMIN`, the owning role.
