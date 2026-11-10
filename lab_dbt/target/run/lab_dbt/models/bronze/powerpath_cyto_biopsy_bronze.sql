
  
  
  
  create or replace view `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_biopsy_bronze`
  (
    `Priority`,
	`spec_group`,
	`Spec_code`,
	`Specimen_description`,
	`CPT_code`,
	`Fee_sch`,
	`Rev_ctr`,
	`Encounter_no`,
	`MRN`,
	`AGE`,
	`TAT`,
	`signed_out_Pathologist`,
	`Refmd_name`,
	`Refmd_code`,
	`NPI_NO`,
	`spec_sort_order`,
	`patient_type`,
	`_source_file`,
	`_ingested_at`,
	`Case_no`,
	`Facility`,
	`Case_created_date`,
	`Collection_Date`,
	`Received_Date`,
	`signed_out_date`,
	`PATIENT_SETTING`
  )
  comment 'Contains data raw powerpath data from 05/18/2026'
  as (
    -- Bronze: raw PowerPath + mappings for cytology/breast (no filtering, no calculations)

select
    c.* except (Case_no, Facility, Case_created_date, Collection_Date, Received_Date, signed_out_date),
    replace(c.Case_no, '*failed to decode utf16*', '')    as Case_no,
    case
        when c.Facility = 'KH'   then 'MSB'
        when c.Facility = 'R'    then 'MSW'
        when c.Facility = 'STL'  then 'MSM'
        when c.Facility = 'SNCH' then 'MSSN'
        when c.Facility = 'MSS'  then 'MSH'
        when c.Facility = 'SL'   then 'MSM'
        when c.Facility = 'PACC' then 'MSUS'
        else c.Facility
    end                                                   as Facility,
    cast(c.Case_created_date as timestamp)                as Case_created_date,
    cast(c.Collection_Date   as timestamp)                as Collection_Date,
    cast(c.Received_Date     as timestamp)                as Received_Date,
    cast(c.signed_out_date   as timestamp)                as signed_out_date,
    -- MSBK patient setting comes from patient_type, not the rev-center crosswalk
    case
        when c.Rev_ctr = 'MSBK' and c.patient_type in ('A', 'O') then 'Amb'
        when c.Rev_ctr = 'MSBK' and c.patient_type = 'IN'        then 'IP'
        else ps.PATIENT_SETTING
    end                                                   as PATIENT_SETTING
from `opsanalytics_adb_workspace01`.`lab`.`powerpath_raw` c
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_patient_setting` ps
    on c.Rev_ctr = ps.REV_CTR
  )
