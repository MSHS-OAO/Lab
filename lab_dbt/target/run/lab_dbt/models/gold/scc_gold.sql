
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      -- Gold: SCC daily summary for the dashboard. Mirrors cp_summary in the Rmd:
-- attaches TAT targets (3-level fallback), DASHBOARD_PRIORITY and in-target flags,
-- then aggregates by site / result date / test / setting / priority.

with targets as (
    select TEST, DIVISION, PRIORITY, PT_SETTING,
           min(RECEIVE_TO_RESULT_TARGET) as RECEIVE_TO_RESULT_TARGET,
           min(COLLECT_TO_RESULT_TARGET) as COLLECT_TO_RESULT_TARGET
    from `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_turnaround_targets`
    group by 1, 2, 3, 4
),

-- R: DASHBOARD_PRIORITY = "All" when the test+division target row has PRIORITY "All"
test_division as (
    select TEST, DIVISION, max(PRIORITY = 'All') as has_all_priority
    from targets
    group by 1, 2
),

labs as (
    select
        s.*,
        case
            when td.has_all_priority     then 'All'
            when td.TEST is not null     then s.ADJ_PRIORITY
        end                                                   as DASHBOARD_PRIORITY
    from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_silver` s
    left join test_division td
        on s.TEST = td.TEST and s.DIVISION = td.DIVISION
),

labs_with_targets as (
    select
        l.*,
        -- 1) test+division+priority+setting, 2) test+division+priority, 3) test+division
        coalesce(t1.RECEIVE_TO_RESULT_TARGET, t2.RECEIVE_TO_RESULT_TARGET, t3.RECEIVE_TO_RESULT_TARGET)
                                                              as RECEIVE_RESULT_TARGET,
        coalesce(t1.COLLECT_TO_RESULT_TARGET, t2.COLLECT_TO_RESULT_TARGET, t3.COLLECT_TO_RESULT_TARGET)
                                                              as COLLECT_RESULT_TARGET
    from labs l
    left join targets t1
        on  l.TEST = t1.TEST and l.DIVISION = t1.DIVISION
        and l.DASHBOARD_PRIORITY = t1.PRIORITY
        and l.DETAILED_SETTING   = t1.PT_SETTING
        and t1.PT_SETTING <> 'All'
    left join targets t2
        on  l.TEST = t2.TEST and l.DIVISION = t2.DIVISION
        and l.DASHBOARD_PRIORITY = t2.PRIORITY
        and t2.PRIORITY <> 'All' and t2.PT_SETTING = 'All'
    left join targets t3
        on  l.TEST = t3.TEST and l.DIVISION = t3.DIVISION
        and t3.PRIORITY = 'All' and t3.PT_SETTING = 'All'
),

flagged as (
    select
        *,
        coalesce(RECEIVE_TO_RESULT_TAT <= RECEIVE_RESULT_TARGET, false) as RECEIVE_RESULT_IN_TARGET,
        coalesce(COLLECT_TO_RESULT_TAT <= COLLECT_RESULT_TARGET, false) as COLLECT_RESULT_IN_TARGET
    from labs_with_targets
)

select
    SITE,
    RESULT_DATE,
    TEST,
    DIVISION,
    SETTING_ROLL_UP,
    DETAILED_SETTING,
    DASHBOARD_SETTING,
    ADJ_PRIORITY,
    DASHBOARD_PRIORITY,
    RECEIVE_RESULT_TARGET,
    COLLECT_RESULT_TARGET,
    count(*)                                                                    as TOTAL_RESULTED,
    sum(case when RECEIVE_TIME_TAT_INCL then 1 else 0 end)                      as RECEIVE_TIME_VOL_INCL,
    sum(case when COLLECT_TIME_TAT_INCL then 1 else 0 end)                      as COLLECT_TIME_VOL_INCL,
    sum(case when RECEIVE_TIME_TAT_INCL and RECEIVE_RESULT_IN_TARGET then 1 else 0 end)
                                                                                as TOTAL_RECEIVE_RESULT_IN_TARGET,
    sum(case when COLLECT_TIME_TAT_INCL and COLLECT_RESULT_IN_TARGET then 1 else 0 end)
                                                                                as TOTAL_COLLECT_RESULT_IN_TARGET,
    sum(case when ADD_ON_FINAL = 'AddOn' then 1 else 0 end)                     as TOTAL_ADD_ON_ORDER,
    sum(case when MISSING_COLLECT then 1 else 0 end)                            as TOTAL_MISSING_COLLECTIONS
from flagged
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
  