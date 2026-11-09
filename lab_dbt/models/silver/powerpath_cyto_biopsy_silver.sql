-- Silver: cytology + breast filters, derived columns (TEST_NAME, TAT), plus frozen history.
-- Mappings (site, patient setting, MSBK override, casts) live in powerpath_cyto_biopsy_bronze.

with filtered as (
    select *
    from {{ ref('powerpath_cyto_biopsy_bronze') }}
    where spec_group in ('CYTO NONGYN', 'CYTO GYN', 'BREAST')
      and spec_sort_order = 'A'
),

with_tat as (
    select
        f.*,
        case
            when f.Spec_code = 'BREA1' and f.spec_group = 'BREAST' then 'Breast Biopsy'
            when f.spec_group = 'CYTO NONGYN'                      then 'Cytology NONGYN'
            when f.spec_group = 'CYTO GYN'                         then 'Cytology GYN'
            else 'Breast Large/Resection'
        end                                              as TEST_NAME,
        datediff(f.signed_out_date, f.Collection_Date)   as Collection_to_signed_out,
        so.bizday_index - rc.bizday_index                as Received_to_signed_out
    from filtered f
    left join {{ source('lab','date_filter') }} rc
        on cast(f.Received_Date   as date) = rc.calendar_date
    left join {{ source('lab','date_filter') }} so
        on cast(f.signed_out_date as date) = so.calendar_date
),

new_data as (
    select
        Facility                as FACILITY,
        Priority                as PRIORITY,
        Spec_code               as SPEC_CODE,
        Specimen_description    as SPECIMEN_DESCRIPTION,
        CPT_code                as CPT_CODE,
        Rev_ctr                 as REV_CTR,
        Encounter_no            as ENCOUNTER_NO,
        MRN,
        Case_no                 as CASE_NO,
        Case_created_date       as CASE_CREATED_DATE,
        Collection_Date         as COLLECTION_DATE,
        Received_Date           as RECEIVED_DATE,
        signed_out_date         as SIGNED_OUT_DATE,
        Refmd_code              as REFMD_CODE,
        spec_sort_order         as SPEC_SORT_ORDER,
        TEST_NAME,
        PATIENT_SETTING,
        Collection_to_signed_out as COLLECTION_TO_SIGNED_OUT,
        Received_to_signed_out   as RECEIVED_TO_SIGNED_OUT,
        case
            when TEST_NAME = 'Breast Biopsy'          then 3
            when TEST_NAME = 'Breast Large/Resection' then 5
            when TEST_NAME = 'Cytology GYN'           then 8
            else 8
        end                     as TAT_TARGET,
        case
            when Received_to_signed_out <= case
                when TEST_NAME = 'Breast Biopsy'          then 3
                when TEST_NAME = 'Breast Large/Resection' then 5
                when TEST_NAME = 'Cytology GYN'           then 8
                else 8
            end then 1 else 0
        end                     as IS_TAT_WITHIN_TARGET,
        spec_group              as SPEC_GROUP,
        Refmd_name              as REFMD_NAME,
        _source_file            as _SOURCE_FILE,
        _ingested_at            as _INGESTED_AT
    from with_tat
),

historical as (
    select
        FACILITY, PRIORITY, SPEC_CODE, SPECIMEN_DESCRIPTION, CPT_CODE, REV_CTR,
        ENCOUNTER_NO, MRN, CASE_NO, CASE_CREATED_DATE, COLLECTION_DATE,
        RECEIVED_DATE, SIGNED_OUT_DATE, REFMD_CODE, SPEC_SORT_ORDER, TEST_NAME,
        PATIENT_SETTING, COLLECTION_TO_SIGNED_OUT, RECEIVED_TO_SIGNED_OUT,
        TAT_TARGET, IS_TAT_WITHIN_TARGET, SPEC_GROUP, REFMD_NAME,
        cast(null as string)    as _SOURCE_FILE,
        cast(null as timestamp) as _INGESTED_AT
    from {{ source('lab', 'powerpath_cyto_biopsy_historical') }}
)

select * from historical
union all
select * from new_data
