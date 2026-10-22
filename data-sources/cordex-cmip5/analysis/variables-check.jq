# Check of the variables of the CORDEX-CMIP5 datasets against the CORDEX
# standard output (the variables requested for the CORDEX archive,
# CORDEX_standard_output.xls converted to JSON tables by the rule
# cordex_cmip5_standard_output).
#
# Input: the pages of the ESGF search results (data/cordex-<n>.json), read
# with -n. Arguments: --slurpfile data_issues mapping/data-issues.json,
# --slurpfile standard_output
# CORDEX_standard_output.json, --slurpfile level_variables
# mapping/level-variables.json, --slurpfile local_spec
# mapping/local-variables.json, --slurpfile cmor_tables (the CMIP5
# CMOR tables, as for the mapping), --slurpfile kg_variables (the IRIs of the
# variables of the KG); the modules of mapping/, data-sources/cmip5/mapping and
# data-sources/cmor-tables/mapping must be in the library path (-L).
#
# Output: {summary, variables}, where variables has, for each variable and time
# frequency of the datasets or of the standard output:
# - variable, frequency, datasets (the number of datasets);
# - requested: "yes" if the standard output requests the variable at the
#   frequency, "other_frequency" if only at other frequencies, otherwise "no",
#   with requested_frequencies;
# - the definitions of the variable: standard_name, standard_units, long_name
#   of the standard output (at the frequency, or else at any frequency), and
#   cmor_standard_name, cmor_units of the CMIP5 CMOR tables (on which their
#   definitions agree, see cmip5_variable_spec), and those found in the
#   datasets (standard_names and units, with the number of datasets);
# - excluded: the number of datasets excluded from the mapping (see
#   mapping/data-issues.json), not considered in the other fields;
# - standard_name_status: null without definitions, otherwise
#   "definitions_differ" if the standard output and the CMOR tables give
#   different standard names, else "match" if all the datasets use one of them,
#   "known_alias" if the others use a name known to be used in place of it
#   (standard_name_aliases in mapping/data-issues.json), "minority_other" if a
#   minority of the datasets use another one (ignored), "majority_other" if a
#   majority do;
# - units_status: null without definitions (the standard output, or else the
#   CMOR tables), otherwise "definitions_differ" if the standard output and the
#   CMOR tables give different units (see canonical_units), else "match" if all
#   the datasets use the units of the definition, "equivalent" if they use the
#   same units written differently (e.g. W/m2 for W m-2, ignored),
#   "known_issue" if the others have units known to be wrong (units_errors in
#   mapping/data-issues.json) or are of a variable of their model with its own
#   units (model_variables), "inconsistent" if some use other units (e.g. K for
#   m), listed in other_units, with the models of their datasets
#   (other_units_models, as <institute>/<model>);
# - variable_iri: the IRI resolved by the mapping, and in_kg, whether it is a
#   variable of the KG or a variable defined locally (see local_variables).

include "esgf";
include "cordex-variables";

# Counts of the values of an array, as "<value> (<count>)", by decreasing count
def _counts: group_by(.) | map([.[0], length]) | sort_by(-.[1]) | map("\(.[0]) (\(.[1]))") | join("; ");

# Canonical form of units (null if missing): the product of the symbols with
# their exponents, whatever the serialization (e.g. "W/m2", "W m-2" and
# "W m^-2" are "W m^-2"; "kg m-2 s-1" and "kg/m2/s" are "kg m^-2 s^-1"),
# simplified ("kg kg-1" is "1"; "Kg" is taken as "kg"); units that cannot be
# parsed (e.g. "None") are kept as they are
def canonical_units:
    if . == null or . == "" then null
    else
        . as $units |
        [scan("/?[^\\s/.*]+") | gsub("\\^|\\*\\*"; "")] |
        map(
            capture("^(?<div>/)?(?<symbol>[A-Za-z%]+|1)(?<exponent>-?[0-9]+)?$") //
            {invalid: true}
        ) |
        if any(.[]; .invalid) or length == 0 then $units
        else
            map(
                select(.symbol != "1") |
                {
                    symbol: ({"Kg": "kg"}[.symbol] // .symbol),
                    exponent: ((.exponent // "1" | tonumber) * (if .div then -1 else 1 end))
                }
            ) |
            group_by(.symbol) |
            map({symbol: .[0].symbol, exponent: (map(.exponent) | add)} | select(.exponent != 0)) |
            if length == 0 then "1"
            else map(if .exponent == 1 then .symbol else "\(.symbol)^\(.exponent)" end) | join(" ")
            end
        end
    end;

$data_issues[0] as $issues |
[inputs | .response.docs[]] as $all_datasets |
[$all_datasets[] | select(excluded($issues) | not)] as $datasets |
# Excluded datasets by variable and frequency
(
    [$all_datasets[] | select(excluded($issues)) | variable_key(.variable[]; .time_frequency[0])] |
    group_by(.) | map({key: .[0], value: length}) | from_entries
) as $excluded |
($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
($kg_variables[0] | iri_set) as $kg |
local_variables($standard_output[0]; $level_variables[0]; $local_spec[0]; $entries_by_name; $kg) as $local_variables |
($datasets | variable_iris($entries_by_name; $local_variables; $level_variables[0]; $local_spec[0]; $kg)) as $variable_iris |
# Entries of the standard output by variable, with their frequency
(
    [$standard_output[0][] | .variable_entry | to_entries[] | .value + {name: .key}] |
    group_by(.name) |
    map({key: .[0].name, value: .}) |
    from_entries
) as $standard |
# Variables of the datasets by variable and frequency
(
    [
        $datasets[] |
        .time_frequency[0] as $frequency |
        . as $dataset |
        [.variable, .variable_units, .cf_standard_name, .variable_long_name] as [$variables, $units, $names, $long_names] |
        range($variables | length) as $i |
        ($names[$i]? // null) as $name |
        {
            variable: $variables[$i],
            frequency: $frequency,
            units: ($units[$i]? // null),
            standard_name: $name,
            alias_of: ($dataset | standard_name_alias($issues; $variables[$i]; $name)),
            # units known to be wrong, or of a variable of the model
            fixed_units: ($dataset | units_error($issues; $variables[$i])),
            model_variable: (($dataset | model_variable($issues; $variables[$i])) != null),
            model: "\($dataset.institute[0])/\($dataset.rcm_name[0])",
            long_name: ($long_names[$i]? // null)
        }
    ] |
    group_by([.variable, .frequency]) |
    map({
        key: variable_key(.[0].variable; .[0].frequency),
        value: {
            variable: .[0].variable,
            frequency: .[0].frequency,
            datasets: length,
            units: [.[].units],
            records: [.[] | {units, fixed_units, model_variable, model}],
            standard_names: [.[].standard_name],
            # the standard names, with the known aliases replaced
            cf_standard_names: [.[] | .alias_of // .standard_name],
            aliased: ([.[] | select(.alias_of)] | length),
            long_names: [.[].long_name | values]
        }
    }) |
    from_entries
) as $found |
(
    (
        [$found[] | {variable, frequency}] +
        [$excluded | keys[] | split(" ") | {variable: .[0], frequency: .[1]}] +
        [$standard | to_entries[] | .key as $variable | .value[] | {variable: $variable, frequency}]
    ) |
    unique |
    map(
        . as {$variable, $frequency} |
        ($found[variable_key($variable; $frequency)] // {datasets: 0, units: [], records: [], standard_names: [], cf_standard_names: [], aliased: 0, long_names: []}) as $f |
        ($standard[$variable] // []) as $entries |
        ([$entries[] | select(.frequency == $frequency)][0] // $entries[0]) as $entry |
        ({variable: $variable, frequency: $frequency, tables: (frequency_tables[$frequency] // [])} | cmip5_variable_spec($entries_by_name)) as $cmor |
        $variable_iris[variable_key($variable; $frequency)] as $iri |
        # standard names
        ([$entry.standard_name, $cmor.quantity | values] | unique) as $names |
        ([$f.cf_standard_names[] | select(. as $name | $names | index($name) | not)]) as $other_names |
        # units
        ($entry.units // $cmor.units) as $definition_units |
        ($definition_units | canonical_units) as $canonical |
        [$f.records[] | select(.model_variable | not) | select((.fixed_units // .units | canonical_units) != $canonical)] as $other_records |
        ([$other_records[].units]) as $other_units |
        ([$f.records[] | select(.model_variable or .fixed_units != null)] | length) as $known_units_issues |
        {
            variable: $variable,
            frequency: $frequency,
            datasets: $f.datasets,
            excluded: ($excluded[variable_key($variable; $frequency)] // 0),
            requested: (
                if any($entries[]; .frequency == $frequency) then "yes"
                elif $entries != [] then "other_frequency"
                else "no"
                end
            ),
            requested_frequencies: ([$entries[].frequency] | join(" ")),
            standard_name: $entry.standard_name,
            cmor_standard_name: $cmor.quantity,
            standard_names: ($f.standard_names | map(. // "") | _counts),
            standard_name_status: (
                if $f.datasets == 0 or $names == [] then null
                elif ($names | length) > 1 then "definitions_differ"
                elif $other_names == [] then (if $f.aliased > 0 then "known_alias" else "match" end)
                elif ($other_names | length) * 2 < $f.datasets then "minority_other"
                else "majority_other"
                end
            ),
            standard_units: $entry.units,
            cmor_units: $cmor.units,
            units: ($f.units | map(. // "") | _counts),
            units_status: (
                if $f.datasets == 0 or $definition_units == null then null
                elif $entry.units != null and $cmor.units != null and ($entry.units | canonical_units) != ($cmor.units | canonical_units) then "definitions_differ"
                elif all($f.units[]; . == $definition_units) then "match"
                elif $other_units == [] and $known_units_issues > 0 then "known_issue"
                elif $other_units == [] then "equivalent"
                else "inconsistent"
                end
            ),
            other_units: ($other_units | map(. // "") | _counts),
            other_units_models: ($other_records | map(.model) | _counts),
            known_units_issues: $known_units_issues,
            long_name: $entry.long_name,
            long_names: ($f.long_names | unique | join("; ")),
            variable_iri: $iri,
            in_kg: (
                if $iri != null then
                    ($kg[$iri] // false) or
                    ($local_variables[first($variable | cordex_variable_name($level_variables[0]; $local_spec[0])) // ""] != null)
                else
                    null
                end
            )
        }
    )
) as $variables |
def _cases($status; f): [$variables[] | select(f == $status) | "\(.variable) \(.frequency)"];
{
    summary: {
        datasets: ($datasets | length),
        excluded_datasets: (
            [$issues.excluded_datasets[] | . as $rule | {match, datasets: ([$all_datasets[] | select(matches($rule.match))] | length)}]
        ),
        variables_found: ([$variables[] | select(.datasets > 0) | .variable] | unique | length),
        variables_requested: ($standard | length),
        variables_defined_locally: ($local_variables | keys),
        by_requested: (
            [$variables[] | select(.datasets > 0)] |
            group_by(.requested) |
            map({
                key: .[0].requested,
                value: {
                    variables: ([.[].variable] | unique | length),
                    variable_frequencies: length,
                    datasets: (map(.datasets) | add)
                }
            }) |
            from_entries
        ),
        requested_not_found: (
            [$variables[] | select(.requested == "yes" and .datasets == 0) | "\(.variable) \(.frequency)"]
        ),
        not_requested: ([$variables[] | select(.datasets > 0 and .requested == "no") | .variable] | unique),
        not_in_kg: ([$variables[] | select(.datasets > 0 and .in_kg == false) | .variable] | unique),
        requested_not_in_kg: ([$variables[] | select(.datasets > 0 and .in_kg == false and .requested != "no") | .variable] | unique),
        # for further analysis (the cases of minority_other and equivalent are ignored)
        standard_name_status: ([$variables[] | .standard_name_status | values] | group_by(.) | map({key: .[0], value: length}) | from_entries),
        standard_name_majority_other: (
            [$variables[] | select(.standard_name_status == "majority_other") | "\(.variable) \(.frequency): \(.standard_names) (definition: \([.standard_name, .cmor_standard_name | values] | unique | join(", ")))"]
        ),
        standard_name_known_aliases: (
            [$variables[] | select(.standard_name_status == "known_alias") | "\(.variable) \(.frequency): \(.standard_names) (definition: \([.standard_name, .cmor_standard_name | values] | unique | join(", ")))"]
        ),
        standard_name_definitions_differ: (
            [$variables[] | select(.standard_name_status == "definitions_differ") | "\(.variable) \(.frequency): \(.standard_name) (CORDEX), \(.cmor_standard_name) (CMOR tables); datasets: \(.standard_names)"]
        ),
        units_status: ([$variables[] | .units_status | values] | group_by(.) | map({key: .[0], value: length}) | from_entries),
        units_inconsistent: (
            [$variables[] | select(.units_status == "inconsistent") | "\(.variable) \(.frequency): \(.other_units) (definition: \(.standard_units // .cmor_units)) in \(.other_units_models)"]
        ),
        units_known_issues: (
            [$variables[] | select(.units_status == "known_issue") | "\(.variable) \(.frequency): \(.units) (definition: \(.standard_units // .cmor_units))"]
        ),
        units_definitions_differ: (
            [$variables[] | select(.units_status == "definitions_differ") | "\(.variable) \(.frequency): \(.standard_units) (CORDEX), \(.cmor_units) (CMOR tables); datasets: \(.units)"]
        )
    },
    variables: $variables
}
