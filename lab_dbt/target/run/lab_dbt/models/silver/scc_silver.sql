
  
  
  
  create or replace view `opsanalytics_adb_workspace01`.`lab_staging`.`scc_silver`
  (
    `Ward`,
	`WARD_NAME`,
	`REQUESTING_DOC`,
	`LAST_NAME`,
	`FIRST_NAME`,
	`ORDER_ID`,
	`ORDERING_DATE`,
	`COLLECTION_DATE`,
	`RECEIVE_DATE`,
	`VERIFIED_DATE`,
	`GROUP_TEST_ID`,
	`TEST_ID`,
	`TEST_NAME`,
	`COLLECT_CENTER_ID`,
	`TAT_OV`,
	`TAT_CV`,
	`TAT_RV`,
	`TAT_CR`,
	`PRIORITY`,
	`COLLECTION_TO_RECEIVED`,
	`ORDER_TO_COLLECTION`,
	`REQUESTING_DOC_NAME`,
	`PATIENT_MRN`,
	`WORK_SHIFT`,
	`WORKSTATION`,
	`RESULT`,
	`Addon`,
	`MPI`,
	`_ingested_at`,
	`_source_file`,
	`SCC_TEST_ID`,
	`CLINIC_TYPE`,
	`SITE`
  )
  
  as (
    -- Silver: SCC filters. Mirrors the start of preprocess_scc() in the Rmd:
--   unique(raw_scc)                -> select distinct
--   filter(!is.na(TEST))           -> keep only tests found in LAB_KPI_SCC_TEST_CODES
select distinct *
from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_bronze`
where SCC_TEST_ID is not null
  )
