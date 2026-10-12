create or replace view CYGNET_TRANSFORMATION.APP.VW_DRAWDOWN_WELL_MASTER(
	WELL_ASSET_ID COMMENT 'Common model asset identifier for the well',
	COUNTY COMMENT 'County where the well is located, from EDW well completion master',
	LEGAL_WELL_NAME COMMENT 'Legal well name as filed with regulatory agencies',
	PROCOUNT_AREA COMMENT 'ProCount operational area assignment from EDW well completion master',
	STATE COMMENT 'State or province where the well is located',
	TOWNSHIP COMMENT 'Survey township location of the well',
	RANGE COMMENT 'Survey range location of the well',
	WELL_NAME COMMENT 'Common well name from EDW well completion master',
	WELL_TYPE COMMENT 'Well classification type (e.g. oil, gas, injection)',
	STATUS COMMENT 'Completion lifecycle status from EDW well completion master',
	COMP_BOTTOM_PERF_MD COMMENT 'Bottom perforation measured depth (ft) of the completion',
	COMP_BOTTOM_PERF_TVD COMMENT 'Bottom perforation true vertical depth (ft) of the completion',
	COMP_RESERVOIR COMMENT 'Target reservoir name for the completion',
	COMP_PRIMARY_FUND_WI COMMENT 'Primary fund working interest percentage for the completion',
	COMP_ACTENUM_AREA COMMENT 'Actenum planning area assigned to the completion',
	COMP_ACTENUM_SUB_AREA COMMENT 'Actenum planning sub-area assigned to the completion',
	COMP_FRAC_END_DATE COMMENT 'Date hydraulic fracturing operations ended for the completion',
	COMP_FRAC_START_DATE COMMENT 'Date hydraulic fracturing operations began for the completion',
	SPUD_DATE COMMENT 'Date drilling commenced (spud date) for the well',
	RIG_RELEASE_DATE COMMENT 'Date the drilling rig was released from the well'
) COMMENT='Provides well master and completion reference data for drawdown wells by joining common model well assets to the EDW well completion master via API number. Supplies reference attributes for dashboards and reporting.'
 as
/********************************************************************************
Author:         Chris Waters
Description:    Joins common model well assets (identified by ENERTIA_COMPLETION_ID) to the
                EDW well completion master dimension to provide reference and
                completion attributes for each drawdown well.
Create Date:    10/02/2026
--------------------------------------------------------------------------------
Modification Log:
--------------------------------------------------------------------------------
<YYYY/MM/DD>    <Modified By>
--------------------------------------------------------------------------------
Notes:
  - Join uses REGEXP_SUBSTR on ENERTIA_COMPLETION_ID to match the Enertia well code from
    DIM_WELL_COMPLETION_MASTER.
  - Additional well/completion attributes can be added from
    DIM_WELL_COMPLETION_MASTER as needed.
--------------------------------------------------------------------------------
*********************************************************************************/
WITH cm_wells AS (
    SELECT asset_id, value_text AS ENERTIA_COMPLETION_ID
    FROM CYGNET_TRANSFORMATION.CORE_COMMON_MODEL.VW_ASSET_ATTR
    WHERE asset_type_id = 'WELL' AND attr_id = 'ENERTIA_COMPLETION_ID' and asset_status = 'ACTIVE'
)
SELECT
    cm.asset_id AS well_asset_id,
    wm.well_county AS county,
    wm.well_legal_well_name AS legal_well_name,
    wm.well_procount_area AS procount_area,
    wm.well_province_state AS state,
    wm.well_township AS township,
    wm.well_range AS range,
    wm.well_well_name AS well_name,
    wm.well_well_type AS well_type,
    wm.comp_completion_lifecycle_status AS status,
    wm.comp_bottom_perf_md,
    wm.comp_bottom_perf_tvd,
    wm.comp_reservoir,
    wm.comp_primary_fund_wi,
    wm.comp_actenum_area,
    wm.comp_actenum_sub_area,
    wm.comp_frac_end_date,
    wm.comp_frac_start_date,
    wm.well_spud_date AS spud_date,
    wm.well_rig_release_date AS rig_release_date
FROM EDW.ANALYTICS.DIM_WELL_COMPLETION_MASTER wm,
     cm_wells cm
WHERE wm.well_enertia_well_code = REGEXP_SUBSTR(cm.ENERTIA_COMPLETION_ID, '^[^-]+');
