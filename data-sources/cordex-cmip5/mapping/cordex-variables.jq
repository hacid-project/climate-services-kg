# Variables of the CORDEX-CMIP5 datasets (ESGF search results), shared by the
# mapping (datasets.jq) and the analysis of the variables
# (analysis/variables-check.jq).
#
# The modules of data-sources/cmip5/mapping (esgf.jq) and of
# data-sources/cmor-tables/mapping must be in the library path (-L).

include "esgf";

# CMIP5 CMOR tables of the time frequencies of the CORDEX datasets, where
# their variables are looked up first (the variables of the other frequencies,
# as 1hr and sem, in any table)
def frequency_tables:
    {
        "3hr": ["3hr"],
        "6hr": ["6hrPlev", "6hrLev"],
        "day": ["day", "cfDay"],
        "mon": ["Amon", "Lmon", "LImon", "OImon", "aero", "cfMon"],
        "fx": ["fx"]
    };

# Key of a variable of a dataset of a time frequency
def variable_key($variable; $frequency): "\($variable) \($frequency)";

# The MIP variable of a variable of a time frequency, resolved from its
# definitions in the CMIP5 CMOR tables (cmip5_variable_iri), in the tables of
# the time frequency first ($entries_by_name: the CMIP5 CMOR tables by
# cmip5_entries_by_name)
def mip_variable_iri_of($variable; $frequency; $entries_by_name):
    {variable: $variable, frequency: $frequency, tables: (frequency_tables[$frequency] // [])} |
    cmip5_variable_iri($entries_by_name);

def _cordex_variables_base: ns + "variables/cordex/";

def cordex_variables_collection: ns + "variables/cordex";

# IRI of a variable defined locally (input: its out_name)
def cordex_variable_iri: _cordex_variables_base + @uri;

# Variables defined locally, by out_name: the variables of the CORDEX standard
# output ($standard_output: its tables, CORDEX_standard_output.json) whose MIP
# variable is not a variable of the KG ($kg: object with the IRIs of the
# variables of the KG as keys) at any of their frequencies, with their entry
# (of the daily table, if they have one, otherwise the first one)
def local_variables($standard_output; $entries_by_name; $kg):
    [$standard_output[] | .variable_entry | to_entries[] | .value + {name: .key}] |
    group_by(.name) |
    map(
        select(all(.[]; $kg[mip_variable_iri_of(.name; .frequency; $entries_by_name)] | not)) |
        {key: .[0].name, value: ((map(select(.frequency == "day")) + .)[0] | del(.name))}
    ) |
    from_entries;

# IRIs of the variables of the datasets (input: their ESGF metadata, as an
# array), by variable_key: the MIP variables (mip_variable_iri_of), unless they
# are not variables of the KG and the variable is defined locally
# ($local_variables, by local_variables)
def variable_iris($entries_by_name; $local_variables; $kg):
    [.[] | {variable: .variable[], frequency: .time_frequency[0]}] |
    unique |
    map(
        . as {$variable, $frequency} |
        mip_variable_iri_of($variable; $frequency; $entries_by_name) as $iri |
        {
            key: variable_key($variable; $frequency),
            value: (if ($kg[$iri] | not) and $local_variables[$variable] then $variable | cordex_variable_iri else $iri end)
        }
    ) |
    from_entries;

# The IRIs of the variables of the KG (input: an array, as
# data-sources/cmor-tables/data/variable-iris.json) as object keys
def iri_set: map({key: ., value: true}) | from_entries;

# --- Known issues of the datasets (mapping/data-issues.json)

# Whether a dataset (input: its ESGF metadata) matches a condition of
# data-issues.json, {<field>: [<values>]}: each field has one of the values
def matches($match):
    . as $dataset |
    all($match | to_entries[]; .value as $values | any($dataset[.key] | if type == "array" then .[] else . end; . as $value | $values | index($value)));

# Whether a dataset (input: its ESGF metadata) is excluded
# ($issues: data-issues.json)
def excluded($issues): . as $dataset | any($issues.excluded_datasets[]; .match as $m | $dataset | matches($m));

# The CF standard name of the standard name of a variable of a dataset (input:
# its ESGF metadata) known to be used in its place, if any
def standard_name_alias($issues; $variable; $standard_name):
    . as $dataset |
    [$issues.standard_name_aliases[] | select(.standard_name == $standard_name) | select(.match as $m | $dataset | matches($m) and ($m.variable // [$variable] | index($variable)))][0].cf_standard_name;
