create or replace view CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_HEADER(
	WELL_ASSET_ID COMMENT 'Common model asset identifier for the well',
	WELL_NAME COMMENT 'Well name from the EDW well completion master',
	DAILY_EST_DRAWDOWN COMMENT 'Latest daily estimated drawdown rate from VW_ASSET_ATTR_DAY_CALCULATED_LATEST',
	TUBING_PRESSURE COMMENT 'Most recent tubing pressure reading (psi) from SCADA tag',
	CASING_PRESSURE COMMENT 'Most recent casing pressure reading (psi) from SCADA tag',
	CHOKE_OUTPUT COMMENT 'Most recent choke output value from SCADA tag',
	ESD_STATUS COMMENT 'Most recent emergency shutdown status from SCADA tag',
	POSITIVE_CHOKE COMMENT 'Most recent positive choke indicator from SCADA tag',
	TARGET_DRAWDOWN_RATE COMMENT 'Configured target drawdown rate for the well',
	GAS_BUDGET COMMENT 'Gas budget target value for the well',
	GAS_ADJ_BUDGET COMMENT 'Adjusted gas budget target value for the well',
	GAS_FLOW_RATE COMMENT 'Most recent gas flow rate from the associated gas meter SCADA tag',
	GAS_FLOW_YESTERDAY COMMENT 'Previous day gas flow total from the associated gas meter SCADA tag',
	WATER_FLOW_RATE COMMENT 'Most recent water flow rate from the associated water meter SCADA tag',
	WATER_FLOW_YESTERDAY COMMENT 'Previous day water flow total from the associated water meter SCADA tag',
	COUNTY COMMENT 'County where the well is located, from EDW well completion master',
	STATE COMMENT 'State or province where the well is located',
	WELL_TYPE COMMENT 'Well classification type from EDW well completion master',
	PROCOUNT_AREA COMMENT 'ProCount operational area assignment from EDW well completion master',
	COMP_RESERVOIR COMMENT 'Completion target reservoir from EDW well completion master'
) COMMENT='Pivoted current-state header view for drawdown wells. Combines the latest tag values and daily estimated drawdown into a single wide row per well, joined with well master attributes for display in dashboards and reports.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Produces a single wide row per well containing the latest value
                for each drawdown attribute (pivoted from rows to columns) plus
                well master reference data. Uses QUALIFY to deduplicate tag and
                daily values before pivoting, then joins to the well master view
                for reference attributes. Designed for dashboard header display.

                Sources:
                  - CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET
                  - CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_DAY_CALCULATED_LATEST
                  - CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_MASTER

Create Date:    10/02/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>  <Modified By>

--------------------------------------------------------------------------------
Notes:
  - Uses PIVOT to transform attr_id rows into columns; new attributes require
    adding to the PIVOT IN list and the view column list.
  - DAILY_EST_DRAWDOWN is sourced separately from the calculated-latest view,
    not from the tag value views.
  - QUALIFY clauses deduplicate before pivoting to ensure one value per
    well/attribute combination.
--------------------------------------------------------------------------------

*********************************************************************************/
WITH rawvals AS (

    SELECT well_asset_id, attr_id, value_number
    FROM CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_TAG_VALUES_CURRENT
    QUALIFY ROW_NUMBER() OVER (PARTITION BY well_asset_id, attr_id
                               ORDER BY timestamp_central DESC NULLS LAST) = 1
    UNION ALL
    (WITH wells AS (
        SELECT asset_id AS well_asset_id
        FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET
        WHERE asset_type_id = 'WELL'
        and status = 'ACTIVE'
    )
    SELECT w.well_asset_id, a.attr_id, a.value_number
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_DAY_CALCULATED_LATEST a,
         wells w
    WHERE a.asset_id = w.well_asset_id
        AND attr_id = 'DAILY_EST_DRAWDOWN'

    QUALIFY ROW_NUMBER() OVER (PARTITION BY w.well_asset_id, a.attr_id
                               ORDER BY a.date_period DESC) = 1)
),
daily_vals AS (
    SELECT
        well_asset_id,
        DAILY_EST_DRAWDOWN, TUBING_PRESSURE, CASING_PRESSURE,
        CHOKE_OUTPUT, ESD_STATUS, POSITIVE_CHOKE,
        TARGET_DRAWDOWN_RATE, GAS_BUDGET, GAS_ADJ_BUDGET,
        GAS_FLOW_RATE, GAS_FLOW_YESTERDAY, WATER_FLOW_RATE,
        WATER_FLOW_YESTERDAY
    FROM rawvals
    PIVOT (MAX(value_number) FOR attr_id IN (
        'DAILY_EST_DRAWDOWN'    AS DAILY_EST_DRAWDOWN,
        'TUBING_PRESSURE'       AS TUBING_PRESSURE,
        'CASING_PRESSURE'       AS CASING_PRESSURE,
        'CHOKE_OUTPUT'          AS CHOKE_OUTPUT,
        'ESD_STATUS'            AS ESD_STATUS,
        'POSITIVE_CHOKE'        AS POSITIVE_CHOKE,
        'TARGET_DRAWDOWN_RATE'  AS TARGET_DRAWDOWN_RATE,
        'GAS_BUDGET'            AS GAS_BUDGET,
        'GAS_ADJ_BUDGET'        AS GAS_ADJ_BUDGET,
        'GAS_FLOW_RATE'         AS GAS_FLOW_RATE,
        'GAS_FLOW_YESTERDAY'    AS GAS_FLOW_YESTERDAY,
        'WATER_FLOW_RATE'       AS WATER_FLOW_RATE,
        'WATER_FLOW_YESTERDAY'  AS WATER_FLOW_YESTERDAY))
)
SELECT
    d.well_asset_id, w.well_name,
    d.DAILY_EST_DRAWDOWN, d.TUBING_PRESSURE, d.CASING_PRESSURE,
    d.CHOKE_OUTPUT, d.ESD_STATUS, d.POSITIVE_CHOKE,
    d.TARGET_DRAWDOWN_RATE, d.GAS_BUDGET, d.GAS_ADJ_BUDGET,
    d.GAS_FLOW_RATE, d.GAS_FLOW_YESTERDAY, d.WATER_FLOW_RATE,
    d.WATER_FLOW_YESTERDAY,
    w.county, w.state, w.well_type, w.procount_area, w.comp_reservoir
FROM daily_vals d,
     CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_MASTER w
WHERE d.well_asset_id = w.well_asset_id;
