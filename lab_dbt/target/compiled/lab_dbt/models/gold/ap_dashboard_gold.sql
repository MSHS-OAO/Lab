-- Gold: AP dashboard cells (Efficiency Indicators + 24 Hour Volume tabs), long format.
-- One row per report date x template cell; VALUE is null where there is no data (grey).
-- Mirrors get_efficiency_indicators_cytology / _surgical_pathology and get_stratified_volume.
-- Averages are weighted by cases signed out, as in R.

with summaries as (
    select 'CYTOLOGY' as DIVISION, * from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_gold`
    union all
    select 'SURGICAL PATHOLOGY' as DIVISION, * from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_sp_gold`
),

by_site as (
    select
        REPORT_DATE, DIVISION, SPECIMEN_GROUP, PATIENT_SETTING, SITE,
        sum(NO_CASES_SIGNED_OUT) as no_cases_signed,
        -- R: round(sum((x * n) / sum(n), na.rm = TRUE)) -> missing x count as 0
        round(coalesce(sum(REC_TO_SIGNED_OUT_WITHIN_TARGET * NO_CASES_SIGNED_OUT), 0)
              / sum(NO_CASES_SIGNED_OUT), 2) as received_to_signed_out_within_target,
        round(coalesce(sum(COL_TO_SIGNED_OUT_AVG * NO_CASES_SIGNED_OUT), 0)
              / sum(NO_CASES_SIGNED_OUT), 0) as avg_collection_to_signed_out
    from summaries
    group by 1, 2, 3, 4, 5
),

by_setting as (
    select
        REPORT_DATE, DIVISION, SPECIMEN_GROUP, PATIENT_SETTING, 'All' as SITE,
        sum(NO_CASES_SIGNED_OUT) as no_cases_signed,
        round(coalesce(sum(REC_TO_SIGNED_OUT_WITHIN_TARGET * NO_CASES_SIGNED_OUT), 0)
              / sum(NO_CASES_SIGNED_OUT), 2) as received_to_signed_out_within_target,
        round(coalesce(sum(COL_TO_SIGNED_OUT_AVG * NO_CASES_SIGNED_OUT), 0)
              / sum(NO_CASES_SIGNED_OUT), 0) as avg_collection_to_signed_out
    from summaries
    group by 1, 2, 3, 4
),

metrics as (
    select
        REPORT_DATE, DIVISION, SPECIMEN_GROUP, PATIENT_SETTING, SITE,
        stack(3,
            'no_cases_signed',                      cast(no_cases_signed as double),
            'received_to_signed_out_within_target', cast(received_to_signed_out_within_target as double),
            'avg_collection_to_signed_out',         cast(avg_collection_to_signed_out as double)
        ) as (METRIC, VALUE)
    from (select * from by_site union all select * from by_setting)
),

report_dates as (
    select distinct REPORT_DATE from summaries
)

select
    d.REPORT_DATE,
    t.DIVISION,
    t.TAB,
    t.SPECIMEN_GROUP,
    t.PATIENT_SETTING,
    t.SITE,
    t.METRIC,
    m.VALUE,
    tt.RECEIVED_TO_SIGNED_OUT_DAYS                                    as TARGET_DAYS,
    concat('<= ', cast(tt.RECEIVED_TO_SIGNED_OUT_DAYS as string), ' Days') as TARGET_LABEL
from report_dates d
cross join `opsanalytics_adb_workspace01`.`lab_staging`.`ap_dashboard_template` t
left join metrics m
    on  m.REPORT_DATE     = d.REPORT_DATE
    and m.DIVISION        = t.DIVISION
    and m.SPECIMEN_GROUP  = t.SPECIMEN_GROUP
    and m.PATIENT_SETTING = t.PATIENT_SETTING
    and m.SITE            = t.SITE
    and m.METRIC          = t.METRIC
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_tat_targets` tt
    on  tt.SPEC_GROUP      = t.SPECIMEN_GROUP
    and tt.PATIENT_SETTING = t.PATIENT_SETTING