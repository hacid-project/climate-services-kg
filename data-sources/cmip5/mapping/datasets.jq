# Mapping of the CMIP5 datasets (ESGF search results) to JSON-LD.
#
# Input: the response of an ESGF search of CMIP5 datasets (data/cmip5.json, see
# query.txt), {"response": {"docs": [...]}}.
#
# Port of the RML mapping rml/cmip5.ttl and of its functions in ws-data-rml.py.
# For each dataset, from its metadata (the facets product, institute, model,
# experiment, time_frequency, cmor_table, ensemble, see cmip5_dataset_jsonld in
# cmip5-datasets.jq), with the model id of the model (cmip5_model_id):
# - the dataset, its simulation output (all the datasets of the same model,
#   experiment, ensemble member and product), the outputs of the ensemble and of
#   the experiment, and the output of CMIP5;
# - the simulation, the ensemble, the experiment and the model, with its
#   institute;
# - the variables of the dataset, its spatial grid and its temporal grid (the
#   time interval of the dataset rounded to the time frequency).
# The nodes of the simulations and models are given by functions of
# cmip5-datasets.jq, also used by the mappings of the sources referring to the
# CMIP5 simulations.
#
# The IRIs of the variables are those of the MIP variables (see
# data-sources/cmor-tables/mapping/mip-mapping.md), resolved from the
# definitions of the variables in the CMIP5 CMOR tables (see
# cmip5_variable_spec in esgf.jq), for each dataset with the index of the
# mapping of the MIP variables.
#
# The variables not in the CMOR tables are skipped, renamed or defined locally
# for their model as given by mapping/variables.json (see
# cmip5_dataset_variable_iri in esgf.jq and variables.jq).
#
# Arguments: --slurpfile cmor_tables <tables of the CMIP5 CMOR tables>
# (data-sources/cmor-tables/data/cmip5/5.0.json), --slurpfile model_variables
# mapping/variables.json, --slurpfile mip_index
# <index of the mapping of the MIP variables>
# (data-sources/cmor-tables/data/mip-mapping-index.json); the modules of
# data-sources/cmor-tables/mapping and of this directory (esgf.jq,
# cmip5-datasets.jq) must be in the library path (-L).

include "variables-jsonld";
include "mip-variables";
include "esgf";
include "cmip5-datasets";

# --- Mapping

($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
$mip_index[0] as $mip_index |
# the IRIs of the variables of the CMIP5 tables, from the configuration
cmip5_variable_index($entries_by_name; $mip_index) as $variable_index |
[
    .response.docs[] |
    .cmor_table[0] as $table |
    .time_frequency[0] as $frequency |
    .model[0] as $model |
    [
        .variable[]? |
        cmip5_dataset_variable_iri(
            $model_variables[0]; $model;
            {table: $table, variable: ., frequency: $frequency} |
            cmip5_variable_iri_indexed($variable_index; $entries_by_name; $mip_index)
        )
    ] as $variables |
    cmip5_dataset_jsonld($variables)
] |
# each node once
unique |
{
    "@context": esgf_context,
    "@graph": .
}
