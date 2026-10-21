# UKCP18 datasets whose variable is not a variable of the KG (neither a MIP
# variable nor a previous variable, see data-sources/cmor-tables/mapping, nor a
# UKCP18 variable linked to MIP variables of the KG), to review their mapping
# (mapping/ukcp18-variables.jq, mapping/ukcp-variables.json).
#
# Input (read with -n): the metadata of the UKCP18 datasets, a JSON value for
# each (data/ceda_ukcp18_metadata.jsonl), checked one at a time.
# Arguments: --slurpfile kg_variables <IRIs of the variables of the KG (array)>,
# --slurpfile mip_index <data/mip-mapping-index.json>; the modules of mapping
# and of data-sources/cmor-tables/mapping must be in the library path (-L), run
# from data-sources/ukcp18.
# Output: the metadata of those datasets (the ones mapped, i.e. not in the
# marine-sim collection), with the fixes of the mapping, as an array.

import "./mapping/ukcp18-variables" as VARIABLES;
import "./mapping/ukcp18-ids" as IDS;

($kg_variables[0] | map({key: ., value: true}) | from_entries) as $known |
$mip_index[0] as $mip_index |
VARIABLES::local_variables_by_iri as $by_iri |
[
    inputs |
    select(.collection != "marine-sim") |
    IDS::fix_variable |
    IDS::fix_units |
    # the variable, if not a UKCP18 one, or the variables the UKCP18 ones are
    # linked to must be variables of the KG
    select(
        [
            VARIABLES::variable_iri($mip_index),
            (
                VARIABLES::local_variables($by_iri) |
                .anomaly_of, .derived_from[]?, .linear_transformation_of,
                .local_version_of, .probabilistic_representation_of
            ) |
            strings |
            select(startswith("https://w3id.org/hacid/data/cs/variables/ukcp/") | not)
        ] |
        all(.[]; $known[.]) |
        not
    )
]
