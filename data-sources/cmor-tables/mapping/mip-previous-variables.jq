# Mapping to JSON-LD of the previous variables of an edition of the CMOR tables,
# i.e. the variables kept separate from the MIP variables by the
# keep/sign_change/unit_change entries of mip-mapping.json for that edition
# (see mip-mapping.md).
#
# Each variable is mapped as in variables.jq, except that:
# - its IRI is the one of a previous variable (see mip-variables.jq), e.g.
#   https://w3id.org/hacid/data/cs/variables/mip/cmip6/6.0.19/tos;
# - its label names the era and version, e.g. "Sea Surface Temperature (tos, CMIP6 6.0.19)";
# - its quantity is the new_quantity of the entry, if any;
# - for a sign_change or unit_change entry, it is related to the variables that
#   follow it (the resolution of the variable after the entry, usually the
#   current variable with the same name) by data:hasOppositeValueOf or
#   data:isLinearTransformationOf (data ontology).
#
# Input: the array of the tables of the edition (see variables-jsonld.jq).
# Arguments: --arg era <era> --arg version <version> (the edition, as in
# config/config.yaml) --slurpfile eras config/cmor-tables-eras.json
#
#   jq -L data-sources/cmor-tables/mapping --arg era cmip6 --arg version 6.0.19 \
#       --slurpfile eras config/cmor-tables-eras.json \
#       -f data-sources/cmor-tables/mapping/mip-previous-variables.jq data-sources/cmor-tables/data/cmip6/6.0.19.json

include "./variables-jsonld";
include "./mip-variables";

(
    first($eras[0].eras[] | select(.era == $era)) //
    error("era not in the eras: \($era)")
) as $era |
(
    [mip_mapping[] | select(.era == $era.era) | mip_section_entries] |
    # entries of the edition (in an era without versions, of its edition)
    map(select(if .version == null then $version == $era.version else .version == $version end))
) as $entries |
[
    variable_entries[] |
    (
        {out_name, era: $era.era, table, dimensions, quantity: .standard_name, units} |
        _variable_spec
    ) as $variable |
    first($entries[] | select(.entry.id == $variable.id and (.entry | _applies_to($variable)))) as $match |
    . + {
        iri: ({era: $era.era, version: $match.version, id: .out_name} | mip_variable_resolution_iri),
        era_version: ([($era.era | ascii_upcase), $match.version | values] | join(" ")),
        relation: (
            {sign_change: "data:hasOppositeValueOf", unit_change: "data:isLinearTransformationOf"}[$match.kind] //
            null
        ),
        follower: (
            $variable | {out_name: .id, era, table, dimensions} |
            mip_variable_resolution(mip_mapping; {era: $era.era, version: $match.version}) |
            mip_variable_resolution_iri
        )
    } |
    if $match.entry.new_quantity != null then .standard_name = $match.entry.new_quantity end
] |
# relations to the following variables, by IRI (a variable in several tables
# may be followed by different variables, e.g. a time series and a climatology)
(
    map(select(.relation != null)) | group_by(.iri) |
    map({key: .[0].iri, value: {(.[0].relation): (map(.follower) | unique | map({"@id": .}))}}) |
    from_entries
) as $relations |
variables_jsonld(.iri; "\(.long_name) (\(.out_name), \(.era_version))") |
.["@graph"] |= map(. + ($relations[.["@id"]] // {}))
