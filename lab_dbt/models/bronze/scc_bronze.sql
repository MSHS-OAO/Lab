-- Bronze: raw SCC + mappings. Mirrors the mapping steps of preprocess_scc() in the Rmd.
-- No filtering, no dedupe, no TAT calculations here.

{%- set string_cols = [
    'Ward', 'WARD_NAME', 'REQUESTING_DOC', 'REQUESTING_DOC_NAME', 'LAST_NAME', 'FIRST_NAME',
    'ORDER_ID', 'GROUP_TEST_ID', 'TEST_ID', 'TEST_NAME', 'PRIORITY', 'CLINIC_TYPE',
    'PATIENT_MRN', 'MPI', 'WORK_SHIFT', 'WORKSTATION', 'RESULT', 'Addon',
    'TAT_OV', 'TAT_CV', 'TAT_RV', 'TAT_CR', 'COLLECTION_TO_RECEIVED', 'ORDER_TO_COLLECTION'
] %}
{%- set date_cols = ['ORDERING_DATE', 'COLLECTION_DATE', 'RECEIVE_DATE', 'VERIFIED_DATE'] %}

with cleaned as (
    -- R: gsub("\\*.*\\*", "") on every character column, then as.POSIXct on the dates
    select
        {%- for c in string_cols %}
        regexp_replace(r.{{ c }}, '[*].*[*]', '')                    as {{ c }},
        {%- endfor %}
        {%- for c in date_cols %}
        cast(regexp_replace(r.{{ c }}, '[*].*[*]', '') as timestamp) as {{ c }},
        {%- endfor %}
        -- R: str_sub(COLLECT_CENTER_ID, 1, 1) is the key into LAB_KPI_SITE_NAMES.DATA_SITE
        substr(regexp_replace(r.COLLECT_CENTER_ID, '[*].*[*]', ''), 1, 1) as COLLECT_CENTER_ID,
        r._source_file,
        r._ingested_at
    from {{ source('lab', 'scc_raw') }} r
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
    left join {{ source('lab', 'lab_kpi_scc_test_codes') }} tc
        on c.TEST_ID = tc.SCC_TEST_ID
    left join {{ source('lab', 'lab_kpi_scc_clinictype') }} ct
        on c.CLINIC_TYPE = ct.CLINIC_TYPE
    left join {{ source('lab', 'lab_kpi_site_names') }} sn
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
    from {{ source('lab', 'lab_kpi_scc_icu') }}
) icu
    on  w.SITE      = icu.SITE
    and w.Ward      = icu.WARD
    and w.WARD_NAME = icu.WARD_NAME
