create or replace view CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_DAY_CALCULATED_LATEST(
	BUSINESS_UNIT COMMENT 'Business unit the asset belongs to',
	ASSET_ID COMMENT 'Unique asset identifier',
	ASSET_NAME COMMENT 'Human-readable display name for the asset',
	ASSET_TYPE_ID COMMENT 'Equipment type classification',
	ATTR_ID COMMENT 'Business-defined attribute identifier',
	ATTR_NAME COMMENT 'Full business-friendly attribute name',
	ATTR_CATEGORY COMMENT 'Grouping category (PRESSURE, FLOW, TEMPERATURE, etc.)',
	DATE_PERIOD COMMENT 'The production or measurement day',
	VERSION_NUMBER COMMENT 'Highest version number (latest revision)',
	VERSION_NAME COMMENT 'Descriptive version label of the latest revision',
	VALUE_NUMBER COMMENT 'Numeric value from the latest version',
	VALUE_TEXT COMMENT 'Text value from the latest version',
	VALUE_DATE COMMENT 'Date value from the latest version',
	VALUE_TIMESTAMP COMMENT 'Timestamp value from the latest version',
	VALUE_JSON COMMENT 'Semi-structured value from the latest version',
	CONTEXT COMMENT 'Additional context from the latest version',
	UNIT_ID COMMENT 'Unit of measure identifier',
	UNIT_NAME COMMENT 'Display name for the unit of measure',
	DATA_TYPE COMMENT 'Expected value type from attribute definition',
	RECORD_SOURCE COMMENT 'Source system that produced this daily value'
) COMMENT='Latest version of each daily calculated value per asset-attribute-day. Filters ASSET_ATTR_DAY to the highest VERSION_NUMBER per (ASSET_ID, ATTR_ID, DATE_PERIOD) using QUALIFY. Ideal for dashboards and reports needing the most current revision without version history.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Latest version of each daily calculated value per asset-attribute.
                Uses QUALIFY with ROW_NUMBER to pick only the highest
                VERSION_NUMBER per (ASSET_ID, ATTR_ID, DATE_PERIOD).
Create Date:    09/16/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>    <Modified By>
--------------------------------------------------------------------------------
Notes:
--------------------------------------------------------------------------------
*********************************************************************************/
SELECT
    A.BUSINESS_UNIT,
    A.ASSET_ID,
    A.ASSET_NAME,
    A.ASSET_TYPE_ID,
    AAD.ATTR_ID,
    AD.ATTR_NAME,
    AD.ATTR_CATEGORY,
    AAD.DATE_PERIOD,
    AAD.VERSION_NUMBER,
    AAD.VERSION_NAME,
    AAD.VALUE_NUMBER,
    AAD.VALUE_TEXT,
    AAD.VALUE_DATE,
    AAD.VALUE_TIMESTAMP,
    AAD.VALUE_JSON,
    AAD.CONTEXT,
    AD.UNIT_ID,
    U.UNIT_NAME,
    AD.DATA_TYPE,
    AAD.RECORD_SOURCE
FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET A
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR_DAY AAD
    ON A.ASSET_ID = AAD.ASSET_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ATTR_DFNTN AD
    ON AAD.ATTR_ID = AD.ATTR_ID
LEFT JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.UNIT_OF_MEASUREMENT U
    ON AD.UNIT_ID = U.UNIT_ID
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY AAD.ASSET_ID, AAD.ATTR_ID, AAD.DATE_PERIOD
    ORDER BY AAD.VERSION_NUMBER DESC
) = 1;
