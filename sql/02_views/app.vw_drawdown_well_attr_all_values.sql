create or replace view CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_ATTR_ALL_VALUES(
	WELL_ASSET_ID COMMENT 'Common model asset identifier for the well',
	ATTR_ID COMMENT 'Attribute identifier (e.g. TUBING_PRESSURE, GAS_FLOW_RATE, DAILY_EST_DRAWDOWN)',
	DATE_UTC COMMENT 'UTC timestamp of the tag reading; NULL for daily-sourced values',
	TIMESTAMP_CENTRAL COMMENT 'Central timezone timestamp of the reading or day period',
	DATE_CENTRAL COMMENT 'Central timezone date of the reading or day period',
	VALUE_NUMBER COMMENT 'Numeric value of the attribute measurement',
	TAG_ID COMMENT 'CygNet SCADA tag identifier; NULL for daily-sourced values'
) COMMENT='Consolidates all drawdown-related well attribute values into a single view by unioning daily estimated drawdown values with real-time tag-based readings (pressures, flow rates, choke, ESD, budgets). Serves as the unified data layer for downstream drawdown analytics and reporting.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Consolidates all drawdown-related well attribute values into a
                single queryable view. Unions daily estimated drawdown values
                with real-time tag-based readings for a unified data layer.
Create Date:    10/02/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>    <Modified By>
--------------------------------------------------------------------------------
Notes:
  - Add new attribute sources to the UNION ALL as additional drawdown metrics
    are onboarded.
  - Source views filter on specific attr_id values; new attributes must be
    added in the respective source view, not here.
--------------------------------------------------------------------------------
*********************************************************************************/
SELECT WELL_ASSET_ID, ATTR_ID, DATE_UTC, TIMESTAMP_CENTRAL, DATE_CENTRAL, VALUE_NUMBER, TAG_ID
FROM CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_ATTR_DAY_VALUES
UNION ALL
SELECT WELL_ASSET_ID, ATTR_ID, DATE_UTC, TIMESTAMP_CENTRAL, DATE_CENTRAL, VALUE_NUMBER, TAG_ID
FROM CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_TAG_VALUES;
