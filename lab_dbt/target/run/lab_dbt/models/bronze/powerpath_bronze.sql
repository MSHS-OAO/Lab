
  
  
  
  create or replace view `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_bronze`
  (
    `Case_no`,
	`spec_group`,
	`Facility`,
	`Case_created_date`,
	`Collection_Date`,
	`Received_Date`,
	`signed_out_date`,
	`Priority`,
	`Spec_code`,
	`Specimen_description`,
	`CPT_code`,
	`Rev_ctr`,
	`Encounter_no`,
	`MRN`,
	`Refmd_code`,
	`Refmd_name`,
	`spec_sort_order`,
	`patient_type`,
	`PATIENT_SETTING`,
	`GI_CODE_INCLEXCL`,
	`_source_file`,
	`_ingested_at`
  )
  comment 'Raw PowerPath extracts with site, spec_group, patient setting and GI code mappings. Feeds cytology and surgical pathology.'
  as (
    -- Bronze: raw PowerPath + reference mappings (no filtering, no calculations)

select
    replace(c.Case_no, '*failed to decode utf16*', '')    as Case_no,
    case when c.spec_group = 'BREAST' then 'Breast' else c.spec_group end
                                                          as spec_group,
    case
        when c.Facility = 'KH'   then 'MSB'
        when c.Facility = 'R'    then 'MSW'
        when c.Facility = 'STL'  then 'MSM'
        when c.Facility = 'BIMC' then 'MSBI'
        when c.Facility = 'SNCH' then 'MSSN'
        when c.Facility = 'MSS'  then 'MSH'
        when c.Facility = 'SL'   then 'MSM'
        else c.Facility                                   -- PACC stays PACC (as in R)
    end                                                   as Facility,
    cast(c.Case_created_date as timestamp)                as Case_created_date,
    cast(c.Collection_Date   as timestamp)                as Collection_Date,
    cast(c.Received_Date     as timestamp)                as Received_Date,
    cast(c.signed_out_date   as timestamp)                as signed_out_date,
    c.Priority, c.Spec_code, c.Specimen_description, c.CPT_code, c.Rev_ctr,
    c.Encounter_no, c.MRN, c.Refmd_code, c.Refmd_name,
    c.spec_sort_order, c.patient_type,
    -- MSBK patient setting comes from patient_type, not the rev-center crosswalk
    case
        when c.Rev_ctr = 'MSBK' and c.patient_type in ('A', 'O') then 'Amb'
        when c.Rev_ctr = 'MSBK' and c.patient_type = 'IN'        then 'IP'
        else ps.PATIENT_SETTING
    end                                                   as PATIENT_SETTING,
    gi.GI_CODE_INCLEXCL,
    c._source_file, c._ingested_at
from `opsanalytics_adb_workspace01`.`lab`.`powerpath_raw` c
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_gi_codes` gi
    on c.Spec_code = gi.SPEC_CODE
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_patient_setting` ps
    on c.Rev_ctr = ps.REV_CTR
  )
