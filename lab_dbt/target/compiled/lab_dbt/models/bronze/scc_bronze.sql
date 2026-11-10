-- Bronze: raw SCC + mappings. Mirrors the mapping steps of preprocess_scc() in the Rmd.
-- No filtering, no dedupe, no TAT calculations here.

with cleaned as (
    -- R: gsub("\\*.*\\*", "") on every character column, then as.POSIXct on the dates
    select
        regexp_replace(r.Ward, '[*].*[*]', '')                    as Ward,
        regexp_replace(r.WARD_NAME, '[*].*[*]', '')                    as WARD_NAME,
        regexp_replace(r.REQUESTING_DOC, '[*].*[*]', '')                    as REQUESTING_DOC,
        regexp_replace(r.REQUESTING_DOC_NAME, '[*].*[*]', '')                    as REQUESTING_DOC_NAME,
        regexp_replace(r.LAST_NAME, '[*].*[*]', '')                    as LAST_NAME,
        regexp_replace(r.FIRST_NAME, '[*].*[*]', '')                    as FIRST_NAME,
        regexp_replace(r.ORDER_ID, '[*].*[*]', '')                    as ORDER_ID,
        regexp_replace(r.GROUP_TEST_ID, '[*].*[*]', '')                    as GROUP_TEST_ID,
        regexp_replace(r.TEST_ID, '[*].*[*]', '')                    as TEST_ID,
        regexp_replace(r.TEST_NAME, '[*].*[*]', '')                    as TEST_NAME,
        regexp_replace(r.PRIORITY, '[*].*[*]', '')                    as PRIORITY,
        regexp_replace(r.CLINIC_TYPE, '[*].*[*]', '')                    as CLINIC_TYPE,
        regexp_replace(r.PATIENT_MRN, '[*].*[*]', '')                    as PATIENT_MRN,
        regexp_replace(r.MPI, '[*].*[*]', '')                    as MPI,
        regexp_replace(r.WORK_SHIFT, '[*].*[*]', '')                    as WORK_SHIFT,
        regexp_replace(r.WORKSTATION, '[*].*[*]', '')                    as WORKSTATION,
        regexp_replace(r.RESULT, '[*].*[*]', '')                    as RESULT,
        regexp_replace(r.Addon, '[*].*[*]', '')                    as Addon,
        regexp_replace(r.TAT_OV, '[*].*[*]', '')                    as TAT_OV,
        regexp_replace(r.TAT_CV, '[*].*[*]', '')                    as TAT_CV,
        regexp_replace(r.TAT_RV, '[*].*[*]', '')                    as TAT_RV,
        regexp_replace(r.TAT_CR, '[*].*[*]', '')                    as TAT_CR,
        regexp_replace(r.COLLECTION_TO_RECEIVED, '[*].*[*]', '')                    as COLLECTION_TO_RECEIVED,
        regexp_replace(r.ORDER_TO_COLLECTION, '[*].*[*]', '')                    as ORDER_TO_COLLECTION,
        cast(regexp_replace(r.ORDERING_DATE, '[*].*[*]', '') as timestamp) as ORDERING_DATE,
        cast(regexp_replace(r.COLLECTION_DATE, '[*].*[*]', '') as timestamp) as COLLECTION_DATE,
        cast(regexp_replace(r.RECEIVE_DATE, '[*].*[*]', '') as timestamp) as RECEIVE_DATE,
        cast(regexp_replace(r.VERIFIED_DATE, '[*].*[*]', '') as timestamp) as VERIFIED_DATE,
        -- R: str_sub(COLLECT_CENTER_ID, 1, 1) is the key into LAB_KPI_SITE_NAMES.DATA_SITE
        substr(regexp_replace(r.COLLECT_CENTER_ID, '[*].*[*]', ''), 1, 1) as COLLECT_CENTER_ID,
        r._source_file,
        r._ingested_at
    from `opsanalytics_adb_workspace01`.`lab`.`scc_raw` r
),

mapped as (
    select
        c.*,
        tc.TEST,
        tc.DIVISION                         as DIVISION_RAW,
        ct.SETTING,
        ct.SETTING_ROLL_UP,
        sn.SITE                             as SITE_RAW
    from cleaned c
    left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_scc_test_codes` tc
        on c.TEST_ID = tc.SCC_TEST_ID
    left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_scc_clinictype` ct
        on c.CLINIC_TYPE = ct.CLINIC_TYPE
    left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_site_names` sn
        on c.COLLECT_CENTER_ID = sn.DATA_SITE
),

with_site as (
    select
        m.* except (SITE_RAW),
        -- HGB and BUN resulted for Ruttenberg Treatment Center are reported as site RTC
        case
            when m.TEST in ('HGB', 'BUN')
             and coalesce(m.WARD_NAME, '') like '%Ruttenberg Treatment Center%' then 'RTC'
            else m.SITE_RAW
        end                                 as SITE
    from mapped m
)

select
    w.* except (DIVISION_RAW),
    case when w.SITE = 'RTC' then 'Infusion' else w.DIVISION_RAW end  as DIVISION,
    -- R: paste(Site, Ward, WARD_NAME) %in% LAB_KPI_SCC_ICU
    icu.SITE is not null                                              as ICU
from with_site w
left join (
    select distinct SITE, WARD, WARD_NAME
    from `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_scc_icu`
) icu
    on  w.SITE      = icu.SITE
    and w.Ward      = icu.WARD
    and w.WARD_NAME = icu.WARD_NAME