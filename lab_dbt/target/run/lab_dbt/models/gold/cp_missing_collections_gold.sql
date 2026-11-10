
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`cp_missing_collections_gold`
      
      
    using delta
  
      
      
      
      
      
      
      comment 'Labs missing collection times per result date and site.'
      
      as
      -- Gold: % of labs missing collection times, per result date and site.
-- Mirrors kable_missing_collections(). Status: green <= 5%, orange <= 15%, red above.

with summary as (
    select RESULT_DATE, SITE,
           sum(TOTAL_RESULTED)            as RESULTED_VOLUME,
           sum(TOTAL_MISSING_COLLECTIONS) as MISSING_COLLECTION
    from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
    group by 1, 2
),

result_dates as (
    select distinct RESULT_DATE from `opsanalytics_adb_workspace01`.`lab_staging`.`scc_gold`
)

select
    d.RESULT_DATE,
    s0.SITE,
    s.RESULTED_VOLUME,
    s.MISSING_COLLECTION,
    s.MISSING_COLLECTION / nullif(s.RESULTED_VOLUME, 0)            as PERCENT_MISSING
from result_dates d
cross join (values ('MSH'), ('MSQ'), ('MSB'), ('MSW'), ('MSM'), ('MSSN'), ('RTC')) as s0(SITE)
left join summary s
    on s.RESULT_DATE = d.RESULT_DATE and s.SITE = s0.SITE
  