-- Gold: SCC daily summary for the dashboard. Mirrors cp_summary in the Rmd.
-- Targets / priority / in-target flags are attached in scc_preprocessed_gold.

with flagged as (
    select * from {{ ref('scc_preprocessed_gold') }}
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
