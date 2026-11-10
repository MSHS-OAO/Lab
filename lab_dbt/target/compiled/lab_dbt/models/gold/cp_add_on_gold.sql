-- Gold: add-on order volume per result date, test and site. Mirrors kable_add_on_volume().

with summary as (
    select RESULT_DATE, TEST, SITE, sum(TOTAL_ADD_ON_ORDER) as ADD_ON_VOLUME
    from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
    group by 1, 2, 3
),

test_sites as (
    select distinct TEST, SITE from `opsanalytics_adb_workspace01`.`lab_staging`.`cp_tat_dashboard_template`
),

result_dates as (
    select distinct RESULT_DATE from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
)

select
    d.RESULT_DATE,
    t.TEST,
    t.SITE,
    coalesce(s.ADD_ON_VOLUME, 0) as ADD_ON_VOLUME
from result_dates d
cross join test_sites t
left join summary s
    on s.RESULT_DATE = d.RESULT_DATE and s.TEST = t.TEST and s.SITE = t.SITE