
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`cp_tat_gold`
      
      
    using delta
  
      
      
      
      
      
      
      comment 'CP TAT table cells per result date. SHOW_TAT = false where R hides TAT (C. diff Amb in Micro RRL).'
      
      as
      -- Gold: CP turnaround table cells per result date (Chemistry, Hematology, Micro RRL,
-- Infusion, Blood Bank). Mirrors summarize_cp_tat() in the Rmd.
-- Note: like R, data are matched to the template on test/site/priority/setting only,
-- so a test appears under the division the template assigns it.

with summary as (
    select
        RESULT_DATE, TEST, SITE, DASHBOARD_PRIORITY, DASHBOARD_SETTING,
        RECEIVE_RESULT_TARGET, COLLECT_RESULT_TARGET,
        sum(TOTAL_RESULTED)                 as RESULTED_VOLUME,
        sum(RECEIVE_TIME_VOL_INCL)          as RESULTED_VOL_RECEIVE_TAT,
        sum(COLLECT_TIME_VOL_INCL)          as RESULTED_VOL_COLLECT_TAT,
        sum(TOTAL_RECEIVE_RESULT_IN_TARGET) as RECEIVE_RESULT_IN_TARGET,
        sum(TOTAL_COLLECT_RESULT_IN_TARGET) as COLLECT_RESULT_IN_TARGET
    from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
    group by 1, 2, 3, 4, 5, 6, 7
),

targets as (
    select TEST, DIVISION, PRIORITY, PT_SETTING,
           min(RECEIVE_TO_RESULT_TARGET) as RECEIVE_TO_RESULT_TARGET,
           min(COLLECT_TO_RESULT_TARGET) as COLLECT_TO_RESULT_TARGET
    from `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_turnaround_targets`
    group by 1, 2, 3, 4
),

result_dates as (
    select distinct RESULT_DATE from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
),

cells as (
    select
        d.RESULT_DATE, t.DIVISION, t.TEST, t.SITE, t.DASHBOARD_PRIORITY, t.DASHBOARD_SETTING,
        s.RECEIVE_RESULT_TARGET, s.COLLECT_RESULT_TARGET,
        s.RESULTED_VOLUME, s.RESULTED_VOL_RECEIVE_TAT, s.RESULTED_VOL_COLLECT_TAT,
        s.RECEIVE_RESULT_IN_TARGET, s.COLLECT_RESULT_IN_TARGET
    from result_dates d
    cross join `opsanalytics_adb_workspace01`.`lab_staging`.`cp_tat_dashboard_template` t
    left join summary s
        on  s.RESULT_DATE        = d.RESULT_DATE
        and s.TEST               = t.TEST
        and s.SITE               = t.SITE
        and s.DASHBOARD_PRIORITY = t.DASHBOARD_PRIORITY
        and s.DASHBOARD_SETTING  = t.DASHBOARD_SETTING
),

-- Empty cells still show a target: same 3-level fallback as scc_gold, on the dashboard setting
with_targets as (
    select
        c.* except (RECEIVE_RESULT_TARGET, COLLECT_RESULT_TARGET),
        coalesce(c.RECEIVE_RESULT_TARGET, t1.RECEIVE_TO_RESULT_TARGET,
                 t2.RECEIVE_TO_RESULT_TARGET, t3.RECEIVE_TO_RESULT_TARGET) as RECEIVE_RESULT_TARGET,
        coalesce(c.COLLECT_RESULT_TARGET, t1.COLLECT_TO_RESULT_TARGET,
                 t2.COLLECT_TO_RESULT_TARGET, t3.COLLECT_TO_RESULT_TARGET) as COLLECT_RESULT_TARGET
    from cells c
    left join targets t1
        on  c.TEST = t1.TEST and c.DIVISION = t1.DIVISION
        and c.DASHBOARD_PRIORITY = t1.PRIORITY and c.DASHBOARD_SETTING = t1.PT_SETTING
        and t1.PT_SETTING <> 'All'
    left join targets t2
        on  c.TEST = t2.TEST and c.DIVISION = t2.DIVISION
        and c.DASHBOARD_PRIORITY = t2.PRIORITY
        and t2.PRIORITY <> 'All' and t2.PT_SETTING = 'All'
    left join targets t3
        on  c.TEST = t3.TEST and c.DIVISION = t3.DIVISION
        and t3.PRIORITY = 'All' and t3.PT_SETTING = 'All'
)

select
    RESULT_DATE,
    DIVISION,
    TEST,
    SITE,
    DASHBOARD_PRIORITY,
    concat(TEST, ' - ', DASHBOARD_PRIORITY, ' Labs')                       as TEST_AND_PRIORITY,
    DASHBOARD_SETTING,
    RECEIVE_RESULT_TARGET,
    COLLECT_RESULT_TARGET,
    concat('<=', cast(RECEIVE_RESULT_TARGET as string), ' min')            as RECEIVE_RESULT_TARGET_LABEL,
    concat('<=', cast(COLLECT_RESULT_TARGET as string), ' min')            as COLLECT_RESULT_TARGET_LABEL,
    coalesce(RESULTED_VOLUME, 0)                                           as RESULTED_VOLUME,
    RESULTED_VOL_RECEIVE_TAT,
    RESULTED_VOL_COLLECT_TAT,
    RECEIVE_RESULT_IN_TARGET,
    COLLECT_RESULT_IN_TARGET,
    round(RECEIVE_RESULT_IN_TARGET / nullif(RESULTED_VOL_RECEIVE_TAT, 0), 3) as RECEIVE_RESULT_PERCENT,
    round(COLLECT_RESULT_IN_TARGET / nullif(RESULTED_VOL_COLLECT_TAT, 0), 3) as COLLECT_RESULT_PERCENT,
    -- R drops C. diff ambulatory from the Micro RRL TAT rows (volume is still shown)
    not (DIVISION = 'Microbiology RRL' and TEST = 'C. diff' and DASHBOARD_SETTING = 'Amb')
                                                                           as SHOW_TAT
from with_targets
  