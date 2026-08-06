{{ config(materialized='table') }}

select
    c.*,
    ps.PATIENT_SETTING
from {{ source('lab', 'powerpath_raw') }} c
left join {{ source('lab', 'lab_kpi_ap_patient_setting') }} ps
    on c.Rev_ctr = ps.REV_CTR