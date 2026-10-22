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

# Index of the MIP variables of the variables of the CMIP5 CMOR tables
# ($entries_by_name, see cmip5_entries_by_name) for the CORDEX datasets, from
# the configuration alone (the tables, frequency_tables, the index of the
# mapping of the MIP variables, $mip_index): {<name>: {<frequency>: <IRI>}},
# the IRI resolved as mip_variable_iri_of for a dataset of each time frequency
# of frequency_tables (or of another one, ""). Built once, to resolve the
# variables of many datasets (variable_iri_of).
def cordex_variable_index($entries_by_name; $mip_index):
    $entries_by_name |
    with_entries(
        .key as $name |
        .value = (
            [(frequency_tables | keys[]), ""] |
            map({
                key: .,
                value: (
                    {variable: $name, frequency: ., tables: (frequency_tables[.] // [])} |
                    cmip5_variable_iri($entries_by_name; $mip_index)
                )
            }) |
            from_entries
        )
    );

def _cordex_variables_base: ns + "variables/cordex/";

def cordex_variables_collection: ns + "variables/cordex";

# IRI of a variable defined locally (input: its out_name)
def cordex_variable_iri: _cordex_variables_base + @uri;

# IRI of a variable of a dataset of a time frequency (the name to resolve, see
# cordex_variable_name): the MIP variable (from
# the index, $index, see cordex_variable_index, or resolved for a name not in
# the tables or a monClim frequency), unless it is not a variable of the KG
# ($kg) and the variable is defined locally ($local_variables, see
# local_variables)
def variable_iri_of($variable; $frequency; $index; $entries_by_name; $mip_index; $local_variables; $kg):
    (
        ($index[$variable] | values | .[$frequency] // (if $frequency != "monClim" then .[""] else empty end)) //
        (
            {variable: $variable, frequency: $frequency, tables: (frequency_tables[$frequency] // [])} |
            cmip5_variable_iri($entries_by_name; $mip_index)
        )
    ) as $iri |
    if ($kg[$iri] | not) and $local_variables[$variable] then $variable | cordex_variable_iri else $iri end;

# Variables at a single level (pressure or height), by out_name, from their
# specification ($levels, mapping/level-variables.json): for each base and
# level, <base><level> (e.g. hus200, at 200 hPa) and <base><level>m (e.g.
# ua50m, at 50 m), and the base itself on all the levels if all_levels (e.g.
# clfr), with an entry as those of the CMOR tables (long name at the level,
# standard name and units of the base), marked as specified (its long name is
# given)
def level_variables($levels):
    $levels.variables | to_entries | map(
        .key as $base |
        .value as $spec |
        {long_name: $spec.long_name, standard_name: $spec.standard_name, units: $spec.units,
         modeling_realm: "atmos", dimensions: "longitude latitude time", specified: true} as $entry |
        (
            (if $spec.all_levels then {key: $base, value: ($entry | .dimensions = "longitude latitude alevel time")} else empty end),
            ($spec.pressure_levels[]? as $level | {key: "\($base)\($level)", value: ($entry | .long_name += " at \($level)hPa")}),
            ($spec.height_levels[]? as $level | {key: "\($base)\($level)m", value: ($entry | .long_name += " at \($level)m")})
        )
    ) | from_entries;

# The name of a variable (input) of the datasets to resolve, given the
# specifications of the variables at a single level ($levels) and of the other
# variables not in the CMOR tables ($locals, mapping/local-variables.json):
# none if skipped ($locals.skip), the variable it is renamed to
# ($locals.renames), or the name with the base of a single level variable
# replaced by the one it is an alias of ($levels.aliases, e.g. u200 is ua200)
def cordex_variable_name($levels; $locals):
    if $locals.skip[.] then
        empty
    elif $locals.renames[.] then
        $locals.renames[.].variable
    else
        (capture("^(?<base>[A-Za-z]+)(?<level>[0-9]+m?)$") // null) as $name |
        if $name != null and $levels.aliases[$name.base] then $levels.aliases[$name.base] + $name.level else . end
    end;

# Variables defined locally, by out_name: the variables of the CORDEX standard
# output ($standard_output: its tables, CORDEX_standard_output.json) whose MIP
# variable is not a variable of the KG ($kg: object with the IRIs of the
# variables of the KG as keys) at any of their frequencies, with their entry
# (of the daily table, if they have one, otherwise the first one), the
# variables at a single level ($levels, see level_variables) whose MIP
# variable is not a variable of the KG, and the other variables not in the
# CMOR tables ($locals.local, mapping/local-variables.json, marked as
# specified)
def local_variables($standard_output; $levels; $locals; $entries_by_name; $kg):
    (
        [$standard_output[] | .variable_entry | to_entries[] | .value + {name: .key}] |
        group_by(.name) |
        map(
            select(all(.[]; $kg[mip_variable_iri_of(.name; .frequency; $entries_by_name)] | not)) |
            {key: .[0].name, value: ((map(select(.frequency == "day")) + .)[0] | del(.name))}
        ) |
        from_entries
    ) as $requested |
    (
        level_variables($levels) +
        ($locals.local | map_values(. + {specified: true})) |
        with_entries(select(($kg[mip_variable_iri_of(.key; ""; $entries_by_name)] | not) and $requested[.key] == null))
    ) + $requested;

# IRIs of the variables of the datasets (input: their ESGF metadata, as an
# array), by variable_key: the MIP variables (mip_variable_iri_of, of the name
# to resolve, see cordex_variable_name), unless they are not variables of the
# KG and the variable is defined locally ($local_variables, by
# local_variables); null for the variables skipped
def variable_iris($entries_by_name; $local_variables; $levels; $locals; $kg):
    [.[] | {variable: .variable[], frequency: .time_frequency[0]}] |
    unique |
    map(
        . as {$variable, $frequency} |
        {
            key: variable_key($variable; $frequency),
            value: (
                first(
                    ($variable | cordex_variable_name($levels; $locals)) as $name |
                    mip_variable_iri_of($name; $frequency; $entries_by_name) as $iri |
                    if ($kg[$iri] | not) and $local_variables[$name] then $name | cordex_variable_iri else $iri end
                ) // null
            )
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

# The rule of model_variables (variables of a model, with their own units)
# for a variable of a dataset (input: its ESGF metadata), if any
def model_variable($issues; $variable):
    . as $dataset |
    [$issues.model_variables[]? | select(.variable == $variable) | select(.match as $m | $dataset | matches($m))][0];

# IRI of the collection of the variables of a model
def model_variables_collection($model): cordex_variables_collection + "/" + ($model | @uri);

# IRI of a variable of a model (input: its rule of model_variables)
def model_variable_iri: model_variables_collection(.model) + "/" + (.variable | @uri) + "/" + (.units | @uri);

# The correct units of a variable of a dataset (input: its ESGF metadata)
# whose units are known to be wrong (units_errors), if any
def units_error($issues; $variable):
    . as $dataset |
    [$issues.units_errors[]? | select(.match as $m | $dataset | matches($m) and ($m.variable // [$variable] | index($variable)))][0].units;
