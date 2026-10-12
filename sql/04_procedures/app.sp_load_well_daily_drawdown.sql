CREATE OR REPLACE PROCEDURE CYGNET_TRANSFORMATION.APP.SP_LOAD_WELL_DAILY_DRAWDOWN("P_WELL_ASSET_ID" VARCHAR, "P_START_DATE" DATE, "P_END_DATE" DATE)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT='Replaces DAILY_EST_DRAWDOWN rows in ASSET_ATTR_DAY for one well and date range with the output of FN_EST_DAILY_DRAWDOWN. Idempotent (delete + insert in a single transaction).'
EXECUTE AS OWNER
AS '
BEGIN
    /********************************************************************************
    Author:         Chris Waters
    Description:    For a single well, deletes existing DAILY_EST_DRAWDOWN rows in
                    ASSET_ATTR_DAY for the requested date range and inserts fresh
                    values from FN_EST_DAILY_DRAWDOWN. Delete and insert run in one
                    transaction, so re-running with the same inputs yields the same
                    result.

                    Sources:
                      - CYGNET_TRANSFORMATION.APP.FN_EST_DAILY_DRAWDOWN (function)
                      - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR_DAY (target)
    Create Date:    10/05/2026
    --------------------------------------------------------------------------------
    Modification Log:
    --------------------------------------------------------------------------------
    <YYYY/MM/DD>    <Modified By>
    --------------------------------------------------------------------------------
    Notes:
      - Delete is scoped to P_START_DATE..P_END_DATE so rolling daily runs do not
        remove history outside the window.
      - Days with a NULL delta (no declining periods) are not inserted.
      - Rolls back and re-raises on error.
    --------------------------------------------------------------------------------
    *********************************************************************************/
    DECLARE
        v_deleted  INT DEFAULT 0;
        v_inserted INT DEFAULT 0;
    BEGIN
        BEGIN TRANSACTION;

        DELETE FROM cygnet_transformation.core_common_model.asset_attr_day
        WHERE asset_id    = :p_well_asset_id
          AND attr_id     = ''DAILY_EST_DRAWDOWN''
          AND date_period BETWEEN :p_start_date AND :p_end_date;
        v_deleted := SQLROWCOUNT;

        INSERT INTO cygnet_transformation.core_common_model.asset_attr_day (
            asset_id, attr_id, date_period, version_number,
            value_number, create_author, create_timestamp, record_source
        )
        SELECT
            well_asset_id, ''DAILY_EST_DRAWDOWN'', date_period, 1,
            delta_tubing_pressure, CURRENT_USER(), CURRENT_TIMESTAMP(), ''SP_LOAD_WELL_DAILY_DRAWDOWN''
        FROM TABLE(cygnet_transformation.app.fn_est_daily_drawdown(
            :p_well_asset_id, :p_start_date, :p_end_date
        ))
        WHERE delta_tubing_pressure IS NOT NULL;
        v_inserted := SQLROWCOUNT;

        COMMIT;

        RETURN ''Well '' || :p_well_asset_id || '': deleted '' || v_deleted || '', inserted '' || v_inserted;
    EXCEPTION
        WHEN OTHER THEN
            ROLLBACK;
            RAISE;
    END;
END;
';
