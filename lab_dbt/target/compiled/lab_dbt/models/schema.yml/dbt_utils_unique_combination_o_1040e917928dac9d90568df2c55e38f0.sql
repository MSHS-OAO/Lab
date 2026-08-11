





with validation_errors as (

    select
        Case_no, _report_date
    from `opsanalytics_adb_workspace01`.`lab_staging`.`cyto_backlog_silver`
    group by Case_no, _report_date
    having count(*) > 1

)

select *
from validation_errors


