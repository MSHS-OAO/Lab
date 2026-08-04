
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`date_filter_bronze`
      
      
    using delta
  
      
      
      
      
      
      
      
      
      as
      with dates as (
    select explode(sequence(
        date '1990-01-01',
        date '2100-12-31',
        interval 1 day
    )) as calendar_date
),

flagged as (
    select
        d.calendar_date,
        case
            when dayofweek(d.calendar_date) in (1, 7) then 0   -- Sun=1, Sat=7
            when h.holiday_date is not null           then 0
            else 1
        end as is_working_day
    from dates d
    left join `opsanalytics_adb_workspace01`.`lab`.`mshs_holidays` h
        on d.calendar_date = h.holiday_date
)

select
    calendar_date,
    is_working_day,
    sum(is_working_day) over (order by calendar_date
        rows between unbounded preceding and current row) as bizday_index
from flagged
  