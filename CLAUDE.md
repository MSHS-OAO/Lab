# Lab KPI – project conventions

## dbt layering (lab_dbt/models)

- **bronze** = raw + mapping. Select from the raw source and attach reference
  crosswalks / value mappings: patient setting (REV_CTR), GI include/exclude codes,
  site/facility code mapping, spec_group renames, MSBK patient-type override,
  type casts of raw string columns. No row filtering, no business calculations.
- **silver** = filter + new columns. Row filters (spec groups, primary specimens,
  site exclusions, GI exclusions, Epic finalized) and derived case-level columns
  (TAT calculations, flags). Still one row per case/specimen.
- **gold** = feeds the reports. Aggregations, targets, and the shapes the
  dashboard (Lab_KPI_Daily_Dashboard Rmd) consumes. Materialized as tables.

Reference logic source of truth: the R Markdown dashboard
(`Lab_KPI_Daily_Dashboard_Prelim_Run_*.Rmd`); dbt models should reproduce it.
