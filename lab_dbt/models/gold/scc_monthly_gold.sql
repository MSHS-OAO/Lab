-- Gold: SCC monthly summary. Rebuild of Oracle LAB_KPI_CP_MONTHLY_VIEW (same column names).
-- Source rows = frozen Oracle history (LAB_KPI_PREPROCESSED_DAILY) for result dates before
-- dbt data starts, plus scc_preprocessed_gold from then on.
-- Only months with at least 28 distinct result days are kept (LAB_KPI_MONTHTRACKER_VIEW).

with history as (
    select
        cast(RESULTDATE as date)          as RESULT_DATE,
        SITE,
        TEST,
        DIVISION,
        MASTERSETTING,
        DASHBOARDSETTING,
        DASHBOARDPRIORITY,
        RECEIVERESULTTARGET,
        COLLECTRESULTTARGET,
        cast(RECEIVETIME_TATINCLUDE as int)  as RECEIVETIME_TATINCLUDE,
        cast(COLLECTTIME_TATINCLUDE as int)  as COLLECTTIME_TATINCLUDE,
        cast(MISSINGCOLLECT as int)          as MISSINGCOLLECT,
        ADDONMASTER,
        cast(RECEIVERESULTINTARGET as int)   as RECEIVERESULTINTARGET,
        cast(COLLECTRESULTINTARGET as int)   as COLLECTRESULTINTARGET,
        RECEIVETORESULTTAT,
        COLLECTTORESULTTAT,
        COLLECTTORECEIVETAT
    from {{ source('lab_history', 'scc_preprocessed_silver') }}
),

history_end as (
    select max(RESULT_DATE) as last_history_date from history
),

new_data as (
    select
        p.RESULT_DATE,
        p.SITE,
        p.TEST,
        p.DIVISION,
        p.DETAILED_SETTING                         as MASTERSETTING,   -- R's "master setting"
        p.DASHBOARD_SETTING                        as DASHBOARDSETTING,
        p.DASHBOARD_PRIORITY                       as DASHBOARDPRIORITY,
        p.RECEIVE_RESULT_TARGET                    as RECEIVERESULTTARGET,
        p.COLLECT_RESULT_TARGET                    as COLLECTRESULTTARGET,
        cast(p.RECEIVE_TIME_TAT_INCL as int)       as RECEIVETIME_TATINCLUDE,
        cast(p.COLLECT_TIME_TAT_INCL as int)       as COLLECTTIME_TATINCLUDE,
        cast(p.MISSING_COLLECT as int)             as MISSINGCOLLECT,
        p.ADD_ON_FINAL                             as ADDONMASTER,
        cast(p.RECEIVE_RESULT_IN_TARGET as int)    as RECEIVERESULTINTARGET,
        cast(p.COLLECT_RESULT_IN_TARGET as int)    as COLLECTRESULTINTARGET,
        p.RECEIVE_TO_RESULT_TAT                    as RECEIVETORESULTTAT,
        p.COLLECT_TO_RESULT_TAT                    as COLLECTTORESULTTAT,
        p.COLLECT_TO_RECEIVE_TAT                   as COLLECTTORECEIVETAT
    from {{ ref('scc_preprocessed_gold') }} p
    cross join history_end h
    where h.last_history_date is null or p.RESULT_DATE > h.last_history_date
),

labs as (
    select
        *,
        -- Month columns derived from the result date for both history and new rows
        cast(date_trunc('month', RESULT_DATE) as date)  as MONTHROLLUP,
        month(RESULT_DATE)                              as MONTHNO,
        date_format(RESULT_DATE, 'MMM')                 as MONTHNAME,
        year(RESULT_DATE)                               as YEAR
    from (select * from history union all select * from new_data)
),

-- LAB_KPI_MONTHTRACKER_VIEW: number of distinct result days in each month
month_tracker as (
    select MONTHNO, YEAR, count(distinct day(RESULT_DATE)) as COMPLETEMONTH
    from labs
    group by MONTHNO, YEAR
)

select
    a.SITE,
    a.MONTHROLLUP,
    a.MONTHNO,
    a.MONTHNAME,
    a.YEAR,
    a.TEST,
    a.DIVISION,
    a.MASTERSETTING,
    a.DASHBOARDSETTING,
    a.DASHBOARDPRIORITY,
    a.RECEIVERESULTTARGET,
    a.COLLECTRESULTTARGET,
    count(*)                                                                   as TOTALRESULTED,
    sum(a.RECEIVETIME_TATINCLUDE)                                              as RECEIVETIME_VOLINCL,
    sum(a.COLLECTTIME_TATINCLUDE)                                              as COLLECTTIME_VOLINCL,
    sum(a.MISSINGCOLLECT)                                                      as TOTALMISSINGCOLLECTIONS,
    sum(case when a.ADDONMASTER = 'AddOn' then 1 else 0 end)                   as TOTALADDONORDER,
    sum(case when a.RECEIVETIME_TATINCLUDE = 1 then a.RECEIVERESULTINTARGET end) as TOTALRECEIVERESULTINTARGET,
    avg(case when a.RECEIVETIME_TATINCLUDE = 1 then a.RECEIVETORESULTTAT end)  as RECEIVERESULT_AVG,
    percentile(case when a.RECEIVETIME_TATINCLUDE = 1 then a.RECEIVETORESULTTAT end, 0.5)
                                                                               as RECEIVERESULT_MEDIAN,
    sum(case when a.COLLECTTIME_TATINCLUDE = 1 then a.COLLECTRESULTINTARGET end) as TOTALCOLLECTRESULTINTARGET,
    avg(case when a.COLLECTTIME_TATINCLUDE = 1 then a.COLLECTTORESULTTAT end)  as COLLECTRESULT_AVG,
    percentile(case when a.COLLECTTIME_TATINCLUDE = 1 then a.COLLECTTORESULTTAT end, 0.5)
                                                                               as COLLECTRESULT_MEDIAN,
    avg(case when a.COLLECTTIME_TATINCLUDE = 1 then a.COLLECTTORECEIVETAT end) as COLLECTRECEIVE_AVG,
    percentile(case when a.COLLECTTIME_TATINCLUDE = 1 then a.COLLECTTORECEIVETAT end, 0.5)
                                                                               as COLLECTRECEIVE_MEDIAN
from labs a
join month_tracker m
    on a.MONTHNO = m.MONTHNO and a.YEAR = m.YEAR
where m.COMPLETEMONTH >= 28
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
