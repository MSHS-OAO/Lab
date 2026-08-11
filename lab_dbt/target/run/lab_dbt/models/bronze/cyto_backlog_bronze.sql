
  
  
  
  create or replace view `opsanalytics_adb_workspace01`.`lab_staging`.`cyto_backlog_bronze`
  (
    `Facility`,
	`Priority`,
	`spec_group`,
	`Spec_code`,
	`Specimen_description`,
	`Current_step`,
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
	`TAT_days`,
	`Refmd_name`,
	`Refmd_code`,
	`NPI_NO`,
	`_source_file`,
	`_report_date`,
	`_ingested_at`,
	`PATIENT_SETTING`,
	`RECEIVED_TO_SIGNED_OUT_DAYS`
  )
  
  as (
    select
    c.*,
    ps.PATIENT_SETTING,
    tt.RECEIVED_TO_SIGNED_OUT_DAYS
from `opsanalytics_adb_workspace01`.`lab`.`cyto_backlog_raw` c
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_patient_setting` ps
    on c.Rev_ctr = ps.REV_CTR
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_tat_targets` tt
    on  c.spec_group = tt.SPEC_GROUP
    and ps.PATIENT_SETTING = tt.PATIENT_SETTING
  )
