

with raw as (
    select *
    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_biopsy_bronze`
    where spec_group in ('CYTO NONGYN', 'CYTO GYN', 'BREAST')
      and spec_sort_order = 'A'
),

cleaned as (
    select
        replace(Case_no, '*failed to decode utf16*', '')   as Case_no,
        case
            when Facility = 'KH'   then 'MSB'
            when Facility = 'R'    then 'MSW'
            when Facility = 'STL'  then 'MSM'
            when Facility = 'SNCH' then 'MSSN'
            when Facility = 'MSS'  then 'MSH'
            when Facility = 'SL'   then 'MSM'
            when Facility = 'PACC' then 'MSUS'
            else Facility
        end                                                 as Facility,
        case
            when Spec_code = 'BREA1' and spec_group = 'BREAST' then 'Breast Biopsy'
            when spec_group = 'CYTO NONGYN'                    then 'Cytology NONGYN'
            when spec_group = 'CYTO GYN'                       then 'Cytology GYN'
            else 'Breast Large/Resection'
        end                                                 as TEST_NAME,
        cast(Case_created_date as timestamp)                as Case_created_date,
        cast(Collection_Date   as timestamp)                as Collection_Date,
        cast(Received_Date     as timestamp)                as Received_Date,
        cast(signed_out_date   as timestamp)                as signed_out_date,
        Priority, Spec_code, Specimen_description, CPT_code, Rev_ctr,
        Encounter_no, MRN, Refmd_code, Refmd_name,
        spec_sort_order, spec_group, patient_type,
        PATIENT_SETTING,
        _source_file, _ingested_at
    from raw
),

with_setting as (
    select
        c.* except (PATIENT_SETTING),
        case
            when c.Rev_ctr = 'MSBK' and c.patient_type in ('A', 'O') then 'Amb'
            when c.Rev_ctr = 'MSBK' and c.patient_type = 'IN'        then 'IP'
            else PATIENT_SETTING
        end as PATIENT_SETTING
    from cleaned c
),

with_tat as (
    select
        w.*,
        datediff(w.signed_out_date, w.Collection_Date)   as Collection_to_signed_out,
        so.bizday_index - rc.bizday_index                as Received_to_signed_out
    from with_setting w
    left join `opsanalytics_adb_workspace01`.`lab_staging`.`date_filter_bronze` rc
        on cast(w.Received_Date   as date) = rc.calendar_date
    left join `opsanalytics_adb_workspace01`.`lab_staging`.`date_filter_bronze` so
        on cast(w.signed_out_date as date) = so.calendar_date
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
    from `opsanalytics_adb_workspace01`.`lab`.`powerpath_cyto_biopsy_historical`
)


select * from historical
union all
select * from new_data