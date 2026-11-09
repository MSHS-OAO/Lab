
  
  
  
  create or replace view `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_bronze`
  (
    `Facility`,
	`Priority`,
	`spec_group`,
	`Spec_code`,
	`Specimen_description`,
	`CPT_code`,
	`Fee_sch`,
	`Rev_ctr`,
	`Encounter_no`,
	`MRN`,
	`AGE`,
	`Case_no`,
	`Case_created_date`,
	`Collection_Date`,
	`Received_Date`,
	`signed_out_date`,
	`TAT`,
	`signed_out_Pathologist`,
	`Refmd_name`,
	`Refmd_code`,
	`NPI_NO`,
	`spec_sort_order`,
	`patient_type`,
	`_source_file`,
	`_ingested_at`,
	`PATIENT_SETTING`,
	`GI_CODE_INCLEXCL`
  )
  
  as (
    select
    c.*,
    ps.PATIENT_SETTING,
    gi.GI_CODE_INCLEXCL
from `opsanalytics_adb_workspace01`.`lab`.`powerpath_raw` c
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_gi_codes` gi
    on c.Spec_code = gi.SPEC_CODE
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_patient_setting` ps
on c.Rev_ctr = ps.REV_CTR
  )
