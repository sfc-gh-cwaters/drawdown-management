create or replace view CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT(
	WELL_ASSET_ID COMMENT 'Common model asset identifier for the well (meters mapped back to parent well)',
	ATTR_ID COMMENT 'Tag-based attribute identifier (e.g. TUBING_PRESSURE, GAS_FLOW_RATE)',
	DATE_CENTRAL COMMENT 'Central timezone date of the most recent SCADA tag reading',
	TIMESTAMP_CENTRAL COMMENT 'Central timezone timestamp of the most recent SCADA tag reading',
	VALUE_NUMBER COMMENT 'Numeric value of the most recent SCADA tag reading',
	TAG_ID COMMENT 'CygNet SCADA tag identifier that produced the reading'
) COMMENT='Provides the most recent (latest) tag-based attribute values for drawdown wells and their associated gas meters. Used as the current-state source for the drawdown well header view.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Returns the most recent tag-based attribute readings for drawdown
                wells and their associated meters using the latest variant of the
                common model tag value view. Same attribute set as
                VW_DRAWDOWN_WELL_TAG_VALUES but returns only the last known value.
Create Date:    10/02/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>    <Modified By>
--------------------------------------------------------------------------------
Notes:
  - Meter matching uses ENERTIA_COMPLETION_ID join between wells and meters.
  - Uses VW_ASSET_ATTR_TAG_VALUE_LATEST (not the historical variant) to
    return only the most recent reading per attribute.
--------------------------------------------------------------------------------
*********************************************************************************/
WITH cm_wells AS (
    SELECT asset_id, asset_name, value_text AS ENERTIA_COMPLETION_ID
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR
    WHERE asset_type_id = 'WELL'
        AND attr_id = 'ENERTIA_COMPLETION_ID'
        AND asset_status = 'ACTIVE'
),
cm_meters AS (
    SELECT asset_id, asset_name, value_text AS ENERTIA_COMPLETION_ID
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR
    WHERE asset_type_id IN ('MTRRUNG', 'MTRRUNW')
        AND attr_id = 'ENERTIA_COMPLETION_ID'
        AND ASSET_STATUS = 'ACTIVE'
),
meters AS (
    SELECT
        w.asset_id AS well_asset_id,
        m.asset_id AS meter_asset_id
    FROM cm_meters m,
         cm_wells w
    WHERE m.ENERTIA_COMPLETION_ID = w.ENERTIA_COMPLETION_ID
),
meter_attrs AS (
    SELECT
        m.well_asset_id,
        v.attr_id,
        TO_DATE(CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc_latest::TIMESTAMP_NTZ)) AS date_central,
        CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc_latest::TIMESTAMP_NTZ) AS timestamp_central,
        v.value_number,
        v.tag_id
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_TAG_VALUE_LATEST v,
         meters m
    WHERE v.asset_id = m.meter_asset_id
        AND v.attr_id IN ('GAS_FLOW_RATE','GAS_FLOW_YESTERDAY','WATER_FLOW_RATE','WATER_FLOW_YESTERDAY')
),
well_attrs AS (
    SELECT
        w.asset_id AS well_asset_id,
        v.attr_id,
        TO_DATE(CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc_latest::TIMESTAMP_NTZ)) AS date_central,
        CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc_latest::TIMESTAMP_NTZ) AS timestamp_central,
        v.value_number,
        v.tag_id
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_TAG_VALUE_LATEST v,
         cm_wells w
    WHERE v.asset_id = w.asset_id
        AND v.attr_id IN ('TUBING_PRESSURE','CASING_PRESSURE','CHOKE_OUTPUT','ESD_STATUS','POSITIVE_CHOKE','TARGET_DRAWDOWN_RATE','GAS_BUDGET','GAS_ADJ_BUDGET')
)
SELECT well_asset_id, attr_id, date_central, timestamp_central, value_number, tag_id FROM well_attrs
UNION ALL
SELECT well_asset_id, attr_id, date_central, timestamp_central, value_number, tag_id FROM meter_attrs;
