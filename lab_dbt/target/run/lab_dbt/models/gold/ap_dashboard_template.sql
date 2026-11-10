
  
    
        create or replace table `opsanalytics_adb_workspace01`.`lab_staging`.`ap_dashboard_template`
      
      
    using delta
  
      
      
      
      
      
      
      comment 'Every AP dashboard cell (division, tab, spec group, setting, site, metric). SITE = \'All\' is setting-level.'
      
      as
      -- Gold helper: every AP cell the dashboard shows, so empty cells appear (grey) instead of
-- disappearing. Mirrors table_ap_template* in the Rmd.
-- SITE = 'All' rows are the setting-level columns (No. Cases Signed Out, and the
-- centralized cytology receive-to-result % within target).

with spec_groups as (
    select * from (values
        ('Breast',      'SURGICAL PATHOLOGY'),
        ('GI',          'SURGICAL PATHOLOGY'),
        ('CYTO GYN',    'CYTOLOGY'),
        ('CYTO NONGYN', 'CYTOLOGY')
    ) as t(SPECIMEN_GROUP, DIVISION)
),

settings as (
    select * from (values ('IP'), ('Amb')) as t(PATIENT_SETTING)
),

sites as (
    select * from (values ('MSB'), ('PACC'), ('MSW'), ('MSH'), ('MSM'), ('MSSN'), ('MSQ'), ('NYEE'))
        as t(SITE)
),

cells as (
    select * from (values
        -- DIVISION,             TAB,                     METRIC,                                 by site?
        ('SURGICAL PATHOLOGY', 'Efficiency Indicators', 'received_to_signed_out_within_target', true),
        ('SURGICAL PATHOLOGY', 'Efficiency Indicators', 'avg_collection_to_signed_out',         true),
        ('SURGICAL PATHOLOGY', 'Efficiency Indicators', 'no_cases_signed',                      false),
        ('SURGICAL PATHOLOGY', '24 Hour Volume',        'no_cases_signed',                      true),
        ('CYTOLOGY',           'Efficiency Indicators', 'avg_collection_to_signed_out',         true),
        ('CYTOLOGY',           'Efficiency Indicators', 'received_to_signed_out_within_target', false),
        ('CYTOLOGY',           'Efficiency Indicators', 'no_cases_signed',                      false),
        ('CYTOLOGY',           '24 Hour Volume',        'no_cases_signed',                      true)
    ) as t(DIVISION, TAB, METRIC, BY_SITE)
)

-- site-level cells (surgical pathology excludes NYEE and MSSN; cytology excludes MSSN)
select g.DIVISION, c.TAB, g.SPECIMEN_GROUP, st.PATIENT_SETTING, s.SITE, c.METRIC
from spec_groups g
join cells c          on c.DIVISION = g.DIVISION and c.BY_SITE
cross join settings st
cross join sites s
where not (g.DIVISION = 'SURGICAL PATHOLOGY' and s.SITE in ('NYEE', 'MSSN'))
  and not (g.DIVISION = 'CYTOLOGY'           and s.SITE = 'MSSN')

union all

-- setting-level cells
select g.DIVISION, c.TAB, g.SPECIMEN_GROUP, st.PATIENT_SETTING, 'All' as SITE, c.METRIC
from spec_groups g
join cells c          on c.DIVISION = g.DIVISION and not c.BY_SITE
cross join settings st
  