CREATE OR REPLACE PROCEDURE CYGNET_TRANSFORMATION.APP.SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN("P_START_DATE" DATE, "P_END_DATE" DATE)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT='Calls SP_LOAD_WELL_DAILY_DRAWDOWN for every ACTIVE well in CORE_COMMON_MODEL.ASSET over the given date range. Idempotent.'
EXECUTE AS OWNER
AS '
BEGIN
    /********************************************************************************
    Author:         Chris Waters
    Description:    Iterates over all wells with STATUS = ''ACTIVE'' and calls
                    SP_LOAD_WELL_DAILY_DRAWDOWN for each. Per-well failures are
                    counted and do not abort the run.

                    Sources:
                      - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET
                      - CYGNET_TRANSFORMATION.APP.SP_LOAD_WELL_DAILY_DRAWDOWN
    Create Date:    10/05/2026
    --------------------------------------------------------------------------------
    Modification Log:
    --------------------------------------------------------------------------------
    <YYYY/MM/DD>    <Modified By>
    --------------------------------------------------------------------------------
    Notes:
      - Each well is its own transaction; a failed well leaves its prior data
        intact.
      - Failed well IDs are listed in the return value (visible in task
        history RETURN_VALUE). Re-running is safe.
    --------------------------------------------------------------------------------
    *********************************************************************************/
    DECLARE
        v_well_id     VARCHAR;
        v_processed   INT DEFAULT 0;
        v_failed      INT DEFAULT 0;
        v_failed_ids  VARCHAR DEFAULT '''';
        c_wells CURSOR FOR
            SELECT asset_id
            FROM cygnet_transformation.core_common_model.asset
            WHERE asset_type_id = ''WELL''
              AND status        = ''ACTIVE''
            ORDER BY asset_id;
    BEGIN
        FOR well IN c_wells DO
            v_well_id := well.asset_id;
            BEGIN
                CALL cygnet_transformation.app.sp_load_well_daily_drawdown(:v_well_id, :p_start_date, :p_end_date);
                v_processed := v_processed + 1;
            EXCEPTION
                WHEN OTHER THEN
                    v_failed     := v_failed + 1;
                    v_failed_ids := v_failed_ids || v_well_id || '' '';
            END;
        END FOR;

        RETURN ''Complete. Wells processed: '' || v_processed || '', Failed: '' || v_failed
            || IFF(v_failed > 0, '' ('' || TRIM(v_failed_ids) || '')'', '''');
    END;
END;
';
