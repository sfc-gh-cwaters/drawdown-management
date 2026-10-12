-- =============================================================================
-- Privileges needed to deploy and run DRAWDOWN_MANAGEMENT_DAILY
-- (Snowflake App Runtime) in CYGNET_TRANSFORMATION.APP as CYGNET_ADMIN.
-- Mirrors what CYGNET_ADMIN holds on TEST (OPJQICB-TEST). Run as an admin role
-- in the target account; skip any grant the role already has.
-- =============================================================================

-- Deploy: the CLI creates the service, its <NAME>_REPO artifact repository and
-- <NAME>_CODE stage in the app schema.
GRANT CREATE APPLICATION SERVICE ON SCHEMA CYGNET_TRANSFORMATION.APP TO ROLE CYGNET_ADMIN;
GRANT CREATE ARTIFACT REPOSITORY ON SCHEMA CYGNET_TRANSFORMATION.APP TO ROLE CYGNET_ADMIN;
GRANT CREATE STAGE               ON SCHEMA CYGNET_TRANSFORMATION.APP TO ROLE CYGNET_ADMIN;

-- Expose the app endpoint (on TEST this comes through PUBLIC).
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE CYGNET_ADMIN;

-- Query warehouse used by the app (app.yml: query_warehouse) and the daily task.
GRANT USAGE ON WAREHOUSE REPORTING_WH TO ROLE CYGNET_ADMIN;

-- Daily drawdown task.
GRANT EXECUTE TASK ON ACCOUNT TO ROLE CYGNET_ADMIN;

-- CYGNET_ADMIN owns CYGNET_TRANSFORMATION and its schemas on TEST, which covers
-- SELECT on the views/functions and INSERT/UPDATE/DELETE on ASSET_COMMENTARY.
-- End-user access to the app is separate: see docs/drawdown-app-user-permissions.md.
