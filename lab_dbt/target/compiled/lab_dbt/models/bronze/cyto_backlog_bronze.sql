-- Bronze: raw cytology pending-cases snapshots + mappings (no filtering, no calculations)

select
    c.* except (Facility, Case_created_date, Received_Date),
    case
        when c.Facility = 'KH'   then 'MSB'
        when c.Facility = 'R'    then 'MSW'
        when c.Facility = 'STL'  then 'MSM'
        when c.Facility = 'BIMC' then 'MSBI'
        when c.Facility = 'SNCH' then 'MSSN'
        when c.Facility = 'MSS'  then 'MSH'
        when c.Facility = 'SL'   then 'MSM'
        else c.Facility                        -- PACC stays PACC (as in R)
    end                                        as Facility,
    cast(c.Case_created_date as timestamp)     as Case_created_date,
    cast(c.Received_Date     as timestamp)     as Received_Date,
    ps.PATIENT_SETTING
from `opsanalytics_adb_workspace01`.`lab`.`cyto_backlog_raw` c
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_patient_setting` ps
    on c.Rev_ctr = ps.REV_CTR