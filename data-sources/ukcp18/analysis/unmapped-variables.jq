# UKCP18 datasets whose variable is not a variable of the KG (neither a MIP
# variable nor a previous variable, see data-sources/cmor-tables/mapping, nor a
# UKCP18 variable linked to MIP variables of the KG), to review their mapping
# (mapping/ukcp18-variables.jq, mapping/ukcp-variables.json).
#
# Input: the metadata of the UKCP18 datasets (data/ceda_ukcp18_metadata_merged.json).
# Arguments: --slurpfile kg_variables <IRIs of the variables of the KG (array)>;
# the modules of mapping and of data-sources/cmor-tables/mapping must be in the
# library path (-L), run from data-sources/ukcp18.
# Output: the metadata of those datasets (the ones mapped, i.e. not in the
# marine-sim collection), as in the input.

import "./mapping/ukcp18-variables" as VARIABLES;
import "./mapping/ukcp18-ids" as IDS;

($kg_variables[0] | map({key: ., value: true}) | from_entries) as $known |
map(select(.collection != "marine-sim") | IDS::fix_variable | IDS::fix_units) |
# whether the variables of the datasets are mapped, once for each key
# (VARIABLES::variable_key): the variable, if not a UKCP18 one, or the variables
# the UKCP18 ones are linked to must be variables of the KG
(
    unique_by(VARIABLES::variable_key) |
    map({
        key: VARIABLES::variable_key,
        value: (
            [
                VARIABLES::variable_iri,
                (
                    VARIABLES::local_variables |
                    .anomaly_of, .derived_from[]?, .linear_transformation_of,
                    .local_version_of, .probabilistic_representation_of
                ) |
                strings |
                select(startswith("https://w3id.org/hacid/data/cs/variables/ukcp/") | not)
            ] |
            all(.[]; $known[.])
        )
    }) |
    from_entries
) as $mapped |
map(select($mapped[VARIABLES::variable_key] | not))
