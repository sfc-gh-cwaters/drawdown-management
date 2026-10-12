create or replace view CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR_TAG_VALUE(
	BUSINESS_UNIT COMMENT 'Business unit the asset belongs to',
	ASSET_ID COMMENT 'Unique asset identifier',
	ASSET_NAME COMMENT 'Human-readable display name for the asset',
	ASSET_TYPE_ID COMMENT 'Equipment type classification',
	ATTR_ID COMMENT 'Business-defined attribute identifier',
	ATTR_NAME COMMENT 'Full business-friendly attribute name',
	TAG_ID COMMENT 'Sensor/signal tag identifier',
	TAG_NAME COMMENT 'Source system tag name',
	DATE_UTC COMMENT 'UTC date of the measurement for partition pruning',
	TIMESTAMP_UTC COMMENT 'UTC timestamp of the measurement at full precision',
	TIMESTAMP_LOCAL COMMENT 'Local timezone timestamp of the measurement',
	VALUE_NUMBER COMMENT 'Numeric measurement value',
	VALUE_TEXT COMMENT 'Text measurement value',
	VALUE_JSON COMMENT 'Semi-structured measurement value',
	QUALITY COMMENT 'OPC-standard quality code (192=Good, 0=Bad)',
	UNIT_ID COMMENT 'Unit of measure identifier',
	UNIT_NAME COMMENT 'Display name for the unit of measure',
	DATA_TYPE COMMENT 'Expected value type from attribute definition',
	IS_STEP COMMENT 'TRUE if step/discrete signal; FALSE for continuous'
) COMMENT='Contextualized raw time series view. Joins ASSET_ATTR to TAG_VALUE through the TAG_ID linkage, enriched with ASSET, ATTR_DFNTN, and UNIT_OF_MEASUREMENT metadata. Each row is one sensor reading with full business context at native timestamp granularity.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Contextualized raw time series view. Joins asset attributes to
                their raw TAG_VALUE readings, providing business-friendly
                attribute names, asset metadata, and engineering units at native
                timestamp granularity.
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
    AA.TAG_ID,
    T.TAG_NAME,
    TV.DATE_UTC,
    TV.TIMESTAMP_UTC,
    TV.TIMESTAMP_LOCAL,
    TV.VALUE_NUMBER,
    TV.VALUE_TEXT,
    TV.VALUE_JSON,
    TV.QUALITY,
    COALESCE(TV.UNIT_ID, AA.UNIT_ID, AD.UNIT_ID) AS UNIT_ID,
    U.UNIT_NAME,
    AD.DATA_TYPE,
    AD.IS_STEP
FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET A
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR AA
    ON A.ASSET_ID = AA.ASSET_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ATTR_DFNTN AD
    ON AA.ATTR_ID = AD.ATTR_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.TAG T
    ON AA.TAG_ID = T.TAG_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.TAG_VALUE TV
    ON AA.TAG_ID = TV.TAG_ID
LEFT JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.UNIT_OF_MEASUREMENT U
    ON COALESCE(TV.UNIT_ID, AA.UNIT_ID, AD.UNIT_ID) = U.UNIT_ID
WHERE AA.TAG_ID IS NOT NULL;
