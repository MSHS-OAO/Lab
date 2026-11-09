-- Gold: cytology signed-out summary (CYTO GYN / CYTO NONGYN). Mirrors cyto_prep() summary.
{{ ap_signed_out_summary(ref('powerpath_cyto_biopsy_silver'), ['CYTO GYN', 'CYTO NONGYN']) }}
