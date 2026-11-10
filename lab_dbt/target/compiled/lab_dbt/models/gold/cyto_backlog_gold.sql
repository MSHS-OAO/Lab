-- Gold: cytology backlog + accessioned volume, one row per spec_group per report date.
-- Mirrors pre_processing_backlog() + analyze_backlog() in the Rmd.
-- _report_date is the run date ("today" in R); the reported day is the day before.

with backlog_with_targets as (
    select
        s.*,
        tt.RECEIVED_TO_SIGNED_OUT_DAYS,
        s.backlog > tt.RECEIVED_TO_SIGNED_OUT_DAYS as is_backlogged
    from `opsanalytics_adb_workspace01`.`lab_staging`.`cyto_backlog_silver` s
    left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_tat_targets` tt
        on  s.spec_group      = tt.SPEC_GROUP
        and s.PATIENT_SETTING = tt.PATIENT_SETTING
),

-- Step 1 (pre_processing_backlog): stats per spec code / site / setting / rev ctr / accession date
group_level as (
    select
        spec_group,
        _report_date,
        sum(case when is_backlogged then 1 else 0 end)                         as cyto_backlog,
        ceil(percentile(case when is_backlogged then backlog end, 0.25))       as percentile_25th,
        ceil(percentile(case when is_backlogged then backlog end, 0.50))       as percentile_50th,
        coalesce(max(case when is_backlogged then backlog end), 0)             as maximum,
        -- R: resulted_date (yesterday) == acc_date_only
        sum(case when acc_date_only = date_sub(_report_date, 1) then 1 else 0 end)
                                                                               as cyto_acc_vol
    from backlog_with_targets
    group by spec_group, _report_date, Spec_code, Facility, PATIENT_SETTING, Rev_ctr, acc_date_only
),

-- Step 2 (analyze_backlog): roll up to spec_group.
-- Percentiles are taken over the group-level percentiles, exactly as R does.
backlog_summary as (
    select
        spec_group,
        _report_date,
        sum(cyto_backlog)                          as cyto_backlog,
        ceil(percentile(percentile_25th, 0.25))    as percentile_25th,
        ceil(percentile(percentile_50th, 0.50))    as percentile_50th,
        ceil(max(maximum))                         as maximum,
        sum(cyto_acc_vol)                          as cyto_acc_spec_group_vol
    from group_level
    group by spec_group, _report_date
),

-- Case-level stats R computes but does not display
backlog_extras as (
    select
        spec_group,
        _report_date,
        ceil(percentile(case when is_backlogged then backlog end, 0.75)) as percentile_75th,
        ceil(min(case when is_backlogged then backlog end))              as minimum,
        ceil(avg(case when is_backlogged then backlog end))              as average
    from backlog_with_targets
    group by spec_group, _report_date
),

cyto_accessioned as (
    select
        SPECIMEN_GROUP              as spec_group,
        REPORT_DATE                 as _report_date,
        sum(CYTO_ACCESSION_VOLUME)  as cyto_acc_recieved
    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_gold`
    group by 1, 2
)

select
    b.spec_group,
    b._report_date,
    date_sub(b._report_date, 1)                         as resulted_date,
    -- R shows "No cases accessioned on weekends and holidays" when this is false
    cast(d.is_working_day as boolean)                   as resulted_date_is_working_day,
    b.cyto_backlog,
    b.percentile_25th,
    b.percentile_50th,
    b.maximum,
    -- R inner-joins the two accession counts, so no PowerPath row -> no total
    c.cyto_acc_recieved + b.cyto_acc_spec_group_vol     as total_accessioned_volume,
    e.percentile_75th,
    e.minimum,
    e.average,
    b.cyto_backlog / 80.0                               as days_of_work
from backlog_summary b
left join backlog_extras e
    on  b.spec_group   = e.spec_group
    and b._report_date = e._report_date
left join cyto_accessioned c
    on  b.spec_group   = c.spec_group
    and b._report_date = c._report_date
left join `opsanalytics_adb_workspace01`.`lab_staging`.`date_filter` d
    on date_sub(b._report_date, 1) = d.calendar_date