-- Silver: cytology spec-group filter + derived backlog columns.
-- Grain: one row per pending case per report date (Case_no, _report_date).

with filtered as (
    select *
    from `opsanalytics_adb_workspace01`.`lab_staging`.`cyto_backlog_bronze`
    where spec_group in ('CYTO NONGYN', 'CYTO GYN')
)

select
    f.*,
    cast(f.Received_Date as date)                       as acc_date_only,
    date_format(f.Received_Date, 'EEEE')                as acc_day_only,
    -- R: bizdays(Case_created_date, today) - 1
    greatest(rd.bizday_index - cc.bizday_index - 1, 0)  as backlog
from filtered f
left join `opsanalytics_adb_workspace01`.`lab`.`date_filter` cc
    on cast(f.Case_created_date as date) = cc.calendar_date
left join `opsanalytics_adb_workspace01`.`lab`.`date_filter` rd
    on f._report_date = rd.calendar_date