-- Gold: surgical pathology signed-out summary (Breast / GI). Mirrors patho_prep() summary.
{{ ap_signed_out_summary(ref('powerpath_daily_silver'), ['Breast', 'GI']) }}
