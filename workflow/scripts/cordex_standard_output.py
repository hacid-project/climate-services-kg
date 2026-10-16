"""Conversion of the CORDEX standard output (CORDEX_standard_output.xls, the
variables requested for the CORDEX-CMIP5 archive) to JSON tables in the format
of the CMOR tables (as data-sources/cmor-tables/data/<era>/<version>.json): one
table per frequency sheet (3hr, 6hr, day, mon, sem, fx), with a Header and a
variable_entry by output variable name.

The entries have the fields of the CMOR tables that the sheets give (the units
are the unformatted ones, the canonical units of the variable), and the CORDEX
specific ones: priority, cmor_variable_name, questions_and_notes and
requested_output, the frequencies and aggregations requested in the CORDEX
archive (the columns frq and ag of the tiers: sub-daily, daily, monthly,
seasonal and fx; ag is a for averaged over the output interval, i for
instantaneous, a number for the minimum samples per day if not averaged, m and
s for the days in month and season).
"""

import json

import xlrd

FREQUENCY_SHEETS = ["3hr", "6hr", "day", "mon", "sem", "fx"]

# Columns of the frequency sheets (by header) and the fields of the entries
FIELDS = {
    "priority": "priority",
    "long name": "long_name",
    "comment": "comment",
    "questions&notes": "questions_and_notes",
    "output variable name": "out_name",
    "standard name": "standard_name",
    "unformatted units": "units",
    "cell-method": "cell_methods",
    "positive": "positive",
    "type": "type",
    "dimensions": "dimensions",
    "CMOR variable name": "cmor_variable_name",
    "realm": "modeling_realm",
    "cell_measures": "cell_measures",
    "flag_values": "flag_values",
    "flag_meanings": "flag_meanings",
}

# Requested output: the (frq, ag) column pairs that follow flag_meanings, and fx
REQUESTED_OUTPUT = [
    ("sub-daily", "Tier 2", "samples_per_day"),
    ("daily", "Tier 1", "samples_per_day"),
    ("monthly", "Core", "samples_per_month"),
    ("seasonal", None, "samples_per_season"),
]


def text(value):
    """A cell value as text (numbers without a decimal part as integers)."""
    if isinstance(value, float):
        return str(int(value)) if value.is_integer() else str(value)
    return " ".join(str(value).split())


def header_row(sheet):
    return next(r for r in range(sheet.nrows) if text(sheet.cell_value(r, 0)) == "priority")


def sheet_date(book, sheet):
    """The date of the sheet (the date cell in its first rows), as ISO date."""
    for r in range(min(3, sheet.nrows)):
        for cell in sheet.row(r):
            if cell.ctype in (xlrd.XL_CELL_NUMBER, xlrd.XL_CELL_DATE) and cell.value > 30000:
                return xlrd.xldate.xldate_as_datetime(cell.value, book.datemode).date().isoformat()
    return None


def table(book, name):
    sheet = book.sheet_by_name(name)
    hr = header_row(sheet)
    headers = [text(c.value) for c in sheet.row(hr)]
    columns = {h: i for i, h in reversed(list(enumerate(headers))) if h}
    flag_meanings = columns["flag_meanings"]
    entries = {}
    for r in range(hr + 1, sheet.nrows):
        row = [text(c.value) for c in sheet.row(r)]
        out_name = row[columns["output variable name"]]
        if not out_name:
            continue
        entry = {"frequency": name}
        for header, field in FIELDS.items():
            value = row[columns[header]] if header in columns else ""
            if field == "units" and not value:
                value = row[columns["units"]]
            if value:
                entry[field] = value
        requested = {}
        for i, (key, tier, samples) in enumerate(REQUESTED_OUTPUT):
            frq, ag = row[flag_meanings + 1 + 2 * i], row[flag_meanings + 2 + 2 * i]
            if frq:
                requested[key] = {
                    k: v for k, v in [("tier", tier), (samples, frq), ("aggregation", ag or None)] if v
                }
        fx = row[flag_meanings + 1 + 2 * len(REQUESTED_OUTPUT)]
        if fx:
            requested["fx"] = {}
        entry["requested_output"] = requested
        entries[out_name] = entry
    return {
        "Header": {
            "table_id": f"Table {name}",
            "frequency": name,
            "project_id": "CORDEX",
            "table_date": sheet_date(book, sheet),
            "title": next(
                (t for r in range(hr) if (t := text(sheet.cell_value(r, 1))).endswith(")")), None
            ),
            "source": "CORDEX_standard_output.xls",
        },
        "variable_entry": entries,
    }


book = xlrd.open_workbook(snakemake.input[0])
# The general notes (the longest text of the sheet "general")
general_sheet = book.sheet_by_name("general")
general = max(
    (text(c.value) for r in range(general_sheet.nrows) for c in general_sheet.row(r)), key=len
)
tables = [table(book, name) for name in FREQUENCY_SHEETS]
for t in tables:
    t["Header"]["comment"] = general

with open(snakemake.output[0], "w") as f:
    json.dump(tables, f, indent=2, ensure_ascii=False)
    f.write("\n")
