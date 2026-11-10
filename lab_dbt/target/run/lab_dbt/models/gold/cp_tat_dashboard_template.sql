
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`cp_tat_dashboard_template`
      
      
    using delta
  
      
      
      
      
      
      
      comment 'Valid CP TAT table cells (test, site, dashboard priority, dashboard setting).'
      
      as
      -- Gold helper: valid Test x Site x Priority x Dashboard Setting cells for the CP TAT tables.
-- Mirrors tat_dashboard_templ in the Rmd (tests come from LAB_KPI_SCC_TEST_CODES).

with tests as (
    select distinct TEST, DIVISION
    from `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_scc_test_codes`
    where TEST is not null
),

base as (
    select
        t.TEST,
        s.SITE,
        p.DASHBOARD_PRIORITY,
        st.DASHBOARD_SETTING,
        case when s.SITE = 'RTC' then 'Infusion' else t.DIVISION end as DIVISION
    from tests t
    cross join (values ('MSH'), ('MSQ'), ('MSB'), ('MSW'), ('MSM'), ('MSSN'), ('RTC')) as s(SITE)
    cross join (values ('All'), ('Stat'), ('Routine'))                               as p(DASHBOARD_PRIORITY)
    cross join (values ('ED & ICU'), ('IP Non-ICU'), ('Amb'))                        as st(DASHBOARD_SETTING)
)

select DIVISION, TEST, SITE, DASHBOARD_PRIORITY, DASHBOARD_SETTING
from base
where not (
    -- ED & ICU labs are all treated as stat
    (DASHBOARD_PRIORITY = 'Routine' and DASHBOARD_SETTING = 'ED & ICU')
    -- Troponin / Lactate: no ambulatory, no priority split
    or (TEST in ('Troponin', 'Lactate WB')
        and (DASHBOARD_PRIORITY in ('Stat', 'Routine') or DASHBOARD_SETTING = 'Amb'))
    -- BUN / PT / HGB: no "All" priority outside Infusion
    or (TEST in ('BUN', 'PT', 'HGB') and DASHBOARD_PRIORITY = 'All'
        and coalesce(DIVISION, '') <> 'Infusion')
    -- Rapid Flu / C. diff: no priority split
    or (TEST in ('Rapid Flu', 'C. diff') and DASHBOARD_PRIORITY <> 'All')
    -- Infusion (RTC): only BUN / HGB, Amb, All
    or (coalesce(DIVISION, '') = 'Infusion'
        and (TEST not in ('BUN', 'HGB') or DASHBOARD_SETTING <> 'Amb' or DASHBOARD_PRIORITY <> 'All'))
    -- Blood Bank: no "All" priority
    or (coalesce(DIVISION, '') = 'Blood Bank' and DASHBOARD_PRIORITY = 'All')
)
  