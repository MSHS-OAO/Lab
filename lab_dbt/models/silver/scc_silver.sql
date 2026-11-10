-- Silver: SCC filters + derived columns. One row per resulted lab.
-- Mirrors preprocess_scc() in the Rmd (targets / in-target flags live in scc_gold).

with deduped_raw as (
    -- R: unique(raw_scc)
    select distinct * from {{ ref('scc_bronze') }}
),

included as (
    -- R: filter(!is.na(TEST))  -- only tests in LAB_KPI_SCC_TEST_CODES
    select * from deduped_raw where TEST is not null
),

derived as (
    select
        i.*,
        cast(i.VERIFIED_DATE as date)                                 as RESULT_DATE,
        case
            when i.SETTING_ROLL_UP = 'IP' and i.ICU     then 'ICU'
            when i.SETTING_ROLL_UP = 'IP' and not i.ICU then 'IP Non-ICU'
            else i.SETTING_ROLL_UP
        end                                                           as DETAILED_SETTING,
        -- minutes, keeping fractional seconds like R's difftime
        (unix_micros(i.RECEIVE_DATE)  - unix_micros(i.COLLECTION_DATE)) / 60000000.0 as COLLECT_TO_RECEIVE_TAT,
        (unix_micros(i.VERIFIED_DATE) - unix_micros(i.RECEIVE_DATE))    / 60000000.0 as RECEIVE_TO_RESULT_TAT,
        (unix_micros(i.VERIFIED_DATE) - unix_micros(i.COLLECTION_DATE)) / 60000000.0 as COLLECT_TO_RESULT_TAT,
        (unix_micros(i.ORDERING_DATE) - unix_micros(i.RECEIVE_DATE))    / 60000000.0 as ORDER_TO_RECEIVE_MINS
    from included i
),

flagged as (
    select
        d.*,
        case when d.DETAILED_SETTING in ('ED', 'ICU') then 'ED & ICU'
             else d.DETAILED_SETTING end                              as DASHBOARD_SETTING,
        -- All ED and ICU labs are treated as stat per operational leadership
        case when d.DETAILED_SETTING in ('ED', 'ICU') or d.PRIORITY = 'S'
             then 'Stat' else 'Routine' end                           as ADJ_PRIORITY,
        -- Add-on if ordered more than 5 minutes after the specimen was received
        case when d.ORDER_TO_RECEIVE_MINS > 5  then 'AddOn'
             when d.ORDER_TO_RECEIVE_MINS <= 5 then 'Original' end    as ADD_ON_FINAL,
        coalesce(d.COLLECT_TO_RECEIVE_TAT = 0, false)                 as MISSING_COLLECT
    from derived d
),

with_incl as (
    select
        f.*,
        -- Exclusions: add-ons, "Other" setting, negative TATs, missing timestamps
        coalesce(
            f.ADD_ON_FINAL = 'Original'
            and f.DETAILED_SETTING <> 'Other'
            and f.COLLECT_TO_RECEIVE_TAT >= 0
            and f.COLLECT_TO_RESULT_TAT  >= 0
            and f.RECEIVE_TO_RESULT_TAT  >= 0
        , false)                                                      as RECEIVE_TIME_TAT_INCL,
        -- Same as above, plus labs with missing collection times are excluded
        coalesce(
            not f.MISSING_COLLECT
            and f.ADD_ON_FINAL = 'Original'
            and f.DETAILED_SETTING <> 'Other'
            and f.COLLECT_TO_RECEIVE_TAT >= 0
            and f.COLLECT_TO_RESULT_TAT  >= 0
            and f.RECEIVE_TO_RESULT_TAT  >= 0
        , false)                                                      as COLLECT_TIME_TAT_INCL,
        -- R: duplicated(paste(LAST_NAME, FIRST_NAME, ORDER_ID, TEST_NAME, COLLECT, RECEIVE, RESULT))
        row_number() over (
            partition by f._source_file, f.LAST_NAME, f.FIRST_NAME, f.ORDER_ID, f.TEST_NAME,
                         f.COLLECTION_DATE, f.RECEIVE_DATE, f.VERIFIED_DATE
            order by f.ORDERING_DATE
        )                                                             as dupl_rank
    from flagged f
),

no_dupes as (
    select * from with_incl where dupl_rank = 1
),

-- R keeps only the result date with the most labs in each daily file
file_result_date as (
    select _source_file, RESULT_DATE
    from (
        select
            _source_file,
            RESULT_DATE,
            row_number() over (partition by _source_file
                               order by count(*) desc, RESULT_DATE) as rn
        from no_dupes
        group by _source_file, RESULT_DATE
    )
    where rn = 1
),

per_file as (
    select
        n.Ward                   as LOC_CODE,
        n.WARD_NAME              as LOC_NAME,
        n.ORDER_ID,
        n.REQUESTING_DOC_NAME    as REQUEST_MD,
        n.MPI                    as MSMRN,
        n.WORK_SHIFT,
        n.TEST_NAME,
        n.TEST,
        n.DIVISION,
        n.PRIORITY               as ORDER_PRIORITY,
        n.SITE,
        n.ICU,
        n.CLINIC_TYPE            as LOC_TYPE,
        n.SETTING,
        n.SETTING_ROLL_UP,
        n.DETAILED_SETTING,
        n.DASHBOARD_SETTING,
        n.ADJ_PRIORITY,
        n.ORDERING_DATE          as ORDER_TIME,
        n.COLLECTION_DATE        as COLLECT_TIME,
        n.RECEIVE_DATE           as RECEIVE_TIME,
        n.VERIFIED_DATE          as RESULT_TIME,
        n.RESULT_DATE,
        n.COLLECT_TO_RECEIVE_TAT,
        n.RECEIVE_TO_RESULT_TAT,
        n.COLLECT_TO_RESULT_TAT,
        n.ADD_ON_FINAL,
        n.MISSING_COLLECT,
        n.RECEIVE_TIME_TAT_INCL,
        n.COLLECT_TIME_TAT_INCL,
        n._source_file           as _SOURCE_FILE,
        n._ingested_at           as _INGESTED_AT
    from no_dupes n
    join file_result_date d
        on  n._source_file = d._source_file
        and n.RESULT_DATE  = d.RESULT_DATE
),

-- The same lab can arrive in more than one daily file. Oracle LAB_KPI_PREPROCESSED_DAILY
-- kept one row per (ORDERID, TEST, RESULTTIME, TESTNAME); keep the most recently ingested.
cross_file as (
    select
        *,
        row_number() over (
            partition by ORDER_ID, TEST, RESULT_TIME, TEST_NAME
            order by _INGESTED_AT desc, _SOURCE_FILE desc
        ) as pk_rank
    from per_file
)

select * except (pk_rank)
from cross_file
where pk_rank = 1
