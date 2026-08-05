
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_gold`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      with base as (
    select
        s.*,
        cast(s.SIGNED_OUT_DATE as date)              as signed_out_date_only,
        cast(s.RECEIVED_DATE   as date)              as acc_date_only,
        tt.RECEIVED_TO_SIGNED_OUT_DAYS,
        tt.COLLECTED_TO_SIGNED_OUT_DAYS
    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_biopsy_silver` s
    left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_tat_targets` tt
        on  s.SPEC_GROUP       = tt.SPEC_GROUP
        and s.PATIENT_SETTING  = tt.PATIENT_SETTING
)

select
    SPEC_CODE                                        as SPECIMEN_CODE,
    SPEC_GROUP                                       as SPECIMEN_GROUP,
    FACILITY                                         as SITE,
    PATIENT_SETTING,
    REV_CTR                                          as REVENUE_CENTER,
    signed_out_date_only                             as SIGNED_OUT_DATE,
    date_format(signed_out_date_only, 'EEEE')        as SIGNED_OUT_DAY,
    RECEIVED_TO_SIGNED_OUT_DAYS                      as REC_TO_SIGNED_OUT_TARGET,
    COLLECTED_TO_SIGNED_OUT_DAYS                     as COL_TO_SIGNED_OUT_TARGET,
    acc_date_only                                    as ACCESSION_DATE,
    date_format(acc_date_only, 'EEEE')               as ACCESION_DAY,
    date_add(signed_out_date_only, 1)                as REPORT_DATE,
    date_format(date_add(signed_out_date_only, 1), 'EEEE') as REPORT_DAY,

    count(*)                                         as NO_CASES_SIGNED_OUT,
    round(avg(RECEIVED_TO_SIGNED_OUT), 0)            as REC_TO_SIGNED_OUT_AVG,
    round(percentile(RECEIVED_TO_SIGNED_OUT, 0.5), 0) as REC_TO_SIGNED_OUT_MEDIAN,
    round(stddev(RECEIVED_TO_SIGNED_OUT), 1)         as REC_TO_SIGNED_OUT_STDDEV,
    round(
        sum(case when RECEIVED_TO_SIGNED_OUT <= RECEIVED_TO_SIGNED_OUT_DAYS then 1 else 0 end)
        / nullif(sum(case when RECEIVED_TO_SIGNED_OUT >= 0 then 1 else 0 end), 0)
    , 2)                                             as REC_TO_SIGNED_OUT_WITHIN_TARGET,
    ceil(avg(COLLECTION_TO_SIGNED_OUT))              as COL_TO_SIGNED_OUT_AVG,
    round(percentile(COLLECTION_TO_SIGNED_OUT, 0.5), 0) as COL_TO_SIGNED_OUT_MEDIAN,
    round(stddev(COLLECTION_TO_SIGNED_OUT), 1)       as COL_TO_SIGNED_OUT_STDDEV,
    sum(case when signed_out_date_only = acc_date_only then 1 else 0 end) as CYTO_ACCESSION_VOLUME
from base
group by 1,2,3,4,5,6,7,8,9,10,11,12,13
  