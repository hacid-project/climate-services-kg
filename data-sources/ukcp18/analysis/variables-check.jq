# Check of the local variables of the UKCP18 datasets (mapping/ukcp-variables.json)
# against the datasets, to keep the file up to date:
# - datasets: the number of datasets of each local variable (as variable of the
#   datasets or as a variable it is a representation of or derived from);
# - unused: the local variables of no dataset;
# - other_units: the variables of the datasets without a local variable, whose
#   units are not those of their MIP variable (a local variable may be needed),
#   with the number of datasets.
#
# Input: the metadata of the UKCP18 datasets (data/ceda_ukcp18_metadata_merged.json).
# Arguments: --slurpfile mip_units <units of the variables of the KG, by IRI>;
# the modules of mapping and of data-sources/cmor-tables/mapping must be in the
# library path (-L), run from data-sources/ukcp18.

import "./mapping/ukcp18-variables" as VARIABLES;
import "./mapping/ukcp18-ids" as IDS;

$mip_units[0] as $mip_units |
map(select(.collection != "marine-sim") | IDS::fix_variable) |
IDS::fix_units |
[
    group_by(VARIABLES::variable_key)[] |
    {count: length} + (.[0] | {
        variable, units, collection,
        local: [VARIABLES::local_variables | .iri],
        iri: VARIABLES::variable_iri
    })
] as $keys |
([VARIABLES::ukcp_variable_nodes[] | select(."@type" | index("data:DeterministicVariable")?) | ."@id"]) as $local |
(
    [$keys[] | .count as $count | .local[] | {iri: ., count: $count}] |
    group_by(.iri) | map({key: .[0].iri, value: (map(.count) | add)}) | from_entries
) as $datasets |
{
    datasets: $datasets,
    unused: [$local[] | select($datasets[.] == null)],
    other_units: [
        $keys[] |
        select(.local == [] and .units != null and $mip_units[.iri] != null and $mip_units[.iri] != .units) |
        {variable, units, mip_units: $mip_units[.iri], iri, collection, count}
    ]
}
