create or replace TABLE CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET_COMMENTARY (
	BUSINESS_UNIT VARCHAR(16777216) COMMENT 'Organizational partition identifier for multi-tenant or multi-region deployments',
	ASSET_ID VARCHAR(16777216) NOT NULL COMMENT 'Unique identifier for the asset to which this commentary applies',
	NOTE_TIMESTAMP TIMESTAMP_LTZ(9) NOT NULL COMMENT 'Timestamp when this note was created',
	NOTE_DATE DATE COMMENT 'Calendar Date when this note was created',
	NOTE_TEXT VARCHAR(16777216) COMMENT 'Comment, note or operational remark associated with an asset',
	NOTE_JSON VARIANT COMMENT 'The note text in JSON format',
	NOTE_CATEGORY VARCHAR(16777216) COMMENT 'Classification of note, such as operations, maintenance or inspection',
	MODIFIED_BY VARCHAR(16777216) COMMENT 'The user, application or process last modified this note',
	CONFIG VARIANT,
	CREATE_AUTHOR VARCHAR(16777216) COMMENT 'The user, application or process that created this note',
	CREATE_TIMESTAMP TIMESTAMP_LTZ(9) DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp when this version was created',
	CREATE_COMMENT VARCHAR(16777216) COMMENT 'Note or reason associated with version creation',
	UPDATE_TIMESTAMP TIMESTAMP_LTZ(9) COMMENT 'Timestamp of the most recent update to this version',
	UPDATE_HISTORY VARIANT COMMENT 'Note or reason associated with the most recent update',
	RECORD_SOURCE VARCHAR(16777216) COMMENT 'Source system or origin from which this record was loaded',
	constraint PK_ASSET_COMMENTARY primary key (ASSET_ID, NOTE_TIMESTAMP),
	constraint FK_ASSET_COMMENTARY_ASSET foreign key (ASSET_ID) references CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.ASSET(ASSET_ID)
)COMMENT='Stores Commentary and notes associated with operational assets. Supports both structure and unstructured comments from source systems and provides historical traceability of asset-related events.'
;
