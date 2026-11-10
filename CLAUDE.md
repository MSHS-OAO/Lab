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

## Model map

| Area | bronze | silver | gold |
|---|---|---|---|
| Calendar | `date_filter` (from `mshs_holidays`) | | |
| Cytology | `powerpath_bronze` | `powerpath_cyto_biopsy_silver` (Epic-finalized, + frozen history) | `powerpath_cyto_gold` |
| Surgical pathology | `powerpath_bronze` | `powerpath_daily_silver` | `powerpath_sp_gold` |
| Cytology backlog | `cyto_backlog_bronze` | `cyto_backlog_silver` | `cyto_backlog_gold` |
| AP dashboard | | | `ap_dashboard_template`, `ap_dashboard_gold` |
| Clinical pathology (SCC) | `scc_bronze` | `scc_silver` | `scc_gold`, `cp_*_dashboard_template`, `cp_tat_gold`, `cp_vol_gold`, `cp_missing_collections_gold`, `cp_add_on_gold` |

Site codes follow R: PACC stays PACC, BIMC -> MSBI (then excluded). spec_group BREAST -> Breast.
Formatting (colours, kable, pivots to site columns) stays in the R report; gold returns long tables.
Shared AP summary logic is the `ap_signed_out_summary` macro.
