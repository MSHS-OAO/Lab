-- Gold: CP 24-hour resulted volume cells per result date. Mirrors summarize_cp_vol().

with summary as (
    select RESULT_DATE, SITE, TEST, DASHBOARD_PRIORITY, DETAILED_SETTING,
           sum(TOTAL_RESULTED) as RESULTED_LABS
    from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
    group by 1, 2, 3, 4, 5
),

result_dates as (
    select distinct RESULT_DATE from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
)

select
    d.RESULT_DATE,
    t.DIVISION,
    t.TEST,
    t.SITE,
    t.DASHBOARD_PRIORITY,
    concat(t.TEST, ' - ', t.DASHBOARD_PRIORITY, ' Labs') as TEST_AND_PRIORITY,
    t.PT_SETTING,
    coalesce(s.RESULTED_LABS, 0)                         as RESULTED_LABS
from result_dates d
cross join `opsanalytics_adb_workspace01`.`lab_staging`.`cp_vol_dashboard_template` t
left join summary s
    on  s.RESULT_DATE        = d.RESULT_DATE
    and s.TEST               = t.TEST
    and s.SITE               = t.SITE
    and s.DASHBOARD_PRIORITY = t.DASHBOARD_PRIORITY
    and s.DETAILED_SETTING   = t.PT_SETTING