# Builds the dbt-vs-dashboard verification workbook from a Lab KPI dashboard HTML export.
# Usage: python verification/build_verification_workbook.py <dashboard.html> <output.xlsx>
# Update REPORT_DATE / RESULT_DATE below for the dashboard being checked.
import sys, re
from bs4 import BeautifulSoup
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.formatting.rule import CellIsRule, FormulaRule
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.utils import get_column_letter

HTML, OUT = sys.argv[1], sys.argv[2]
REPORT_DATE, RESULT_DATE = '2026-11-09', '2026-11-08'
SCHEMA = 'opsanalytics_adb_workspace01.lab_staging'
RAW = 'opsanalytics_adb_workspace01.lab'

soup = BeautifulSoup(open(HTML, encoding='utf-8').read(), 'html.parser')
tables = soup.find_all('table')

def grid(t):
    out, pending = [], {}
    for tr in t.find_all('tr'):
        row, ci = [], 0
        cells = tr.find_all(['th', 'td'])
        k = 0
        while k < len(cells) or (ci in pending):
            if ci in pending:
                txt, left = pending[ci]
                row.append(txt)
                if left > 1: pending[ci] = (txt, left - 1)
                else: del pending[ci]
                ci += 1; continue
            c = cells[k]; k += 1
            txt = c.get_text(' ', strip=True)
            cs, rs = int(c.get('colspan', 1)), int(c.get('rowspan', 1))
            for _ in range(cs):
                row.append(txt)
                if rs > 1: pending[ci] = (txt, rs - 1)
                ci += 1
        out.append(row)
    return out

def data_rows(g, first):
    for i, r in enumerate(g):
        if r and r[0].startswith(first):
            return r, g[i + 1:]
    raise ValueError(first)

def val(s):
    s = s.strip()
    if s == 'NA' or s == '': return 'NA', 'num', 0
    m = re.fullmatch(r'(-?\d+(?:\.\d+)?)%', s)
    if m: return round(float(m.group(1)) / 100, 4), 'num', 0.005
    m = re.fullmatch(r'<=\s*(\d+(?:\.\d+)?)\s*(min|Days)', s)
    if m: return float(m.group(1)), 'num', 0
    m = re.fullmatch(r'-?\d+(?:\.\d+)?', s)
    if m: return float(s), 'num', 0
    return s, 'text', 0

rows = []   # step, area, table, item, priority, setting, site, metric, expected, rule, tol, key, note
def add(step, area, table, item, prio, setting, site, metric, raw, keyparts, note=''):
    v, rule, tol = val(raw)
    if metric.startswith('TGT') or metric == 'TARGET_DAYS': tol = 0
    rows.append([step, area, table, item, prio, setting, site, metric, v, rule, tol,
                 '|'.join([step] + keyparts), note])

def split_tp(s):
    m = re.fullmatch(r'(.+?) - (All|Stat|Routine) Labs', s)
    return m.group(1), m.group(2)

# ---- CP TAT tables ---------------------------------------------------------
def cp_tat(ti, step, area, sites):
    g = grid(tables[ti]); hdr, data = data_rows(g, 'Test & Priority')
    n = len(sites)
    for r in data:
        test, prio = split_tp(r[0])
        label = f'{area} TAT'
        if r[1] == 'ResultedVolume':
            setting = r[2]
            for j, s in enumerate(sites):
                add(step, area, label, test, prio, setting, s, 'Resulted volume', r[3 + j],
                    [test, prio, setting, s, 'RESVOL'])
            continue
        setting = r[2]
        add(step, area, label, test, prio, setting, '', 'Receive-to-result target (min)', r[1],
            [test, prio, setting, 'TGT_R2R'])
        for j, s in enumerate(sites):
            add(step, area, label, test, prio, setting, s, 'Receive-to-result % in target', r[3 + j],
                [test, prio, setting, s, 'R2R'])
        c0 = 3 + n
        add(step, area, label, test, prio, r[c0 + 1], '', 'Collect-to-result target (min)', r[c0],
            [test, prio, r[c0 + 1], 'TGT_C2R'])
        for j, s in enumerate(sites):
            add(step, area, label, test, prio, r[c0 + 1], s, 'Collect-to-result % in target', r[c0 + 2 + j],
                [test, prio, r[c0 + 1], s, 'C2R'])

CP_SITES = ['MSH', 'MSQ', 'MSB', 'MSW', 'MSM', 'MSSN']
cp_tat(0, 'S07', 'Chemistry', CP_SITES)
cp_tat(1, 'S08', 'Hematology', CP_SITES)
cp_tat(2, 'S09', 'Microbiology RRL', CP_SITES)
cp_tat(3, 'S10', 'Infusion', ['RTC'])
cp_tat(8, 'S11', 'Blood Bank', CP_SITES)

# ---- Missing collections / add-ons ---------------------------------------
g = grid(tables[4]); hdr, data = data_rows(g, 'Site')
for j, s in enumerate(hdr[1:]):
    add('S12', 'Missing collections', 'Missing collect times', 'All tests', '', '', s,
        '% labs missing collect time', data[0][1 + j], [s, 'PCT'])
g = grid(tables[5]); hdr, data = data_rows(g, 'Test')
for r in data:
    for j, s in enumerate(hdr[1:]):
        add('S13', 'Add-on orders', 'Add-on volume', r[0], '', '', s, 'Add-on volume', r[1 + j], [r[0], s])

# ---- CP volume -------------------------------------------------------------
def cp_vol(ti, step, area):
    g = grid(tables[ti]); hdr, data = data_rows(g, 'Test & Priority')
    sites = hdr[2:]
    for r in data:
        test, prio = split_tp(r[0])
        for j, s in enumerate(sites):
            add(step, area, f'{area} 24h volume', test, prio, r[1], s, 'Resulted labs', r[2 + j],
                [test, prio, r[1], s])
cp_vol(9, 'S14', 'Chemistry'); cp_vol(10, 'S15', 'Hematology'); cp_vol(11, 'S16', 'Infusion')

# ---- AP efficiency indicators ---------------------------------------------
def grp(s):
    return {'All Breast Specimens': 'Breast', 'GI Biopsies': 'GI'}.get(s, s)

g = grid(tables[6]); hdr, data = data_rows(g, 'Case Type')
sp_sites = ['MSH', 'MSQ', 'PACC', 'MSB', 'MSW', 'MSM']
for r in data:
    sg, setting = grp(r[0]), r[2]
    add('S02', 'Surgical Pathology', 'SP efficiency indicators', sg, '', setting, '', 'Target (business days)', r[1], [sg, setting, 'TARGET_DAYS'])
    add('S02', 'Surgical Pathology', 'SP efficiency indicators', sg, '', setting, 'All', 'No. cases signed out', r[3], [sg, setting, 'All', 'no_cases_signed'])
    for j, s in enumerate(sp_sites):
        add('S02', 'Surgical Pathology', 'SP efficiency indicators', sg, '', setting, s, 'Receive-to-result % in target', r[4 + j], [sg, setting, s, 'received_to_signed_out_within_target'])
    for j, s in enumerate(sp_sites):
        add('S02', 'Surgical Pathology', 'SP efficiency indicators', sg, '', setting, s, 'Avg collect-to-result (cal. days)', r[10 + j], [sg, setting, s, 'avg_collection_to_signed_out'])

g = grid(tables[7]); hdr, data = data_rows(g, 'Case Type')
cy_sites = ['MSH', 'MSQ', 'PACC', 'MSB', 'MSW', 'MSM', 'NYEE']
for r in data:
    sg, setting = r[0], r[2]
    add('S04', 'Cytology', 'Cytology efficiency indicators', sg, '', setting, '', 'Target (business days)', r[1], [sg, setting, 'TARGET_DAYS'])
    add('S04', 'Cytology', 'Cytology efficiency indicators', sg, '', setting, 'All', 'No. cases signed out', r[3], [sg, setting, 'All', 'no_cases_signed'])
    add('S04', 'Cytology', 'Cytology efficiency indicators', sg, '', setting, 'All', 'Receive-to-result % in target (centralized)', r[4], [sg, setting, 'All', 'received_to_signed_out_within_target'])
    for j, s in enumerate(cy_sites):
        add('S04', 'Cytology', 'Cytology efficiency indicators', sg, '', setting, s, 'Avg collect-to-result (cal. days)', r[5 + j], [sg, setting, s, 'avg_collection_to_signed_out'])

# ---- AP 24h volume: R prints these columns under the wrong site labels -------
# R pivots sites in template order (MSB, PACC, MSW, MSH, MSM, [MSSN], MSQ, NYEE) but
# labels them MSH, MSQ, PACC, MSB, MSW, MSM, NYEE. Map label position -> real site.
def ap_vol(ti, step, area, real_sites):
    g = grid(tables[ti]); hdr, data = data_rows(g, 'Case Type')
    labels = hdr[2:]
    for r in data:
        for j, real in enumerate(real_sites):
            note = '' if labels[j] == real else f'Dashboard header says {labels[j]}; R mislabels this column, real site is {real}'
            add(step, area, f'{area} 24h volume', r[0], '', r[1], real, 'No. cases signed out', r[2 + j],
                [r[0], r[1], real, 'no_cases_signed'], note)
ap_vol(12, 'S03', 'Surgical Pathology', ['MSB', 'PACC', 'MSW', 'MSH', 'MSM', 'MSQ'])
ap_vol(13, 'S05', 'Cytology', ['MSB', 'PACC', 'MSW', 'MSH', 'MSM', 'MSQ', 'NYEE'])

# ---- Backlog ---------------------------------------------------------------
for sg in ['CYTO GYN', 'CYTO NONGYN']:
    add('S06', 'Cytology backlog', 'Backlog & accessioned', sg, '', '', '', 'Resulted day is a working day', 'false',
        [sg, 'resulted_date_is_working_day'],
        'Dashboard shows "No cases accessioned on weekends and holidays" (Sun 11/08)')

# ---- Targets reference ----------------------------------------------------
g = grid(tables[16]); hdr, data = data_rows(g, 'Division')
for r in data:
    div, test, prio, setting = r[:4]
    add('S17', 'Reference', 'CP target turnaround times', test, prio, setting, '', f'{div}: receive-to-result target', r[4], [div, test, prio, setting, 'R2R'])
    add('S17', 'Reference', 'CP target turnaround times', test, prio, setting, '', f'{div}: collect-to-result target', r[5], [div, test, prio, setting, 'C2R'])

# ---- Inputs (S01) ----------------------------------------------------------
for item, note in [('scc_raw rows (file 2026-11-09)', ''), ('powerpath_raw rows (file 2026-11-09)', ''),
                   ('cyto_backlog_raw rows (_report_date 2026-11-09)', ''), ('epic_cytology_raw rows', '')]:
    rows.append(['S01', 'Inputs', 'Raw data loaded', item, '', '', '', 'Row count', '> 0', 'gt0', 0,
                 'S01|' + item.split(' ')[0], note])
rows.append(['S01', 'Inputs', 'Raw data loaded', 'scc_silver result date for 2026-11-09 file', '', '', '',
             'Result date', RESULT_DATE, 'text', 0, 'S01|scc_silver_result_date',
             'Dashboard: "Labs Resulted on Sun 11/08/26"'])

# ---- SQL per step ---------------------------------------------------------
def q(s): return re.sub(r'\n {4}', '\n', s).strip()
S = SCHEMA
sql = {
 'S01': f"""
select 'S01|scc_raw' as key, cast(count(*) as string) as value from {RAW}.scc_raw where _source_file like '%{REPORT_DATE}%'
union all
select 'S01|powerpath_raw', cast(count(*) as string) from {RAW}.powerpath_raw where _source_file like '%{REPORT_DATE}%'
union all
select 'S01|cyto_backlog_raw', cast(count(*) as string) from {RAW}.cyto_backlog_raw where _report_date = '{REPORT_DATE}'
union all
select 'S01|epic_cytology_raw', cast(count(*) as string) from {RAW}.epic_cytology_raw
union all
select 'S01|scc_silver_result_date', cast(max(RESULT_DATE) as string) from {S}.scc_silver where _SOURCE_FILE like '%{REPORT_DATE}%'""",
}
def ap_sql(step, div, tab):
    return f"""
select concat_ws('|', '{step}', SPECIMEN_GROUP, PATIENT_SETTING, SITE, METRIC) as key,
       coalesce(cast(VALUE as string), 'NA') as value
from {S}.ap_dashboard_gold
where REPORT_DATE = '{REPORT_DATE}' and DIVISION = '{div}' and TAB = '{tab}'
union all
select distinct concat_ws('|', '{step}', SPECIMEN_GROUP, PATIENT_SETTING, 'TARGET_DAYS'),
       coalesce(cast(TARGET_DAYS as string), 'NA')
from {S}.ap_dashboard_gold
where REPORT_DATE = '{REPORT_DATE}' and DIVISION = '{div}' and TAB = '{tab}'"""
sql['S02'] = ap_sql('S02', 'SURGICAL PATHOLOGY', 'Efficiency Indicators')
sql['S03'] = ap_sql('S03', 'SURGICAL PATHOLOGY', '24 Hour Volume')
sql['S04'] = ap_sql('S04', 'CYTOLOGY', 'Efficiency Indicators')
sql['S05'] = ap_sql('S05', 'CYTOLOGY', '24 Hour Volume')
sql['S06'] = f"""
select concat_ws('|', 'S06', spec_group, 'resulted_date_is_working_day') as key,
       coalesce(cast(resulted_date_is_working_day as string), 'NA') as value
from {S}.cyto_backlog_gold
where _report_date = '{REPORT_DATE}'"""
def cp_sql(step, div):
    return f"""
with t as (select * from {S}.cp_tat_gold where RESULT_DATE = '{RESULT_DATE}' and DIVISION = '{div}')
select concat_ws('|', '{step}', TEST, DASHBOARD_PRIORITY, DASHBOARD_SETTING, SITE, 'R2R') as key,
       coalesce(cast(RECEIVE_RESULT_PERCENT as string), 'NA') as value from t
union all
select concat_ws('|', '{step}', TEST, DASHBOARD_PRIORITY, DASHBOARD_SETTING, SITE, 'C2R'),
       coalesce(cast(COLLECT_RESULT_PERCENT as string), 'NA') from t
union all
select concat_ws('|', '{step}', TEST, DASHBOARD_PRIORITY, DASHBOARD_SETTING, SITE, 'RESVOL'),
       cast(RESULTED_VOLUME as string) from t
union all
select concat_ws('|', '{step}', TEST, DASHBOARD_PRIORITY, DASHBOARD_SETTING, 'TGT_R2R'),
       coalesce(cast(max(RECEIVE_RESULT_TARGET) as string), 'NA') from t group by TEST, DASHBOARD_PRIORITY, DASHBOARD_SETTING
union all
select concat_ws('|', '{step}', TEST, DASHBOARD_PRIORITY, DASHBOARD_SETTING, 'TGT_C2R'),
       coalesce(cast(max(COLLECT_RESULT_TARGET) as string), 'NA') from t group by TEST, DASHBOARD_PRIORITY, DASHBOARD_SETTING"""
sql['S07'] = cp_sql('S07', 'Chemistry'); sql['S08'] = cp_sql('S08', 'Hematology')
sql['S09'] = cp_sql('S09', 'Microbiology RRL'); sql['S10'] = cp_sql('S10', 'Infusion')
sql['S11'] = cp_sql('S11', 'Blood Bank')
sql['S12'] = f"""
select concat_ws('|', 'S12', SITE, 'PCT') as key, coalesce(cast(PERCENT_MISSING as string), 'NA') as value
from {S}.cp_missing_collections_gold where RESULT_DATE = '{RESULT_DATE}'"""
sql['S13'] = f"""
select concat_ws('|', 'S13', TEST, SITE) as key, cast(ADD_ON_VOLUME as string) as value
from {S}.cp_add_on_gold where RESULT_DATE = '{RESULT_DATE}'"""
def vol_sql(step, div):
    return f"""
select concat_ws('|', '{step}', TEST, DASHBOARD_PRIORITY, PT_SETTING, SITE) as key, cast(RESULTED_LABS as string) as value
from {S}.cp_vol_gold where RESULT_DATE = '{RESULT_DATE}' and DIVISION = '{div}'"""
sql['S14'] = vol_sql('S14', 'Chemistry'); sql['S15'] = vol_sql('S15', 'Hematology'); sql['S16'] = vol_sql('S16', 'Infusion')
sql['S17'] = f"""
select concat_ws('|', 'S17', DIVISION, TEST, PRIORITY, PT_SETTING, 'R2R') as key, cast(RECEIVE_TO_RESULT_TARGET as string) as value
from {RAW}.lab_kpi_turnaround_targets
union all
select concat_ws('|', 'S17', DIVISION, TEST, PRIORITY, PT_SETTING, 'C2R'), cast(COLLECT_TO_RESULT_TARGET as string)
from {RAW}.lab_kpi_turnaround_targets"""
sql = {k: q(v) for k, v in sql.items()}

steps = [
 ('S01', 'Inputs: raw files for 11/09 loaded; SCC file resolves to result date 11/08', 'scc_raw, powerpath_raw, cyto_backlog_raw, epic_cytology_raw, scc_silver'),
 ('S02', 'Surgical Pathology - Efficiency Indicators', 'ap_dashboard_gold (powerpath_sp_gold)'),
 ('S03', 'Surgical Pathology - 24h signed-out volume', 'ap_dashboard_gold'),
 ('S04', 'Cytology - Efficiency Indicators', 'ap_dashboard_gold (powerpath_cyto_gold)'),
 ('S05', 'Cytology - 24h signed-out volume', 'ap_dashboard_gold'),
 ('S06', 'Cytology backlog - weekend/holiday handling', 'cyto_backlog_gold'),
 ('S07', 'Chemistry TAT', 'cp_tat_gold'),
 ('S08', 'Hematology TAT', 'cp_tat_gold'),
 ('S09', 'Microbiology RRL TAT + volume', 'cp_tat_gold'),
 ('S10', 'Infusion TAT', 'cp_tat_gold'),
 ('S11', 'Blood Bank TAT + volume', 'cp_tat_gold'),
 ('S12', 'Missing collection times', 'cp_missing_collections_gold'),
 ('S13', 'Add-on order volume', 'cp_add_on_gold'),
 ('S14', 'Chemistry 24h volume', 'cp_vol_gold'),
 ('S15', 'Hematology 24h volume', 'cp_vol_gold'),
 ('S16', 'Infusion 24h volume', 'cp_vol_gold'),
 ('S17', 'CP target turnaround times (reference table)', 'lab.lab_kpi_turnaround_targets'),
]

# ---- Workbook ---------------------------------------------------------------
F = 'Arial'
hfont = Font(name=F, bold=True, color='FFFFFF'); hfill = PatternFill('solid', fgColor='221F72')
body = Font(name=F, size=10); bold = Font(name=F, size=10, bold=True)
inp = PatternFill('solid', fgColor='FFFF00'); blue = Font(name=F, size=10, color='0000FF')
thin = Side(style='thin', color='D0D0D0'); border = Border(bottom=thin)
wrap = Alignment(wrap_text=True, vertical='top')

wb = Workbook()
ws0 = wb.active; ws0.title = 'Instructions'
ins = [
 ('Lab KPI dashboard vs dbt verification', bold),
 (f'Dashboard: Lab KPI Prelim Dashboard 11-09-26 (CP labs resulted {RESULT_DATE}; AP cases signed out {RESULT_DATE}, report date {REPORT_DATE}).', body),
 (f'dbt models are read from {SCHEMA}. Change the schema in the SQL tab if you built to another target.', body),
 ('', body),
 ('How to run a step', bold),
 ('1. In the Steps tab, pick the next step (S01, S02, ...). Its SQL is in the SQL tab.', body),
 ('2. Run the SQL in Databricks. It returns two columns: key and value.', body),
 ('3. Copy the result rows (without the header) and paste them at the bottom of the dbt_results tab, columns A:B (yellow).', body),
 ('4. The Checks tab fills in "dbt value" and "Result" automatically. Steps tab shows the totals.', body),
 ('5. For every Mismatch or "Missing in dbt", log it in the Findings tab (yellow cells) with cause and fix.', body),
 ('', body),
 ('Only cells with a yellow fill are meant to be edited. Everything else is formulas or dashboard values.', body),
 ('', body),
 ('Example of a pasted dbt_results row', bold),
 ('key: S07|Troponin|All|ED & ICU|MSH|R2R     value: 0.981', body),
 ('', body),
 ('How results are judged', bold),
 ('Percentages: dashboard shows whole percents, so a dbt value within 0.5 percentage points matches (tolerance 0.005).', body),
 ('Counts, days and targets: must match exactly. NA on the dashboard must be NA (null) in dbt, or no row at all.', body),
 ('Pending = no rows pasted yet for that step. Missing in dbt = dashboard has a number but dbt returned no row.', body),
 ('', body),
 ('Known dashboard quirk', bold),
 ('The R 24h volume tables for Surgical Pathology and Cytology print site values under the wrong headers '
  '(values are in site order MSB, PACC, MSW, MSH, MSM, MSQ, NYEE but labeled MSH, MSQ, PACC, MSB, MSW, MSM, NYEE). '
  'Rows for S03 and S05 use the real site; the Notes column shows the header the dashboard used. Logged as finding F1.', body),
]
for i, (t, f) in enumerate(ins, 1):
    c = ws0.cell(i, 1, t); c.font = f; c.alignment = Alignment(wrap_text=True, vertical='top')
ws0.column_dimensions['A'].width = 120
ws0['A1'].font = Font(name=F, size=14, bold=True)

# Checks
ws = wb.create_sheet('Checks')
cols = ['Step', 'Area', 'Dashboard table', 'Test / case type', 'Priority', 'Setting', 'Site', 'Metric',
        'Dashboard value', 'Rule', 'Tolerance', 'Key', 'dbt value', 'Result', 'Notes']
widths = [6, 18, 26, 22, 9, 12, 8, 34, 11, 6, 9, 46, 11, 15, 50]
for j, (h, w) in enumerate(zip(cols, widths), 1):
    c = ws.cell(1, j, h); c.font = hfont; c.fill = hfill; c.alignment = Alignment(wrap_text=True, vertical='center')
    ws.column_dimensions[get_column_letter(j)].width = w
order = {s[0]: i for i, s in enumerate(steps)}
rows.sort(key=lambda r: order[r[0]])
for i, r in enumerate(rows, 2):
    step, area, table, item, prio, setting, site, metric, v, rule, tol, key, note = r
    vals = [step, area, table, item, prio, setting, site, metric, v, rule, tol, key, None, None, note]
    for j, x in enumerate(vals, 1):
        c = ws.cell(i, j, x); c.font = body; c.border = border
    ws.cell(i, 9).font = blue
    if isinstance(v, float):
        ws.cell(i, 9).number_format = '0%' if (tol == 0.005) else '0'
    ws.cell(i, 13).value = f'=IFERROR(INDEX(dbt_results!$B:$B,MATCH(L{i},dbt_results!$A:$A,0)),"")'
    ws.cell(i, 13).font = Font(name=F, size=10, color='008000')
    ws.cell(i, 14).value = (
        f'=IF(COUNTIF(dbt_results!$A:$A,A{i}&"|*")=0,"Pending",'
        f'IF(M{i}="",IF(I{i}="NA","Match (no row)","Missing in dbt"),'
        f'IF(OR(I{i}="NA",M{i}="NA"),IF(AND(I{i}="NA",M{i}="NA"),"Match","Mismatch"),'
        f'IF(J{i}="text",IF(LOWER(M{i}&"")=LOWER(I{i}&""),"Match","Mismatch"),'
        f'IF(J{i}="gt0",IF(IFERROR(VALUE(M{i}&""),0)>0,"Match","Mismatch"),'
        f'IF(ISERROR(VALUE(M{i}&"")),"Mismatch",'
        f'IF(ABS(VALUE(M{i}&"")-I{i})<=K{i}+0.000001,"Match","Mismatch")))))))')
last = len(rows) + 1
ws.freeze_panes = 'A2'; ws.auto_filter.ref = f'A1:O{last}'
rng = f'N2:N{last}'
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'LEFT(N2,5)="Match"'], fill=PatternFill('solid', fgColor='C6EFCE')))
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'N2="Mismatch"'], fill=PatternFill('solid', fgColor='FFC7CE')))
ws.conditional_formatting.add(rng, FormulaRule(formula=[f'N2="Missing in dbt"'], fill=PatternFill('solid', fgColor='FFEB9C')))

# dbt_results
wr = wb.create_sheet('dbt_results')
for j, h in enumerate(['key', 'value'], 1):
    c = wr.cell(1, j, h); c.font = hfont; c.fill = hfill
wr.column_dimensions['A'].width = 60; wr.column_dimensions['B'].width = 20
for i in range(2, 3001):
    for j in (1, 2):
        wr.cell(i, j).fill = inp; wr.cell(i, j).font = blue
wr.freeze_panes = 'A2'

# Steps
wst = wb.create_sheet('Steps', 1)
sh = ['Step', 'What is checked', 'dbt model(s)', 'Checks', 'Match', 'Mismatch', 'Missing in dbt', 'Pending', 'Status', 'Date run', 'Notes']
sw = [6, 52, 40, 8, 8, 9, 13, 8, 14, 12, 50]
for j, (h, w) in enumerate(zip(sh, sw), 1):
    c = wst.cell(1, j, h); c.font = hfont; c.fill = hfill; c.alignment = Alignment(wrap_text=True)
    wst.column_dimensions[get_column_letter(j)].width = w
for i, (s, d, m) in enumerate(steps, 2):
    wst.cell(i, 1, s); wst.cell(i, 2, d); wst.cell(i, 3, m)
    wst.cell(i, 4, f'=COUNTIF(Checks!$A:$A,A{i})')
    wst.cell(i, 5, f'=COUNTIFS(Checks!$A:$A,A{i},Checks!$N:$N,"Match*")')
    wst.cell(i, 6, f'=COUNTIFS(Checks!$A:$A,A{i},Checks!$N:$N,"Mismatch")')
    wst.cell(i, 7, f'=COUNTIFS(Checks!$A:$A,A{i},Checks!$N:$N,"Missing in dbt")')
    wst.cell(i, 8, f'=COUNTIFS(Checks!$A:$A,A{i},Checks!$N:$N,"Pending")')
    wst.cell(i, 9, f'=IF(H{i}=D{i},"Not started",IF(AND(F{i}=0,G{i}=0),"Passed","Needs review"))')
    for j in range(1, 12):
        wst.cell(i, j).font = body; wst.cell(i, j).alignment = wrap
    for j in (10, 11):
        wst.cell(i, j).fill = inp; wst.cell(i, j).font = blue
    wst.cell(i, 10).number_format = 'yyyy-mm-dd'
t = len(steps) + 2
wst.cell(t, 2, 'Total').font = bold
for j in range(4, 9):
    col = get_column_letter(j)
    wst.cell(t, j, f'=SUM({col}2:{col}{t-1})').font = bold
srng = f'I2:I{t-1}'
wst.conditional_formatting.add(srng, FormulaRule(formula=['I2="Passed"'], fill=PatternFill('solid', fgColor='C6EFCE')))
wst.conditional_formatting.add(srng, FormulaRule(formula=['I2="Needs review"'], fill=PatternFill('solid', fgColor='FFC7CE')))
wst.freeze_panes = 'A2'

# SQL
wq = wb.create_sheet('SQL')
for j, (h, w) in enumerate([('Step', 6), ('SQL (Databricks)', 130)], 1):
    c = wq.cell(1, j, h); c.font = hfont; c.fill = hfill
    wq.column_dimensions[get_column_letter(j)].width = w
for i, (s, d, m) in enumerate(steps, 2):
    wq.cell(i, 1, s).font = body
    c = wq.cell(i, 2, sql[s]); c.font = Font(name='Courier New', size=9); c.alignment = wrap
    wq.row_dimensions[i].height = 15 * (sql[s].count('\n') + 1)

# Findings
wf = wb.create_sheet('Findings')
fh = ['ID', 'Step', 'Finding', 'Cause', 'Fix / action', 'Owner', 'Status']
fw = [5, 6, 60, 50, 50, 12, 12]
for j, (h, w) in enumerate(zip(fh, fw), 1):
    c = wf.cell(1, j, h); c.font = hfont; c.fill = hfill
    wf.column_dimensions[get_column_letter(j)].width = w
f1 = ['F1', 'S03/S05',
      'R dashboard: Surgical Pathology and Cytology 24h volume tables show values under the wrong site headers.',
      'get_stratified_volume() pivots sites in template order (MSB, PACC, MSW, MSH, MSM, MSQ, NYEE) but kable labels them MSH, MSQ, PACC, MSB, MSW, MSM, NYEE. Confirmed by totals: Cytology GYN IP 36 + 30 = 66 = No. Cases Signed Out, with cases at MSH and PACC per the Efficiency Indicators tab.',
      'dbt (ap_dashboard_gold) stores the real site, so Tableau will show it correctly. No dbt change. Do not "fix" dbt to match the R labels.',
      '', 'Open']
for j, x in enumerate(f1, 1):
    c = wf.cell(2, j, x); c.font = body; c.alignment = wrap
dv = DataValidation(type='list', formula1='"Open,Fixed,Accepted difference,Not a defect"', allow_blank=True)
wf.add_data_validation(dv); dv.add('G2:G200')
for i in range(3, 61):
    for j in range(1, 8):
        wf.cell(i, j).fill = inp; wf.cell(i, j).font = blue; wf.cell(i, j).alignment = wrap

# Dashboard_raw (as printed)
wd = wb.create_sheet('Dashboard_raw')
r0 = 1
for ti, t in enumerate(tables):
    h4 = t.find_previous('h4'); h3 = t.find_previous('h3')
    wd.cell(r0, 1, f'Table {ti}: {h3.get_text(strip=True) if h3 else ""} - {h4.get_text(strip=True) if h4 else ""}').font = bold
    r0 += 1
    for row in grid(t):
        for j, x in enumerate(row, 1):
            wd.cell(r0, j, x).font = body
        r0 += 1
    r0 += 1
wd.column_dimensions['A'].width = 36

wb.save(OUT)
print(len(rows), 'checks;', {s: sum(1 for r in rows if r[0] == s) for s, _, _ in steps})
