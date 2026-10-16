# Check of the variables of the CORDEX-CMIP5 datasets against the CORDEX
# standard output (the variables requested for the CORDEX archive,
# CORDEX_standard_output.xls converted to JSON tables by the rule
# cordex_cmip5_standard_output).
#
# Input: the pages of the ESGF search results (data/cordex-<n>.json), read
# with -n. Arguments: --slurpfile standard_output
# CORDEX_standard_output.json, --slurpfile cmor_tables (the CMIP5
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
# - standard_units, standard_name, long_name: those of the standard output
#   (at the frequency, or else at any frequency), and units and standard_names
#   (and long_names) found in the datasets, with units_match and
#   standard_name_match;
# - mip_variable: the IRI resolved by the mapping, and in_kg, whether it is a
#   variable of the KG.

include "esgf";
include "cordex-variables";

def _join: if . == null then null else unique | join("; ") end;

[inputs | .response.docs[]] as $datasets |
($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
($datasets | variable_iris($entries_by_name)) as $variable_iris |
($kg_variables[0] | map({key: ., value: true}) | from_entries) as $kg |
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
        [.variable, .variable_units, .cf_standard_name, .variable_long_name] as [$variables, $units, $names, $long_names] |
        range($variables | length) as $i |
        {
            variable: $variables[$i],
            frequency: $frequency,
            units: ($units[$i]? // null),
            standard_name: ($names[$i]? // null),
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
            units: [.[].units | values],
            standard_names: [.[].standard_name | values],
            long_names: [.[].long_name | values]
        }
    }) |
    from_entries
) as $found |
(
    (
        [$found[] | {variable, frequency}] +
        [$standard | to_entries[] | .key as $variable | .value[] | {variable: $variable, frequency}]
    ) |
    unique |
    map(
        . as {$variable, $frequency} |
        ($found[variable_key($variable; $frequency)] // {datasets: 0}) as $f |
        ($standard[$variable] // []) as $entries |
        ([$entries[] | select(.frequency == $frequency)][0] // $entries[0]) as $entry |
        $variable_iris[variable_key($variable; $frequency)] as $iri |
        {
            variable: $variable,
            frequency: $frequency,
            datasets: $f.datasets,
            requested: (
                if any($entries[]; .frequency == $frequency) then "yes"
                elif $entries != [] then "other_frequency"
                else "no"
                end
            ),
            requested_frequencies: ([$entries[].frequency] | join(" ")),
            standard_units: $entry.units,
            units: ($f.units | _join),
            units_match: (if $entry and $f.units != null then $f.units | unique == [$entry.units] else null end),
            standard_name: $entry.standard_name,
            standard_names: ($f.standard_names | _join),
            standard_name_match: (if $entry and $f.standard_names != null then $f.standard_names | unique == [$entry.standard_name] else null end),
            long_name: $entry.long_name,
            long_names: ($f.long_names | _join),
            mip_variable: $iri,
            in_kg: (if $iri != null then $kg[$iri] // false else null end)
        }
    )
) as $variables |
{
    summary: {
        datasets: ($datasets | length),
        variables_found: ([$variables[] | select(.datasets > 0) | .variable] | unique | length),
        variables_requested: ($standard | length),
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
        units_mismatch: ([$variables[] | select(.units_match == false) | "\(.variable) \(.frequency): \(.units) (\(.standard_units))"]),
        standard_name_mismatch: ([$variables[] | select(.standard_name_match == false) | "\(.variable) \(.frequency): \(.standard_names) (\(.standard_name))"])
    },
    variables: $variables
}
