
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        TEST_NAME as value_field,
        count(*) as n_records

    from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_biopsy_silver`
    group by TEST_NAME

)

select *
from all_values
where value_field not in (
    'Breast Biopsy','Breast Large/Resection','Cytology GYN','Cytology NONGYN'
)



  
  
      
    ) dbt_internal_test