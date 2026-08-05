{{ config(materialized='table') }}

with filtered as (
    select *
    from {{ ref('cyto_backlog_bronze') }}
    where spec_group in ('CYTO NONGYN', 'CYTO GYN')
),

cleaned as (
    select
        b.* except (Facility, Case_created_date, Received_Date),
        case
            when Facility = 'KH'   then 'MSB'
            when Facility = 'R'    then 'MSW'
            when Facility = 'STL'  then 'MSM'
            when Facility = 'SNCH' then 'MSSN'
            when Facility = 'MSS'  then 'MSH'
            when Facility = 'SL'   then 'MSM'
            when Facility = 'PACC' then 'MSUS'
            else Facility
        end                                      as Facility,
        cast(Case_created_date as timestamp)     as Case_created_date,
        cast(Received_Date     as timestamp)     as Received_Date
    from filtered b
)

select
    c.*,
    cast(c.Received_Date as date)                       as acc_date_only,
    date_format(c.Received_Date, 'EEEE')                as acc_day_only,
    greatest(rd.bizday_index - cc.bizday_index - 1, 0)  as backlog
from cleaned c
left join {{ ref('date_filter_bronze') }} cc
    on cast(c.Case_created_date as date) = cc.calendar_date
left join {{ ref('date_filter_bronze') }} rd
    on c._report_date = rd.calendar_date