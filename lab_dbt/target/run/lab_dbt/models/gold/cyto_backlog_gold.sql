
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`cyto_backlog_gold`
      
      
    using delta
  
      
      
      
      
      
      
      comment 'One row per pending case per report date.'
      
      as
      with backlog_summary as (
    select
        spec_group,
        _report_date,
        count(case when backlog > RECEIVED_TO_SIGNED_OUT_DAYS then 1 end) as cyto_backlog,
        ceil(percentile(case when backlog > RECEIVED_TO_SIGNED_OUT_DAYS then backlog end, 0.25)) as percentile_25th,
        ceil(percentile(case when backlog > RECEIVED_TO_SIGNED_OUT_DAYS then backlog end, 0.50)) as percentile_50th,
        coalesce(max(case when backlog > RECEIVED_TO_SIGNED_OUT_DAYS then backlog end), 0) as maximum,
        sum(case when acc_date_only = _report_date then 1 else 0 end) as cyto_acc_spec_group_vol
    from `opsanalytics_adb_workspace01`.`lab_staging`.`cyto_backlog_silver`
    group by 1, 2
),

cyto_accessioned as (
    select
        SPECIMEN_GROUP as spec_group,
        REPORT_DATE    as _report_date,
        sum(CYTO_ACCESSION_VOLUME) as cyto_acc_recieved
    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_gold`
    group by 1, 2
)

select
    b.spec_group,
    b._report_date,
    b.cyto_backlog,
    b.percentile_25th,
    b.percentile_50th,
    b.maximum,
    coalesce(c.cyto_acc_recieved, 0) + b.cyto_acc_spec_group_vol as total_accessioned_volume
from backlog_summary b
left join cyto_accessioned c
    on  b.spec_group    = c.spec_group
    and b._report_date  = c._report_date
  