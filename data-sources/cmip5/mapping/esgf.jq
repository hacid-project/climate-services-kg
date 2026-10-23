# Functions shared by the mappings of the ESGF search results (CMIP5 and
# CORDEX-CMIP5 datasets): temporal grids, variables, scenarios and IRIs.
#
# Needs the modules of data-sources/cmor-tables/mapping in the library path.

include "mip-variables";

# --- Time

def _is_leap_year: . % 4 == 0 and (. % 100 != 0 or . % 400 == 0);

def _days_in_month($year):
    if . == 2 and ($year | _is_leap_year) then 29
    else [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][. - 1]
    end;

# Dates as {y, m, d}
def _date_key: [.y, .m, .d];

def _add_day:
    if .d < (.y as $y | .m | _days_in_month($y)) then .d += 1
    elif .m < 12 then .m += 1 | .d = 1
    else .y += 1 | .m = 1 | .d = 1
    end;

def _add_months($n): (.y * 12 + .m - 1 + $n) as $months | .y = ($months / 12 | floor) | .m = $months % 12 + 1;

def _pad($digits): tostring | ("0" * ([$digits - length, 0] | max)) + .;

def _datetime_string: "\(.y | _pad(4))-\(.m | _pad(2))-\(.d | _pad(2))T00:00:00Z";

# ISO date time (as in the ESGF results, e.g. 1859-12-01T12:00:00Z) rounded down
# or up to the time frequency: the time frequencies shorter than a day are
# rounded to days, monClim to months
def round_datetime($frequency; $up):
    (
        capture("^(?<y>[0-9]+)-(?<m>[0-9]+)-(?<d>[0-9]+)T(?<hh>[0-9]+):(?<mm>[0-9]+):(?<ss>[0-9.]+)")
        // error("unsupported date time: \(.)")
    ) |
    map_values(tonumber) |
    (.hh == 0 and .mm == 0 and .ss == 0) as $midnight |
    {y, m, d} as $date |
    ({"1hr": "day", "3hr": "day", "6hr": "day", "monClim": "mon"}[$frequency] // $frequency) as $granularity |
    if $granularity == "day" then
        $date | if $up and ($midnight | not) then _add_day end
    elif $granularity == "mon" then
        ($date | .d = 1) | if $up and _date_key < ($date | _date_key) then _add_months(1) end
    elif $granularity == "sem" then
        ($date | .m = ([.m, 6] | min) | .d = 1) | if $up and _date_key < ($date | _date_key) then _add_months(6) end
    elif $granularity == "yr" then
        ($date | .m = 1 | .d = 1) | if $up and _date_key < ($date | _date_key) then .y += 1 end
    else
        error("unknown granularity \($frequency)")
    end |
    _datetime_string;

# Temporal grids of the time frequencies: [description, grid type, step, period,
# step in period, offset]
def _time_frequencies:
    {
        "1hr": ["one hour", "regular", "PT1H", null, null, null],
        "3hr": ["three hours", "regular", "PT3H", null, null, null],
        "6hr": ["six hours", "regular", "PT6H", null, null, null],
        "day": ["day", "regular", "P1D", null, null, null],
        "mon": ["month", "regular", "P1M", null, null, null],
        "monClim": ["all time aggregated month of the year", "periodic", null, "P1M", "P1Y", null],
        "sem": ["season", "regular", "P3M", null, null, "P2M"],
        "yr": ["year", "regular", "P1Y", null, null, null],
        "fx": ["all time", null, null, null, null, null]
    };

# Temporal grid of a dataset (input: its ESGF metadata; null if its time
# interval is not known): its time interval rounded to the time frequency, and
# the type and values of its grid
def temporal_grid:
    .time_frequency[0] as $frequency |
    if .datetime_start == null or .datetime_stop == null then null
    else
        ([.datetime_start, .datetime_stop] | min | round_datetime($frequency; false)) as $start |
        ([.datetime_start, .datetime_stop] | max | round_datetime($frequency; true)) as $end |
        (_time_frequencies[$frequency] // error("unknown time frequency \($frequency)")) as [$description, $type, $step, $period, $in_period_step, $offset] |
        {
            $start,
            $end,
            grid_type_id: (if $type != null then [$type, $step, $period, $in_period_step, $offset | values] | join("/") else null end),
            dimensional_space_type: {
                points: "IntervalSampling",
                regular: "SimpleRegularBinning",
                periodic: "SinglePeriodicBinning",
                constant: "SingleBinBinning"
            }[$type // ""],
            $step,
            $period,
            $in_period_step,
            $offset
        }
    end;

# --- Variables

# Entries of the CMIP5 CMOR tables (input: the tables, as in
# data-sources/cmor-tables/data/cmip5/5.0.json) by key and out_name, with their
# table
def cmip5_entries_by_name:
    [
        .[] | select(.variable_entry) |
        ((.Header.table_id // "") | sub("^Table "; "")) as $table |
        .variable_entry | to_entries[] |
        .value + {key, out_name: (.value.out_name // .key), $table}
    ] |
    [.[] | {name: .key, entry: .}, {name: .out_name, entry: .}] |
    group_by(.name) |
    map({key: .[0].name, value: (map(.entry) | unique)}) |
    from_entries;

# Definitions of a variable of a dataset in the CMIP5 CMOR tables, as the input
# of mip_variable_iri (input: {tables, variable, frequency}, the candidate
# tables of the dataset, its variable and time frequency): the entries of the
# candidate tables whose key or out_name is the variable (the ESGF results use
# either), or if there are none (e.g. a variable of the "day" table in "cfDay",
# or tables not in the CMOR tables, as "AmonExtras") the entries of any table.
# Among them, a climatology (time frequency monClim) is defined on time2, the
# other datasets not. Of the remaining entries, only the table, dimensions,
# standard name and units on which all agree are given.
def _cmip5_candidates($entries_by_name):
    . as {$tables, $variable, $frequency} |
    ($entries_by_name[$variable] // []) as $entries |
    [$entries[] | select(.table as $table | $tables | index($table))] |
    if . == [] then $entries end |
    ([.[] | select((.dimensions // "" | test("\\btime2\\b")) == ($frequency == "monClim"))] | if . == [] then null end) // .;

def cmip5_variable_spec($entries_by_name):
    . as {$tables, $variable} |
    _cmip5_candidates($entries_by_name) as $candidates |
    def agreed(f): [$candidates[] | f] | unique | if length == 1 then .[0] else null end;
    {
        out_name: (agreed(.out_name) // $variable),
        era: "cmip5",
        table: (if $candidates == [] then (if ($tables | length) == 1 then $tables[0] else null end) else agreed(.table) end),
        dimensions: agreed(.dimensions),
        quantity: agreed(.standard_name),
        units: agreed(.units)
    };

# IRI of the MIP variable of a variable of a dataset (input as for
# cmip5_variable_spec): the IRI resolved from each of the definitions of the
# variable (see cmip5_variable_spec), if they all resolve to the same one (e.g.
# a variable in several tables, renamed in all of them), otherwise the one
# resolved from what they agree on (cmip5_variable_spec). Needs the module
# mip-variables (data-sources/cmor-tables/mapping) in the library path.
def cmip5_variable_iri($entries_by_name):
    (
        [
            _cmip5_candidates($entries_by_name)[] |
            {out_name, era: "cmip5", table, dimensions, quantity: .standard_name, units} |
            mip_variable_iri
        ] |
        unique
    ) as $iris |
    if ($iris | length) == 1 then $iris[0] else cmip5_variable_spec($entries_by_name) | mip_variable_iri end;

# As cmip5_variable_iri, resolving the MIP variables with the index of the
# mapping ($mip_index, data-sources/cmor-tables/data/mip-mapping-index.json, see
# mip_mapping_index), to resolve the variables of many datasets
def cmip5_variable_iri($entries_by_name; $mip_index):
    (
        [
            _cmip5_candidates($entries_by_name)[] |
            {out_name, era: "cmip5", table, dimensions, quantity: .standard_name, units} |
            mip_variable_iri_indexed($mip_index)
        ] |
        unique
    ) as $iris |
    if ($iris | length) == 1 then $iris[0] else cmip5_variable_spec($entries_by_name) | mip_variable_iri_indexed($mip_index) end;

# Index of the MIP variables of the variables of the CMIP5 CMOR tables
# ($entries_by_name, see cmip5_entries_by_name), from the configuration alone
# (the tables and the index of the mapping of the MIP variables, $mip_index):
# {<name>: {<table>: {climatology, other}}}, the IRI resolved by
# cmip5_variable_iri for a dataset of the table (or of a table without the
# name, "") with time frequency monClim or other. Built once, to resolve the
# variables of many datasets (cmip5_variable_iri_indexed).
def cmip5_variable_index($entries_by_name; $mip_index):
    $entries_by_name |
    with_entries(
        .key as $name |
        .value = (
            [(.value | map(.table) | unique)[], ""] |
            map({
                key: .,
                value: (
                    (if . == "" then [] else [.] end) as $tables |
                    {
                        climatology: ({variable: $name, tables: $tables, frequency: "monClim"} | cmip5_variable_iri($entries_by_name; $mip_index)),
                        other: ({variable: $name, tables: $tables, frequency: ""} | cmip5_variable_iri($entries_by_name; $mip_index))
                    }
                )
            }) |
            from_entries
        )
    );

# IRI of the MIP variable of a variable of a dataset of a CMIP5 table (input:
# {table, variable, frequency}) from the index ($index, cmip5_variable_index),
# as cmip5_variable_iri with the table of the dataset as candidate table (a name
# not in the tables is resolved from the name and table)
def cmip5_variable_iri_indexed($index; $entries_by_name; $mip_index):
    (if .frequency == "monClim" then "climatology" else "other" end) as $kind |
    if $index[.variable] then
        ($index[.variable][.table] // $index[.variable][""])[$kind]
    else
        .tables = [.table] | cmip5_variable_iri($entries_by_name; $mip_index)
    end;

# --- IRIs and literals

def ns: "https://w3id.org/hacid/data/cs/";

# --- Variables of the models (mapping/variables.json)

# Collection of the variables defined locally for a CMIP5 model (its ESGF name)
def cmip5_model_variables_collection($model): ns + "variables/cmip5/" + ($model | @uri);

# IRI of a variable defined locally for a CMIP5 model (input: its name)
def cmip5_model_variable_iri($model): cmip5_model_variables_collection($model) + "/" + @uri;

# IRI of a variable (input: its name) of a dataset of a CMIP5 model, given the
# variables of the models ($variables, mapping/variables.json): none if it is
# skipped, the variable defined locally for the model if any, otherwise the
# MIP variable (of the name it is renamed to for the model, if any) resolved
# by mip_iri (input: the name)
def cmip5_dataset_variable_iri($variables; $model; mip_iri):
    if $variables.skip[.] then
        empty
    elif $variables.local[$model][.] then
        cmip5_model_variable_iri($model)
    else
        ($variables.renames[$model][.].variable // .) | mip_iri
    end;

# Percent-encoding as in Python's urllib.parse.quote (keeping "/")
def quote: @uri | gsub("%2F"; "/");

def id($iri): {"@id": $iri};

# Typed literal (null if the value is null)
def typed($type): if . == null then null else {"@value": ., "@type": $type} end;

# English literal (null if the value is null)
def en: if . == null then null else {"@value": ., "@language": "en"} end;

# IRIs of the scenarios of the experiments (input: the experiment ids)
def scenario_iris:
    [
        .[] |
        {
            rcp45: "RCP/RCP4.5",
            rcp85: "RCP/RCP8.5",
            rcp26: "RCP/RCP2.6",
            rcp60: "RCP/RCP6"
        }[.] // empty |
        ns + "scenarios/\(.)"
    ];

# IRIs of the temporal region, of its specialization and of the temporal grid
# (variable and quantization) of a temporal grid (input: temporal_grid)
def temporal_iris:
    if . == null then null
    else
        "\(ns)dimensions/time/reference-frames/gregorian/regions/\(.start)-\(.end)" as $region |
        {
            region: $region,
            specialization: "\($region)/specialization",
            variable: (if .grid_type_id != null then "\($region)/quantized/\(.grid_type_id)" else null end),
            quantization: (if .grid_type_id != null then "\(ns)dimensions/time/reference-frames/gregorian/quantizations/\(.grid_type_id)" else null end)
        }
    end;

# JSON-LD context of the nodes of the mappings of the ESGF search results
def esgf_context:
    {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        xsd: "http://www.w3.org/2001/XMLSchema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        data: "https://w3id.org/hacid/onto/data/"
    };
