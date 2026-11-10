-- Silver: surgical pathology (Breast + GI) filters + derived TAT columns.
-- Mirrors patho_prep() in Lab_KPI_Daily_Dashboard_Prelim_Run_4.Rmd.
-- Mappings (site, spec_group, patient setting, GI codes, casts) live in powerpath_bronze.

with bronze as (
    select * from {{ ref('powerpath_bronze') }}
),

-- GI cases with any specimen code not marked 'Include' are dropped entirely
exclude_case_numbers as (
    select distinct Case_no
    from bronze
    where spec_group = 'GI'
      and (GI_CODE_INCLEXCL is null or GI_CODE_INCLEXCL <> 'Include')
),

filtered as (
    select b.*
    from bronze b
    left anti join exclude_case_numbers x
        on b.Case_no = x.Case_no
    where b.spec_sort_order = 'A'                    -- primary specimens only
      and b.spec_group in ('GI', 'Breast')
      and b.Facility not in ('NYEE', 'MSBI')
)

select
    f.Facility                as FACILITY,
    f.Priority                as PRIORITY,
    f.Spec_code               as SPEC_CODE,
    f.Specimen_description    as SPECIMEN_DESCRIPTION,
    f.CPT_code                as CPT_CODE,
    f.Rev_ctr                 as REV_CTR,
    f.Encounter_no            as ENCOUNTER_NO,
    f.MRN,
    f.Case_no                 as CASE_NO,
    f.Case_created_date       as CASE_CREATED_DATE,
    f.Collection_Date         as COLLECTION_DATE,
    f.Received_Date           as RECEIVED_DATE,
    f.signed_out_date         as SIGNED_OUT_DATE,
    f.Refmd_code              as REFMD_CODE,
    f.Refmd_name              as REFMD_NAME,
    f.spec_sort_order         as SPEC_SORT_ORDER,
    f.spec_group              as SPEC_GROUP,
    f.patient_type            as PATIENT_TYPE,
    f.PATIENT_SETTING,
    f.GI_CODE_INCLEXCL,
    -- R: difftime(signed_out, collection, units = "days") -> fractional calendar days
    (unix_timestamp(f.signed_out_date) - unix_timestamp(f.Collection_Date)) / 86400.0
                              as COLLECTION_TO_SIGNED_OUT,
    -- R: bizdays(Received_Date, signed_out_date) on the MSHS working-day calendar
    so.bizday_index - rc.bizday_index
                              as RECEIVED_TO_SIGNED_OUT,
    f._source_file            as _SOURCE_FILE,
    f._ingested_at            as _INGESTED_AT
from filtered f
left join {{ ref('date_filter') }} rc
    on cast(f.Received_Date as date) = rc.calendar_date
left join {{ ref('date_filter') }} so
    on cast(f.signed_out_date as date) = so.calendar_date
