
  
  
  
  create or replace view `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_biopsy_silver`
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
	`SPEC_SORT_ORDER`,
	`TEST_NAME`,
	`PATIENT_SETTING`,
	`COLLECTION_TO_SIGNED_OUT`,
	`RECEIVED_TO_SIGNED_OUT`,
	`TAT_TARGET`,
	`IS_TAT_WITHIN_TARGET`,
	`SPEC_GROUP`,
	`REFMD_NAME`,
	`_SOURCE_FILE`,
	`_INGESTED_AT`
  )
  
  as (
    -- Silver: cytology + breast cases (filters, TEST_NAME, TAT), plus frozen Oracle-era history.
-- Mirrors the filter/TAT part of cyto_prep() in the Rmd.
-- Mappings (site, spec_group, patient setting, MSBK override, casts) live in powerpath_bronze.

with epic_finalized as (
    -- R: cytology cases count only once they are finalized in Epic
    select distinct SPECIMEN_ID
    from `opsanalytics_adb_workspace01`.`lab`.`epic_cytology_raw`
    where LAB_STATUS in ('Final result', 'Edited Result - FINAL')
),

filtered as (
    select b.*
    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_bronze` b
    left join epic_finalized e
        on b.Case_no = e.SPECIMEN_ID
    where b.spec_group in ('CYTO NONGYN', 'CYTO GYN', 'Breast')
      and b.spec_sort_order = 'A'                         -- primary specimens only
      and coalesce(b.Facility, '') <> 'MSBI'              -- R drops MSBI after site mapping (keeps blanks)
      and (b.spec_group = 'Breast' or e.SPECIMEN_ID is not null)
),

with_tat as (
    select
        f.*,
        case
            when f.Spec_code = 'BREA1' and f.spec_group = 'Breast' then 'Breast Biopsy'
            when f.spec_group = 'CYTO NONGYN'                      then 'Cytology NONGYN'
            when f.spec_group = 'CYTO GYN'                         then 'Cytology GYN'
            else 'Breast Large/Resection'
        end                                              as TEST_NAME,
        -- R: difftime(signed_out, collection, units = "days") -> fractional calendar days
        (unix_timestamp(f.signed_out_date) - unix_timestamp(f.Collection_Date)) / 86400.0
                                                         as Collection_to_signed_out,
        -- R: bizdays(Received_Date, signed_out_date)
        so.bizday_index - rc.bizday_index                as Received_to_signed_out
    from filtered f
    left join `opsanalytics_adb_workspace01`.`lab_staging`.`date_filter` rc
        on cast(f.Received_Date   as date) = rc.calendar_date
    left join `opsanalytics_adb_workspace01`.`lab_staging`.`date_filter` so
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
            else 8
        end                     as TAT_TARGET,
        case
            when Received_to_signed_out <= case
                when TEST_NAME = 'Breast Biopsy'          then 3
                when TEST_NAME = 'Breast Large/Resection' then 5
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
    -- Normalize the frozen history to the same site / spec_group values as new data
    select
        case when FACILITY = 'MSUS' then 'PACC' else FACILITY end              as FACILITY,
        PRIORITY, SPEC_CODE, SPECIMEN_DESCRIPTION, CPT_CODE, REV_CTR,
        ENCOUNTER_NO, MRN, CASE_NO, CASE_CREATED_DATE, COLLECTION_DATE,
        RECEIVED_DATE, SIGNED_OUT_DATE, REFMD_CODE, SPEC_SORT_ORDER, TEST_NAME,
        PATIENT_SETTING, COLLECTION_TO_SIGNED_OUT, RECEIVED_TO_SIGNED_OUT,
        TAT_TARGET, IS_TAT_WITHIN_TARGET,
        case when upper(SPEC_GROUP) = 'BREAST' then 'Breast' else SPEC_GROUP end as SPEC_GROUP,
        REFMD_NAME,
        cast(null as string)    as _SOURCE_FILE,
        cast(null as timestamp) as _INGESTED_AT
    from `opsanalytics_adb_workspace01`.`lab`.`powerpath_cyto_biopsy_historical`
    where coalesce(FACILITY, '') not in ('MSBI', 'BIMC')
)

select * from historical
union all
select * from new_data
  )
