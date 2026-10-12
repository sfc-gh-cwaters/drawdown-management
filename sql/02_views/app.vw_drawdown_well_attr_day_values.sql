create or replace view CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_ATTR_DAY_VALUES(
	WELL_ASSET_ID COMMENT 'Common model asset identifier for the well',
	ATTR_ID COMMENT 'Day-level attribute identifier (e.g. DAILY_EST_DRAWDOWN)',
	DATE_UTC COMMENT 'Always NULL; daily values have no intraday UTC timestamp',
	TIMESTAMP_CENTRAL COMMENT 'Day period cast to timestamp in Central timezone',
	DATE_CENTRAL COMMENT 'Calendar date of the daily attribute value in Central timezone',
	VALUE_NUMBER COMMENT 'Numeric value of the daily attribute measurement',
	TAG_ID COMMENT 'Always NULL; daily values are not sourced from SCADA tags'
) COMMENT='Retrieves daily estimated drawdown values for wells from the common model day-level attribute store. Provides the daily component of drawdown analytics alongside real-time tag values.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Retrieves daily estimated drawdown (DAILY_EST_DRAWDOWN) values
                for each well from the common model day-level attribute store.
                Outputs are shaped to align with the tag-based value views for
                UNION compatibility in VW_DRAWDOWN_WELL_ATTR_ALL_VALUES.
Create Date:    10/02/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>    <Modified By>
--------------------------------------------------------------------------------
Notes:
  - DATE_UTC and TAG_ID are NULL by design; daily values have no intraday
    timestamp or tag association.
  - Only DAILY_EST_DRAWDOWN is included; add new daily attr_ids to the
    WHERE clause as needed.
--------------------------------------------------------------------------------
*********************************************************************************/
WITH cm_wells AS (
    SELECT asset_id, asset_name, value_text AS api_number
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR
    WHERE asset_type_id = 'WELL'
        AND attr_name = 'ENERTIA_COMPLETION_ID'
        AND asset_status = 'ACTIVE'
)
SELECT
    w.asset_id AS well_asset_id,
    v.attr_id,
    NULL AS date_utc,
    TO_TIMESTAMP(v.date_period) AS timestamp_central,
    v.date_period AS date_central,
    v.value_number,
    NULL AS tag_id
FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR_DAY v,
     cm_wells w
WHERE v.asset_id = w.asset_id
    AND v.attr_id IN ('DAILY_EST_DRAWDOWN');
