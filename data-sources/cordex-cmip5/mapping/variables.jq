# Mapping to JSON-LD of the variables of the CORDEX-CMIP5 datasets defined
# locally: the variables requested by CORDEX (the CORDEX standard output,
# CORDEX_standard_output.json, in the format of the CMOR tables), the
# variables at a single level (mapping/level-variables.json) and the other
# variables not in the CMOR tables (mapping/local-variables.json, derived from
# the MIP variable of derived_from, data:derivedFromVariable, if any) that are
# not variables of the KG (see local_variables in cordex-variables.jq), mapped as
# the variables of the CMOR tables (variables_jsonld in
# data-sources/cmor-tables/mapping/variables-jsonld.jq), as
# https://w3id.org/hacid/data/cs/variables/cordex/<out_name>, members of the
# collection https://w3id.org/hacid/data/cs/variables/cordex.
#
# The long names of the variables of the standard output at a single pressure
# level, <base><level> (e.g. ta200), are derived from the analogous MIP variables, of the same base
# at a single pressure level (e.g. ta500, on the dimension p500): the quantity
# of their long names (without a level, e.g. "Air Temperature") at the level,
# as in the CMOR tables (e.g. "Air Temperature at 200hPa").
#
# Input: the tables of the editions of the MIP variables of the KG (current
# and previous, data-sources/cmor-tables/data/<era>/<version>.json).
#
# Also the variables of a model with their own units (model_variables in
# mapping/data-issues.json), variables/cordex/<model>/<variable>/<units>,
# related to the MIP variable (or to the variable defined locally, e.g. hur200)
# as given by their relation (data:isLinearTransformationOf,
# data:derivedFromVariable, or none).
#
# Arguments (run with -n): --slurpfile data_issues mapping/data-issues.json,
# --slurpfile standard_output
# CORDEX_standard_output.json, --slurpfile level_variables
# mapping/level-variables.json, --slurpfile local_spec
# mapping/local-variables.json, --slurpfile cmor_tables (the CMIP5 CMOR tables,
# as for datasets.jq), --slurpfile kg_variables
# data-sources/cmor-tables/data/variable-iris.json, --slurpfile cf_names
# data-sources/cf-standard-names/data/standard-names.json, --slurpfile cf_fixes
# data-sources/cmor-tables/mapping/cf-standard-name-fixes.json; the modules of this
# directory, of data-sources/cmip5/mapping and of
# data-sources/cmor-tables/mapping must be in the library path (-L).

include "variables-jsonld";
include "esgf";
include "cordex-variables";

# Quantity names (long names without the level) of the MIP variables at a
# single pressure level by base, the most common one
def _single_level_quantities:
    [
        .[] | variable_entries[] |
        (.out_name | capture("^(?<base>[A-Za-z]+)(?<level>[0-9]+)$")) as $name |
        select([.dimensions | words] | index("p\($name.level)")) |
        {base: $name.base, quantity: (.long_name | present | sub(" at ?[0-9]+ ?hPa$"; ""))}
    ] |
    group_by(.base) |
    map({key: .[0].base, value: (map(.quantity) | group_by(.) | max_by(length) | .[0])}) |
    from_entries;

([inputs] | _single_level_quantities) as $quantities |
($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
($kg_variables[0] | iri_set) as $kg |
[
    local_variables($standard_output[0]; $level_variables[0]; $local_spec[0]; $entries_by_name; $kg) | to_entries[] |
    .value + {out_name: .key} |
    ((.out_name | capture("^(?<base>[A-Za-z]+)(?<level>[0-9]+)$")) // null) as $name |
    if $name != null and $quantities[$name.base] != null and (.specified | not) then
        .long_name = "\($quantities[$name.base]) at \($name.level)hPa"
    end |
    del(.specified)
] as $variables |
($variables | map({key: .out_name, value: true}) | from_entries) as $local_names |
# the MIP variables the variables are derived from (derived_from), by IRI
(
    [
        $variables[] | select(.derived_from != null) |
        {key: (.out_name | cordex_variable_iri), value: {"data:derivedFromVariable": {"@id": mip_variable_iri_of(.derived_from; ""; $entries_by_name)}}}
    ] |
    from_entries
) as $derivations |
$variables |
variables_jsonld(
    .out_name | cordex_variable_iri;
    "\(.long_name) (\(.out_name))";
    cordex_variables_collection;
    cf_standard_names($cf_names[0]; $cf_fixes[0])
) |
.["@graph"] |= map(. + ($derivations[.["@id"]] // {})) |
# The variables of a model with their own units (model_variables in
# mapping/data-issues.json), derived from the MIP variable, members of the
# collection of the variables of the model, associated with the model
.["@graph"] += [
    $data_issues[0].model_variables[]? |
    . as $rule |
    (.units | @uri "https://w3id.org/hacid/data/cs/unitsofmeasure/\(.)") as $unit |
    {
        "@id": model_variable_iri,
        "@type": "data:DeterministicVariable",
        isMemberOf: [cordex_variables_collection, model_variables_collection(.model)],
        label: "\(.long_name) (\(.variable), \(.units), \(.model))",
        acronym: .variable,
        # relation to the MIP variable
        (
            {linear_transformation: "data:isLinearTransformationOf", derived: "data:derivedFromVariable"}[.relation // ""] //
            "data:relatedTo"
        ): (
            if .relation then
                {"@id": (if $local_names[$rule.variable] then $rule.variable | cordex_variable_iri else mip_variable_iri_of($rule.variable; ""; $entries_by_name) end)}
            else null end
        ),
        hasUnitOfMeasure: $unit,
        hasValuesOn: $unit
    },
    {
        "@id": model_variables_collection(.model),
        "@type": "top:Collection",
        "rdfs:label": {"@value": "\(.model) variables", "@language": "en"},
        "rdfs:comment": {"@value": "Collection of the variables of the CORDEX-CMIP5 datasets of the model \(.model) used differently from the CORDEX standard (e.g. with other units).", "@language": "en"},
        "top:associatedWith": {"@id": ("https://w3id.org/hacid/data/cs/models/" + (.model | @uri))}
    },
    {
        "@id": $unit,
        "@type": ["top:UnitOfMeasure", "data:DimensionalSpace"],
        "rdfs:label": .units
    }
] |
.["@graph"] |= (map(with_entries(select(.value != null))) | unique)
