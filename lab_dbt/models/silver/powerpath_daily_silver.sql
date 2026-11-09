with exclude_case_numbers as (
    -- Reusing the logic from your previous step
    select distinct Case_no
    from {{ ref('powerpath_bronze') }}
    where spec_group = 'GI'
      and (GI_CODE_INCLEXCL is null or GI_CODE_INCLEXCL <> 'Include')
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


cleaned as (
    select
        case
            when spec_group = 'BREAST'   then 'Breast'
            else spec_group
        end                                                 as spec_group,
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
    from with_setting
)