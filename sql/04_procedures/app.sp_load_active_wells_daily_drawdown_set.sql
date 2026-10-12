CREATE OR REPLACE PROCEDURE CYGNET_TRANSFORMATION.APP.SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN_SET("P_START_DATE" DATE, "P_END_DATE" DATE, "P_CHUNK_DAYS" NUMBER(38,0) DEFAULT 90)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT='Set-based load of DAILY_EST_DRAWDOWN into ASSET_ATTR_DAY for every ACTIVE well: one TAG_VALUE scan and one FN_EST_DAILY_DRAWDOWN_CORE call (partitioned by well) per chunk. Idempotent.'
EXECUTE AS OWNER
AS '
/********************************************************************************
Author:         Chris Waters
Description:    Set-based replacement for SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN.
                For each chunk of P_CHUNK_DAYS days, reads TUBING_PRESSURE for
                all ACTIVE wells in a single scan, runs FN_EST_DAILY_DRAWDOWN_CORE
                once partitioned by well, stages results in a temp table, then
                replaces the chunk''s DAILY_EST_DRAWDOWN rows in one transaction.

                Sources:
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ATTR_DFNTN
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.TAG
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.TAG_VALUE
                  - CYGNET_TRANSFORMATION.APP.FN_EST_DAILY_DRAWDOWN_CORE (function)
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR_DAY (target)
Create Date:    10/12/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
2026/10/12      Chris Waters
                Calls SYSTEM$SET_RETURN_VALUE with the run summary so task
                history RETURN_VALUE shows wells/deleted/inserted counts.
--------------------------------------------------------------------------------
Notes:
  - Same reading window and filters as FN_EST_DAILY_DRAWDOWN (21 days before
    the chunk start, one UTC day after the chunk end), so per-well results
    match the per-well procedure for the same date range.
  - A failure rolls back the current chunk only; earlier chunks stay committed.
    Re-running is safe.
  - Days with a NULL delta are not inserted.
  - SYSTEM$SET_RETURN_VALUE errors outside a task; that error is ignored so
    manual CALLs still work.
--------------------------------------------------------------------------------
*********************************************************************************/
DECLARE
    v_chunk_start DATE;
    v_chunk_end   DATE;
    v_chunks      INT DEFAULT 0;
    v_wells       INT DEFAULT 0;
    v_deleted     INT DEFAULT 0;
    v_inserted    INT DEFAULT 0;
    v_result      VARCHAR;
BEGIN
    IF (p_end_date < p_start_date OR p_chunk_days < 1) THEN
        RETURN ''Invalid arguments: end date before start date or chunk days < 1'';
    END IF;

    SELECT COUNT(*) INTO :v_wells
    FROM cygnet_transformation.core_common_model.asset
    WHERE asset_type_id = ''WELL'' AND status = ''ACTIVE'';

    v_chunk_start := p_start_date;
    WHILE (v_chunk_start <= p_end_date) DO
        v_chunk_end := LEAST(DATEADD(day, p_chunk_days - 1, v_chunk_start), p_end_date);

        CREATE OR REPLACE TEMPORARY TABLE tmp_daily_drawdown AS
        WITH tp_tags AS (
            SELECT aa.asset_id, aa.tag_id
            FROM cygnet_transformation.core_common_model.asset a
            JOIN cygnet_transformation.core_common_model.asset_attr aa ON aa.asset_id = a.asset_id
            JOIN cygnet_transformation.core_common_model.attr_dfntn ad ON ad.attr_id = aa.attr_id
            JOIN cygnet_transformation.core_common_model.tag t         ON t.tag_id   = aa.tag_id
            WHERE a.asset_type_id = ''WELL''
              AND a.status        = ''ACTIVE''
              AND aa.attr_id      = ''TUBING_PRESSURE''
              AND aa.tag_id IS NOT NULL
        ),
        readings AS (
            SELECT DISTINCT
                g.asset_id,
                CONVERT_TIMEZONE(''UTC'', ''America/Chicago'', tv.timestamp_utc::TIMESTAMP_NTZ) AS ts,
                tv.value_number::FLOAT AS tp
            FROM cygnet_transformation.core_common_model.tag_value tv
            JOIN tp_tags g ON g.tag_id = tv.tag_id
            WHERE tv.value_number IS NOT NULL
              AND tv.date_utc BETWEEN DATEADD(day, -21, :v_chunk_start) AND DATEADD(day, 1, :v_chunk_end)
        )
        SELECT r.asset_id, c.date_period, c.delta_tubing_pressure
        FROM readings r,
             TABLE(cygnet_transformation.app.fn_est_daily_drawdown_core(
                       r.ts, r.tp, :v_chunk_start::DATE, :v_chunk_end::DATE)
                   OVER (PARTITION BY r.asset_id ORDER BY r.ts)) c;

        BEGIN TRANSACTION;

        DELETE FROM cygnet_transformation.core_common_model.asset_attr_day d
        USING cygnet_transformation.core_common_model.asset a
        WHERE d.asset_id      = a.asset_id
          AND a.asset_type_id = ''WELL''
          AND a.status        = ''ACTIVE''
          AND d.attr_id       = ''DAILY_EST_DRAWDOWN''
          AND d.date_period BETWEEN :v_chunk_start AND :v_chunk_end;
        v_deleted := v_deleted + SQLROWCOUNT;

        INSERT INTO cygnet_transformation.core_common_model.asset_attr_day (
            asset_id, attr_id, date_period, version_number,
            value_number, create_author, create_timestamp, record_source
        )
        SELECT asset_id, ''DAILY_EST_DRAWDOWN'', date_period, 1,
               delta_tubing_pressure, CURRENT_USER(), CURRENT_TIMESTAMP(),
               ''SP_LOAD_ACTIVE_WELLS_DAILY_DRAWDOWN_SET''
        FROM tmp_daily_drawdown
        WHERE delta_tubing_pressure IS NOT NULL;
        v_inserted := v_inserted + SQLROWCOUNT;

        COMMIT;

        v_chunks      := v_chunks + 1;
        v_chunk_start := DATEADD(day, 1, v_chunk_end);
    END WHILE;

    DROP TABLE IF EXISTS tmp_daily_drawdown;

    v_result := ''Complete. Active wells: '' || v_wells || '', chunks: '' || v_chunks
        || '', deleted: '' || v_deleted || '', inserted: '' || v_inserted;

    BEGIN
        CALL SYSTEM$SET_RETURN_VALUE(:v_result);
    EXCEPTION
        WHEN OTHER THEN
            NULL;
    END;

    RETURN v_result;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
';
