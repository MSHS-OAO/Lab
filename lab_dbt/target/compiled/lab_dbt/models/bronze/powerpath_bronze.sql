select
    c.*,
    ps.PATIENT_SETTING,
    gi.GI_CODE_INCLEXCL
from `opsanalytics_adb_workspace01`.`lab`.`powerpath_raw` c
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_gi_codes` gi
    on c.Spec_code = gi.SPEC_CODE
left join `opsanalytics_adb_workspace01`.`lab`.`lab_kpi_ap_patient_setting` ps
on c.Rev_ctr = ps.REV_CTR