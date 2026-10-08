# Parser for legacy (CMOR 2, e.g. CMIP5) plain-text tables.
# To be used on the raw lines of one or more tables (jq -R -n, reading the
# input files with `inputs`).
#
# The result is an array with a table for each input file, each one with the
# same shape as the CMOR 3 JSON tables, so that a single mapping can handle
# every edition:
#   {
#     "Header": {"table_id": "Table Amon", ...},
#     "variable_entry": {"tas": {"standard_name": "air_temperature", ...}, ...},
#     "axis_entry": {...},
#     ...
#   }
# Keys repeated in the same section (e.g. expt_id_ok) become arrays.

# Incomplete trim function, just good enough for current usage
def trim: sub("^\\s+"; "") | sub("\\s+$"; "");

def add_value($key; $value):
    if has($key)
    then .[$key] |= (if type == "array" then . + [$value] else [., $value] end)
    else .[$key] = $value
    end;

# Parse the lines of a table
def parse_table:
    reduce (
        .[] |
        # '!' starts a comment (it never occurs inside values)
        sub("!.*$"; "") | trim | select(. != "") |
        capture("^(?<key>[A-Za-z0-9_]+):\\s*(?<value>.*)$")
    ) as $line (
        {Header: {}, "@section": ["Header"]};
        .["@section"] as $section |
        if ($line.key | endswith("_entry"))
        then
            # Start of a new entry (variable_entry, axis_entry, ...)
            .["@section"] = [$line.key, $line.value] |
            if getpath(.["@section"]) == null then setpath(.["@section"]; {}) else . end
        else
            setpath($section; getpath($section) | add_value($line.key; $line.value))
        end
    ) |
    del(.["@section"]);

[inputs | {file: input_filename, line: .}] |
group_by(.file) |
map(map(.line) | parse_table)
