-- Use the `ref` function to select from other models

select *
from `opsanalytics_adb_workspace01`.`lab_staging`.`my_first_dbt_model`
where id = 1