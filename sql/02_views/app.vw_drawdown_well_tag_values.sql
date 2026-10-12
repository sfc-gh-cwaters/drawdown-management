create or replace view CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_TAG_VALUES(
	WELL_ASSET_ID COMMENT 'Common model asset identifier for the well (meters mapped back to parent well)',
	ATTR_ID COMMENT 'Tag-based attribute identifier (e.g. TUBING_PRESSURE, GAS_FLOW_RATE)',
	DATE_UTC COMMENT 'UTC date of the SCADA tag reading',
	TIMESTAMP_CENTRAL COMMENT 'Central timezone timestamp of the SCADA tag reading',
	DATE_CENTRAL COMMENT 'Central timezone date derived from the tag reading timestamp',
	VALUE_NUMBER COMMENT 'Numeric value of the SCADA tag reading',
	TAG_ID COMMENT 'CygNet SCADA tag identifier that produced the reading'
) COMMENT='Provides real-time tag-based attribute values for drawdown wells and their associated gas meters. Includes pressures, flow rates, choke, ESD status, and budget targets from the common model tag value store.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Returns real-time tag-based attribute readings for drawdown wells
                and their associated meters. Well-level attributes include
                tubing/casing pressure, choke output, ESD status, positive choke,
                target drawdown rate, and gas budget values. Meter-level
                attributes include gas/water flow rates and yesterday values.
Create Date:    10/02/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>    <Modified By>
--------------------------------------------------------------------------------
Notes:
  - Meter matching uses ENERTIA_COMPLETION_ID join between wells and meters.
  - Add new well attr_ids to the well_attrs CTE and new meter attr_ids to the
    meter_attrs CTE as needed.
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
        v.date_utc,
        CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc::TIMESTAMP_NTZ) AS timestamp_central,
        TO_DATE(CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc::TIMESTAMP_NTZ)) AS date_central,
        v.value_number,
        v.tag_id
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_TAG_VALUE v,
         meters m
    WHERE v.asset_id = m.meter_asset_id
        AND attr_id IN ('GAS_FLOW_RATE','GAS_FLOW_YESTERDAY','WATER_FLOW_RATE','WATER_FLOW_YESTERDAY')
),
well_attrs AS (
    SELECT
        w.asset_id AS well_asset_id,
        v.attr_id,
        v.date_utc,
        CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc::TIMESTAMP_NTZ) AS timestamp_central,
        TO_DATE(CONVERT_TIMEZONE('UTC', 'America/Chicago', v.timestamp_utc::TIMESTAMP_NTZ)) AS date_central,
        v.value_number,
        v.tag_id
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_TAG_VALUE v,
         cm_wells w
    WHERE v.asset_id = w.asset_id
        AND v.attr_id IN ('TUBING_PRESSURE','CASING_PRESSURE','CHOKE_OUTPUT','ESD_STATUS','POSITIVE_CHOKE','TARGET_DRAWDOWN_RATE','GAS_BUDGET','GAS_ADJ_BUDGET')
)
SELECT well_asset_id, attr_id, date_utc, timestamp_central, date_central, value_number, tag_id FROM well_attrs
UNION ALL
SELECT well_asset_id, attr_id, date_utc, timestamp_central, date_central, value_number, tag_id FROM meter_attrs;
