-- Gold helper: valid Test x Site x Priority x Patient Setting cells for the CP 24-hour
-- volume tables. Mirrors vol_dashboard_templ in the Rmd.

with tests as (
    select distinct TEST, DIVISION
    from {{ source('lab', 'lab_kpi_scc_test_codes') }}
    where TEST is not null
),

base as (
    select
        t.TEST,
        s.SITE,
        p.DASHBOARD_PRIORITY,
        st.PT_SETTING,
        case when s.SITE = 'RTC' then 'Infusion' else t.DIVISION end as DIVISION
    from tests t
    cross join (values ('MSH'), ('MSQ'), ('MSB'), ('MSW'), ('MSM'), ('MSSN'), ('RTC')) as s(SITE)
    cross join (values ('All'), ('Stat'), ('Routine'))                               as p(DASHBOARD_PRIORITY)
    cross join (values ('ED'), ('ICU'), ('IP Non-ICU'), ('Amb'), ('Other'))          as st(PT_SETTING)
)

select DIVISION, TEST, SITE, DASHBOARD_PRIORITY, PT_SETTING
from base
where not (
    (DASHBOARD_PRIORITY = 'Routine' and PT_SETTING in ('ED', 'ICU'))
    or (TEST in ('Troponin', 'Lactate WB') and DASHBOARD_PRIORITY in ('Stat', 'Routine'))
    or (TEST in ('BUN', 'PT', 'HGB') and DASHBOARD_PRIORITY = 'All'
        and coalesce(DIVISION, '') <> 'Infusion')
    -- Micro RRL volume is already shown in its TAT table
    or coalesce(DIVISION, '') = 'Microbiology RRL'
    or (coalesce(DIVISION, '') = 'Infusion'
        and (TEST not in ('BUN', 'HGB') or PT_SETTING <> 'Amb' or DASHBOARD_PRIORITY <> 'All'))
    or (coalesce(DIVISION, '') = 'Blood Bank' and DASHBOARD_PRIORITY = 'All')
)
