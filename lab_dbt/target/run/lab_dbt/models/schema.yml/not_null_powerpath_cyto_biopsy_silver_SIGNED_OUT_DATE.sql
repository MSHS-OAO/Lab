
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select SIGNED_OUT_DATE
from `opsanalytics_adb_workspace01`.`lab_staging`.`powerpath_cyto_biopsy_silver`
where SIGNED_OUT_DATE is null



  
  
      
    ) dbt_internal_test