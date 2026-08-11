select
    c.*,
    ps.PATIENT_SETTING,
    tt.RECEIVED_TO_SIGNED_OUT_DAYS
from {{ source('lab', 'cyto_backlog_raw') }} c
left join {{ source('lab', 'lab_kpi_ap_patient_setting') }} ps
    on c.Rev_ctr = ps.REV_CTR
left join {{ source('lab', 'lab_kpi_ap_tat_targets') }} tt
    on  c.spec_group = tt.SPEC_GROUP
    and ps.PATIENT_SETTING = tt.PATIENT_SETTING