-- Bronze: raw SCC + mappings (test codes, clinic type, site). No filtering/dedupe here.
select scc_raw.Ward,
       scc_raw.WARD_NAME,
       scc_raw.REQUESTING_DOC,
       scc_raw.LAST_NAME,
       scc_raw.FIRST_NAME,
       scc_raw.ORDER_ID,
       scc_raw.ORDERING_DATE,
       scc_raw.COLLECTION_DATE,
       scc_raw.RECEIVE_DATE,
       scc_raw.VERIFIED_DATE,
       scc_raw.GROUP_TEST_ID,
       scc_raw.TEST_ID,
       scc_raw.TEST_NAME,
       scc_raw.COLLECT_CENTER_ID,
       scc_raw.TAT_OV,
       scc_raw.TAT_CV,
       scc_raw.TAT_RV,
       scc_raw.TAT_CR,
       scc_raw.PRIORITY,
       scc_raw.COLLECTION_TO_RECEIVED,
       scc_raw.ORDER_TO_COLLECTION,
       scc_raw.REQUESTING_DOC_NAME,
       scc_raw.PATIENT_MRN,
       scc_raw.WORK_SHIFT,
       scc_raw.WORKSTATION,
       scc_raw.RESULT,
       scc_raw.Addon,
       scc_raw.MPI,
       scc_raw._ingested_at,
       scc_raw._source_file,
       ps.SCC_TEST_ID,
       tt.CLINIC_TYPE,
       site_map.SITE
from `opsanalytics_adb_workspace01`.`lab`.`scc_raw` scc_raw
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_scc_test_codes` ps
    on scc_raw.TEST_ID = ps.SCC_TEST_ID
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_scc_clinictype` tt
    on  scc_raw.CLINIC_TYPE = tt.CLINIC_TYPE
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_site_names` site_map
    on scc_raw.SITE = site_map.SITE