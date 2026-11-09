
  
  
  
  create or replace view `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_daily_silver`
  (
    `FACILITY`,
	`PRIORITY`,
	`SPEC_CODE`,
	`SPECIMEN_DESCRIPTION`,
	`CPT_CODE`,
	`REV_CTR`,
	`ENCOUNTER_NO`,
	`MRN`,
	`CASE_NO`,
	`CASE_CREATED_DATE`,
	`COLLECTION_DATE`,
	`RECEIVED_DATE`,
	`SIGNED_OUT_DATE`,
	`REFMD_CODE`,
	`REFMD_NAME`,
	`SPEC_SORT_ORDER`,
	`SPEC_GROUP`,
	`PATIENT_TYPE`,
	`PATIENT_SETTING`,
	`GI_CODE_INCLEXCL`,
	`COLLECTION_TO_SIGNED_OUT`,
	`RECEIVED_TO_SIGNED_OUT`,
	`_SOURCE_FILE`,
	`_INGESTED_AT`
  )
  
  as (
    -- Surgical pathology (Breast + GI) case-level silver.
-- Mirrors patho_prep() in Lab_KPI_Daily_Dashboard_Prelim_Run_4.Rmd.

with bronze as (
    select
        *,
        case when spec_group = 'BREAST' then 'Breast' else spec_group end as spec_group_clean
    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_bronze`
),

-- GI cases with any specimen code not marked 'Include' are dropped entirely
exclude_case_numbers as (
    select distinct Case_no
    from bronze
    where spec_group_clean = 'GI'
      and (GI_CODE_INCLEXCL is null or GI_CODE_INCLEXCL <> 'Include')
),

cleaned as (
    select
        replace(b.Case_no, '*failed to decode utf16*', '')  as Case_no,
        b.spec_group_clean                                  as spec_group,
        case
            when b.Facility = 'KH'   then 'MSB'
            when b.Facility = 'R'    then 'MSW'
            when b.Facility = 'STL'  then 'MSM'
            when b.Facility = 'BIMC' then 'MSBI'
            when b.Facility = 'SNCH' then 'MSSN'
            when b.Facility = 'MSS'  then 'MSH'
            when b.Facility = 'SL'   then 'MSM'
            else b.Facility                                 -- PACC stays PACC (as in R)
        end                                                 as Facility,
        cast(b.Case_created_date as timestamp)              as Case_created_date,
        cast(b.Collection_Date   as timestamp)              as Collection_Date,
        cast(b.Received_Date     as timestamp)              as Received_Date,
        cast(b.signed_out_date   as timestamp)              as signed_out_date,
        b.Priority, b.Spec_code, b.Specimen_description, b.CPT_code, b.Rev_ctr,
        b.Encounter_no, b.MRN, b.Refmd_code, b.Refmd_name,
        b.spec_sort_order, b.patient_type, b.GI_CODE_INCLEXCL,
        -- MSBK patient setting comes from patient_type, not the rev-center crosswalk
        case
            when b.Rev_ctr = 'MSBK' and b.patient_type in ('A', 'O') then 'Amb'
            when b.Rev_ctr = 'MSBK' and b.patient_type = 'IN'        then 'IP'
            else b.PATIENT_SETTING
        end                                                 as PATIENT_SETTING,
        b._source_file, b._ingested_at
    from bronze b
    left anti join exclude_case_numbers x
        on b.Case_no = x.Case_no
    where b.spec_sort_order = 'A'                           -- primary specimens only
      and b.spec_group_clean in ('GI', 'Breast')
),

filtered as (
    select *
    from cleaned
    where Facility not in ('NYEE', 'MSBI')
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
left join `opsanalytics_adb_workspace01`.`lab`.`date_filter` rc
    on cast(f.Received_Date as date) = rc.calendar_date
left join `opsanalytics_adb_workspace01`.`lab`.`date_filter` so
    on cast(f.signed_out_date as date) = so.calendar_date
  )
