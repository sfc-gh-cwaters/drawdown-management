CREATE OR REPLACE FUNCTION CYGNET_TRANSFORMATION.APP.FN_DRAWDOWN_WELL_VALUES_LTTB("P_START_TS" TIMESTAMP_NTZ(9), "P_END_TS" TIMESTAMP_NTZ(9), "P_WELL_ASSET_ID" VARCHAR, "P_NUM_POINTS" NUMBER(38,0))
RETURNS TABLE ("WELL_ASSET_ID" VARCHAR, "ATTR_ID" VARCHAR, "TIMESTAMP_CENTRAL" TIMESTAMP_NTZ(9), "VALUE_NUMBER" FLOAT)
LANGUAGE SQL
COMMENT='Applies Largest Triangle Three Buckets (LTTB) downsampling to drawdown well attribute time series. Returns a reduced point set that preserves visual fidelity for charting. Combines tag-based and daily estimated drawdown values with seed interpolation.'
AS '
/********************************************************************************
Author:         Chris Waters
Description:    Applies the Largest Triangle Three Buckets (LTTB) downsampling
                algorithm to drawdown well attribute time series data. Combines
                real-time tag values, daily estimated drawdown, and seed values
                (last known reading before the requested range) into a unified
                dataset, then reduces to P_NUM_POINTS per well/attribute while
                preserving visual shape for charting.
Create Date:    10/02/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>    <Modified By>
--------------------------------------------------------------------------------
Notes:
  - LTTB is a simplified SQL implementation; bucket boundaries are computed
    via FLOOR arithmetic rather than true iterative triangle selection.
  - Seed values provide continuity at chart edges by carrying the last known
    reading before P_START_TS.
  - If total points <= P_NUM_POINTS, all points are returned unmodified.
--------------------------------------------------------------------------------
*********************************************************************************/
WITH
-- ============================================================
-- DATA SOURCING (same pattern as FN_DRAWDOWN_WELL_VALUES)
-- ============================================================
cm_wells AS (
    SELECT asset_id, asset_name, value_text AS ENERTIA_COMPLETION_ID
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR
    WHERE asset_type_id = ''WELL''
        AND attr_id = ''ENERTIA_COMPLETION_ID''
        AND asset_status = ''ACTIVE''
),
cm_meters AS (
    SELECT asset_id, asset_name, value_text AS ENERTIA_COMPLETION_ID
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR
    WHERE asset_type_id IN (''MTRRUNG'', ''MTRRUNW'')
        AND attr_id = ''ENERTIA_COMPLETION_ID''
        AND ASSET_STATUS = ''ACTIVE''
),
meters AS (
    SELECT
        w.asset_id AS well_asset_id,
        m.asset_id AS meter_asset_id
    FROM cm_meters m,
         cm_wells w
    WHERE m.ENERTIA_COMPLETION_ID = w.ENERTIA_COMPLETION_ID
),
all_well_tags AS (
    SELECT w.asset_id AS well_asset_id, aa.attr_id, aa.tag_id
    FROM cm_wells w
    JOIN cygnet_transformation.core_common_model.asset_attr aa ON aa.asset_id = w.asset_id
    WHERE aa.attr_id IN (''TUBING_PRESSURE'',''CASING_PRESSURE'',''CHOKE_OUTPUT'',''ESD_STATUS'',
                         ''POSITIVE_CHOKE'',''TARGET_DRAWDOWN_RATE'',''GAS_BUDGET'',''GAS_ADJ_BUDGET'')
      AND aa.tag_id IS NOT NULL
),
all_meter_tags AS (
    SELECT m.well_asset_id, aa.attr_id, aa.tag_id
    FROM meters m
    JOIN cygnet_transformation.core_common_model.asset_attr aa ON aa.asset_id = m.meter_asset_id
    WHERE aa.attr_id IN (''GAS_FLOW_RATE'',''GAS_FLOW_YESTERDAY'',''WATER_FLOW_RATE'',''WATER_FLOW_YESTERDAY'')
      AND aa.tag_id IS NOT NULL
),
all_tags AS (
    SELECT DISTINCT well_asset_id, attr_id, tag_id FROM (
        SELECT well_asset_id, attr_id, tag_id FROM all_well_tags
        UNION ALL
        SELECT well_asset_id, attr_id, tag_id FROM all_meter_tags
    )
),
-- Last known value before range start — one per (well, attr)
seeds AS (
    SELECT well_asset_id, attr_id, p_start_ts AS timestamp_central, value_number_last AS value_number
    FROM (
        SELECT t.well_asset_id, t.attr_id, tvd.value_number_last, tvd.date_utc,
               ROW_NUMBER() OVER (PARTITION BY t.well_asset_id, t.attr_id ORDER BY tvd.date_utc DESC) AS rn
        FROM all_tags t
        JOIN cygnet_transformation.core_common_model.tag_value_day tvd
            ON tvd.tag_id = t.tag_id AND tvd.date_utc < p_start_ts::DATE
    )
    WHERE rn = 1
),
-- Actual observations within range (non-null), deduped per (well, attr, timestamp)
filtered AS (
    SELECT well_asset_id, attr_id, timestamp_central, value_number
    FROM cygnet_transformation.APP.vw_drawdown_well_tag_values
    WHERE date_utc BETWEEN p_start_ts::DATE AND p_end_ts::DATE
      AND timestamp_central >= p_start_ts
      AND timestamp_central <= p_end_ts
      AND value_number IS NOT NULL
      AND (p_well_asset_id IS NULL OR well_asset_id = p_well_asset_id)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY well_asset_id, attr_id, timestamp_central
        ORDER BY timestamp_central) = 1
),
-- DAILY_EST_DRAWDOWN from asset_attr_day (one value per well per day, no interpolation)
drawdown_daily AS (
    SELECT
        aad.asset_id AS well_asset_id,
        aad.attr_id,
        TO_TIMESTAMP_NTZ(aad.date_period) AS timestamp_central,
        aad.value_number
    FROM cygnet_transformation.core_common_model.asset_attr_day aad
    JOIN cm_wells w ON w.asset_id = aad.asset_id
    WHERE aad.attr_id        = ''DAILY_EST_DRAWDOWN''
      AND aad.version_number = 1
      AND aad.value_number   IS NOT NULL
      AND aad.date_period    BETWEEN p_start_ts::DATE AND p_end_ts::DATE
),
-- Merge seeds, tag-based data, and daily drawdown
combined AS (
    SELECT well_asset_id, attr_id, timestamp_central, value_number
    FROM (
        SELECT well_asset_id, attr_id, timestamp_central, value_number, 1 AS src_priority FROM filtered
        UNION ALL
        SELECT well_asset_id, attr_id, timestamp_central, value_number, 1 AS src_priority FROM drawdown_daily
        UNION ALL
        SELECT well_asset_id, attr_id, timestamp_central, value_number, 2 AS src_priority FROM seeds
        WHERE value_number IS NOT NULL
    )
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY well_asset_id, attr_id, timestamp_central
        ORDER BY src_priority) = 1
),

-- ============================================================
-- LTTB — Largest Triangle Three Buckets (simplified SQL version)
-- ============================================================
numbered AS (
    SELECT
        well_asset_id, attr_id, timestamp_central, value_number,
        ROW_NUMBER() OVER (PARTITION BY well_asset_id, attr_id ORDER BY timestamp_central) - 1 AS rn,
        COUNT(*)      OVER (PARTITION BY well_asset_id, attr_id) AS total_count
    FROM combined
),
bucketed AS (
    SELECT *,
        CASE
            WHEN total_count <= p_num_points THEN rn
            WHEN rn = 0                      THEN 0
            WHEN rn = total_count - 1        THEN p_num_points - 1
            ELSE FLOOR(((rn - 1) * (p_num_points - 2.0)) / NULLIF(total_count - 2, 0)) + 1
        END AS bucket_id,
        DATEDIFF(''second'', p_start_ts, timestamp_central) AS ts_sec
    FROM numbered
),
bucket_avgs AS (
    SELECT well_asset_id, attr_id, bucket_id,
           AVG(ts_sec)       AS avg_ts,
           AVG(value_number) AS avg_val
    FROM bucketed
    GROUP BY well_asset_id, attr_id, bucket_id
),
scored AS (
    SELECT
        b.well_asset_id, b.attr_id, b.timestamp_central, b.value_number,
        b.bucket_id, b.total_count,
        CASE
            WHEN b.total_count <= p_num_points          THEN 1
            WHEN b.bucket_id = 0                        THEN 1
            WHEN b.bucket_id = p_num_points - 1         THEN 1
            ELSE ABS(
                   (pa.avg_ts  - na.avg_ts) * (b.value_number - pa.avg_val)
                 - (pa.avg_ts  - b.ts_sec)  * (na.avg_val     - pa.avg_val)
                 ) * 0.5
        END AS triangle_area
    FROM bucketed b
    LEFT JOIN bucket_avgs pa
        ON  pa.well_asset_id = b.well_asset_id
        AND pa.attr_id       = b.attr_id
        AND pa.bucket_id     = b.bucket_id - 1
    LEFT JOIN bucket_avgs na
        ON  na.well_asset_id = b.well_asset_id
        AND na.attr_id       = b.attr_id
        AND na.bucket_id     = b.bucket_id + 1
)
SELECT well_asset_id, attr_id, timestamp_central, value_number
FROM scored
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY well_asset_id, attr_id, bucket_id
    ORDER BY triangle_area DESC, timestamp_central
) = 1';
