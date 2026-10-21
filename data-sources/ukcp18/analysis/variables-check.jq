# Check of the local variables of the UKCP18 datasets (mapping/ukcp-variables.json)
# against the datasets, to keep the file up to date:
# - datasets: the number of datasets of each local variable (as variable of the
#   datasets or as a variable it is a representation of or derived from);
# - unused: the local variables of no dataset;
# - other_units: the variables of the datasets without a local variable, whose
#   units are not those of their MIP variable (a local variable may be needed),
#   with the number of datasets.
#
# Input (read with -n): the metadata of the UKCP18 datasets, a JSON value for
# each (data/ceda_ukcp18_metadata.jsonl), counted by key (variable_key) one at a
# time.
# Arguments: --slurpfile mip_units <units of the variables of the KG, by IRI>,
# --slurpfile mip_index <data/mip-mapping-index.json>;
# the modules of mapping and of data-sources/cmor-tables/mapping must be in the
# library path (-L), run from data-sources/ukcp18.

import "./mapping/ukcp18-variables" as VARIABLES;
import "./mapping/ukcp18-ids" as IDS;

$mip_units[0] as $mip_units |
$mip_index[0] as $mip_index |
VARIABLES::local_variables_by_iri as $by_iri |
# the number of datasets of each key, with the first dataset of the key
reduce (
    inputs | select(.collection != "marine-sim") | IDS::fix_variable | IDS::fix_units
) as $dataset (
    {};
    ($dataset | VARIABLES::variable_key) as $key |
    if has($key) then .[$key].count += 1 else .[$key] = {count: 1, dataset: $dataset} end
) |
[
    .[] |
    {count} + (.dataset | {
        variable, units, collection,
        local: [VARIABLES::local_variables($by_iri) | .iri],
        iri: VARIABLES::variable_iri($mip_index)
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
