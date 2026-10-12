create or replace view CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR(
	BUSINESS_UNIT COMMENT 'Business unit the asset belongs to',
	ASSET_ID COMMENT 'Unique identifier for the equipment instance',
	ASSET_NAME COMMENT 'Human-readable display name for the asset',
	ASSET_TYPE_ID COMMENT 'Equipment type classification (e.g., WELL, MTRRUNG)',
	ASSET_STATUS COMMENT 'Lifecycle status of the asset (ACTIVE, INACTIVE, etc.)',
	ATTR_ID COMMENT 'Business-defined attribute identifier (e.g., INLET_PRESSURE)',
	ATTR_NAME COMMENT 'Full business-friendly attribute name from ATTR_DFNTN',
	ATTR_SHORT_NAME COMMENT 'Abbreviated attribute name for compact displays',
	ATTR_CATEGORY COMMENT 'Grouping category (PRESSURE, FLOW, TEMPERATURE, etc.)',
	DATA_TYPE COMMENT 'Expected value type: TEXT, NUMBER, DATE, or TIMESTAMP',
	VALUE_TEXT COMMENT 'Text value when DATA_TYPE is TEXT',
	VALUE_NUMBER COMMENT 'Numeric value when DATA_TYPE is NUMBER',
	VALUE_DATE COMMENT 'Date value when DATA_TYPE is DATE',
	VALUE_TIMESTAMP COMMENT 'Timestamp value when DATA_TYPE is TIMESTAMP',
	VALUE_JSON COMMENT 'Semi-structured value for complex attribute data',
	TAG_ID COMMENT 'Associated sensor/signal tag identifier (NULL for static attributes)',
	TAG_NAME COMMENT 'Source system tag name from the historian/SCADA',
	TAG_TYPE COMMENT 'Data type of values the linked tag produces',
	TAG_STATUS COMMENT 'Lifecycle status of the linked tag',
	UNIT_ID COMMENT 'Unit of measure identifier',
	UNIT_NAME COMMENT 'Display name for the unit of measure',
	UNIT_CATEGORY COMMENT 'Physical quantity category of the unit (PRESSURE, FLOW_RATE, etc.)',
	ATTR_STATUS COMMENT 'Lifecycle status of this attribute assignment',
	ATTR_DESCRIPTION COMMENT 'Detailed description of what this attribute measures',
	IS_STEP COMMENT 'TRUE if step/discrete signal; FALSE for continuous',
	DECIMAL_PLACES COMMENT 'Display precision for numeric values'
) COMMENT='Enriched asset-attribute view. Denormalizes ASSET, ASSET_ATTR, ATTR_DFNTN, TAG, and UNIT_OF_MEASUREMENT into a single row per asset-attribute pair. Provides full business context for each attribute including equipment info, attribute definitions, linked tag metadata, and engineering units.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Enriched asset-attribute view that denormalizes the core
                contextualization tables (ASSET, ASSET_ATTR, ATTR_DFNTN, TAG,
                UNIT_OF_MEASUREMENT) into a single queryable row per asset-attribute pair.
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
    A.STATUS                AS ASSET_STATUS,
    AA.ATTR_ID,
    AD.ATTR_NAME,
    AD.ATTR_SHORT_NAME,
    AD.ATTR_CATEGORY,
    AD.DATA_TYPE,
    AA.VALUE_TEXT,
    AA.VALUE_NUMBER,
    AA.VALUE_DATE,
    AA.VALUE_TIMESTAMP,
    AA.VALUE_JSON,
    AA.TAG_ID,
    T.TAG_NAME,
    T.TAG_TYPE,
    T.STATUS                AS TAG_STATUS,
    COALESCE(AA.UNIT_ID, AD.UNIT_ID) AS UNIT_ID,
    U.UNIT_NAME,
    U.UNIT_CATEGORY,
    AA.STATUS               AS ATTR_STATUS,
    AD.DESCRIPTION          AS ATTR_DESCRIPTION,
    AD.IS_STEP,
    AD.DECIMAL_PLACES
FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET A
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_ATTR AA
    ON A.ASSET_ID = AA.ASSET_ID
JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ATTR_DFNTN AD
    ON AA.ATTR_ID = AD.ATTR_ID
LEFT JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.TAG T
    ON AA.TAG_ID = T.TAG_ID
LEFT JOIN CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.UNIT_OF_MEASUREMENT U
    ON COALESCE(AA.UNIT_ID, AD.UNIT_ID) = U.UNIT_ID;
