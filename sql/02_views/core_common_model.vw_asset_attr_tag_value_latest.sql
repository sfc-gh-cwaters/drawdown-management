create or replace view CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_TAG_VALUE_LATEST(
	BUSINESS_UNIT COMMENT 'Business unit the asset belongs to',
	ASSET_ID COMMENT 'Unique asset identifier',
	ASSET_NAME COMMENT 'Human-readable display name for the asset',
	ASSET_TYPE_ID COMMENT 'Equipment type classification',
	ATTR_ID COMMENT 'Business-defined attribute identifier',
	ATTR_NAME COMMENT 'Full business-friendly attribute name',
	ATTR_CATEGORY COMMENT 'Grouping category (PRESSURE, FLOW, TEMPERATURE, etc.)',
	TAG_ID COMMENT 'Sensor/signal tag identifier',
	TAG_NAME COMMENT 'Source system tag name',
	TIMESTAMP_UTC_LATEST COMMENT 'UTC timestamp of the most recently received value',
	VALUE_NUMBER COMMENT 'Most recent numeric measurement value',
	VALUE_TEXT COMMENT 'Most recent text measurement value',
	VALUE_JSON COMMENT 'Most recent semi-structured measurement value',
	UNIT_ID COMMENT 'Unit of measure identifier',
	UNIT_NAME COMMENT 'Display name for the unit of measure',
	DATA_TYPE COMMENT 'Expected value type from attribute definition',
	ASSET_STATUS COMMENT 'Lifecycle status of the asset',
	ATTR_STATUS COMMENT 'Lifecycle status of the attribute assignment'
) COMMENT='Latest known value per asset-attribute-tag combination. Sources from TAG_VALUE_CURRENT for fast point-in-time lookups. Enriched with ASSET, ATTR_DFNTN, TAG, and UNIT_OF_MEASUREMENT metadata. Ideal for real-time dashboards and current-state queries.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Latest known tag value per asset-attribute. Uses TAG_VALUE_CURRENT
                to provide fast point-in-time lookups for real-time dashboards
                and current-state queries.
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
    AA.ATTR_ID,
    AD.ATTR_NAME,
    AD.ATTR_CATEGORY,
    AA.TAG_ID,
    T.TAG_NAME,
    TVC.TIMESTAMP_UTC_LATEST,
    TVC.VALUE_NUMBER,
    TVC.VALUE_TEXT,
    TVC.VALUE_JSON,
    COALESCE(TVC.UNIT_UID, AA.UNIT_ID, AD.UNIT_ID) AS UNIT_ID,
    U.UNIT_NAME,
    AD.DATA_TYPE,
    A.STATUS                AS ASSET_STATUS,
    AA.STATUS               AS ATTR_STATUS
FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET A
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR AA
    ON A.ASSET_ID = AA.ASSET_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ATTR_DFNTN AD
    ON AA.ATTR_ID = AD.ATTR_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.TAG T
    ON AA.TAG_ID = T.TAG_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.TAG_VALUE_CURRENT TVC
    ON AA.TAG_ID = TVC.TAG_ID
LEFT JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.UNIT_OF_MEASUREMENT U
    ON COALESCE(TVC.UNIT_UID, AA.UNIT_ID, AD.UNIT_ID) = U.UNIT_ID
WHERE AA.TAG_ID IS NOT NULL;
