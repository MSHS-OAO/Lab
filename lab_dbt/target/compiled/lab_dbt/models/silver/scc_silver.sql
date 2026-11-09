-- Silver: SCC filters. Mirrors the start of preprocess_scc() in the Rmd:
--   unique(raw_scc)                -> select distinct
--   filter(!is.na(TEST))           -> keep only tests found in LAB_KPI_SCC_TEST_CODES
select distinct *
from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_bronze`
where SCC_TEST_ID is not null