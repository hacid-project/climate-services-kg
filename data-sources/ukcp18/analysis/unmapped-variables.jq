# UKCP18 datasets whose variable is not a variable of the KG (neither a MIP
# variable nor a previous variable, see data-sources/cmor-tables/mapping, nor a
# UKCP18 variable linked to MIP variables of the KG), to review their mapping
# (mapping/ukcp18-variables.jq).
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
map(select(.collection != "marine-sim") | IDS::fix_variable) |
VARIABLES::with_variable_iris |
map(
    select(
        (VARIABLES::ukcp_variable // null) as $ukcp |
        if $ukcp != null then
            [$ukcp.anomaly_of // empty, $ukcp.derived_from[]?] | any(.[]; $known[.] | not)
        else
            $known[.variable_iri] | not
        end
    ) |
    del(.variable_iri)
)
