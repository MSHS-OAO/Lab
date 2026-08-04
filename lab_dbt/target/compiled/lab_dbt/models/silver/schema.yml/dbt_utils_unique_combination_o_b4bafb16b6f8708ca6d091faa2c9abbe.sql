





with validation_errors as (

    select
        CASE_NO, TEST_NAME, SIGNED_OUT_DATE
    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_biopsy_silver`
    group by CASE_NO, TEST_NAME, SIGNED_OUT_DATE
    having count(*) > 1

)

select *
from validation_errors


