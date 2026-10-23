# Mapping of the CORDEX-CMIP5 datasets (ESGF search results) to JSON-LD.
#
# Input: a page of the response of an ESGF search of CORDEX datasets
# (data/cordex-<n>.json, {"response": {"docs": [...]}}), read with -n (also
# more pages): the workflow maps each page on its own, to a JSON-LD document
# (rdf/datasets/cordex-<n>.jsonld). The mapping of a dataset depends only on
# its metadata and on the configuration.
#
# Port of clean-data.jq and of the RML mapping rml/cordex.ttl (with its
# functions in ws-data-rml.py). The driving models are normalised to the CMIP5
# model names (--slurpfile model_synonyms mapping/cmip5-model-synonyms.json),
# also in the dataset ids. For each dataset, from its metadata (the facets
# product, domain, institute, driving_model, experiment, ensemble, rcm_name,
# rcm_version, time_frequency, variable, see cordex_dataset_jsonld in
# cordex-datasets.jq):
# - the dataset, the output of its simulation (all the datasets of the same
#   domain, driving model, experiment, regional model and version, ensemble
#   member and product), the outputs of the driving ensemble, of the ensemble,
#   of the experiment, of the domain and of CORDEX-CMIP5;
# - the simulation, a downscaling of the CMIP5 simulation of the driving model,
#   the driving ensemble (the simulations of the same domain, driving model,
#   experiment and regional model), the ensemble (of the same domain,
#   experiment and regional model), the experiment, the domain and the
#   regional model, with its institute;
# - the variables of the dataset, its spatial grid (the CORDEX grid of the
#   domain, see data-sources/cordex-domains) and its temporal grid (the time
#   interval of the dataset rounded to the time frequency).
# The nodes of the simulations and models are given by functions of
# cordex-datasets.jq, also used by the mappings of the sources referring to the
# CORDEX-CMIP5 simulations.
#
# The IRIs of the variables are those of the MIP variables (see
# data-sources/cmor-tables/mapping/mip-mapping.md), resolved from the
# definitions of the variables in the CMIP5 CMOR tables (see cmip5_variable_iri
# in data-sources/cmip5/mapping/esgf.jq), in the tables of the time frequency
# of the dataset (see cordex-variables.jq).
#
# The variables not in the KG that CORDEX requests (CORDEX_standard_output.json)
# and the variables at a single level not in the KG (mapping/level-variables.json)
# are defined locally (see variables.jq and local_variables in
# cordex-variables.jq), https://w3id.org/hacid/data/cs/variables/cordex/<name>;
# the bases of the single level variables that are aliases (e.g. u200, of
# ua200) are resolved. The other variables not in the CMOR tables are skipped,
# renamed or defined locally as given by mapping/local-variables.json (see
# cordex_variable_name and local_variables in cordex-variables.jq).
#
# Arguments: --slurpfile cmor_tables <tables of the CMIP5 CMOR tables>
# (data-sources/cmor-tables/data/cmip5/5.0.json), --slurpfile model_synonyms
# mapping/cmip5-model-synonyms.json, --slurpfile standard_output
# CORDEX_standard_output.json, --slurpfile level_variables
# mapping/level-variables.json, --slurpfile local_spec
# mapping/local-variables.json, --slurpfile kg_variables
# data-sources/cmor-tables/data/variable-iris.json, --slurpfile mip_index
# data-sources/cmor-tables/data/mip-mapping-index.json, --slurpfile data_issues
# mapping/data-issues.json (the known issues of the datasets, see
# ../DECISIONS.md); the modules of this directory, of
# data-sources/cmip5/mapping (esgf.jq, cmip5-datasets.jq) and of
# data-sources/cmor-tables/mapping must be in the library path (-L).

include "esgf";
include "cordex-variables";
include "cordex-datasets";

# --- Driving models (clean-data.jq)

# Institutions, to tell the institution of a driving model (the first one, the
# longest, prefixing its name)
def _institutions:
    [
        "AER", "AS-RCEC", "AWI", "BCC", "BOM", "CAMS", "CAS", "CCCR-IITM", "CCCma",
        "CMCC", "CNRM-CERFACS", "CSIRO", "CSIRO-ARCCSS", "CSIRO-BOM", "CNRM-CERFACS",
        "CSIRO-COSIMA", "CSIRO-QCCCE", "QCCCE", "DKRZ", "DWD", "E3SM-Project",
        "EC-EARTH", "EC-Earth-Consortium", "ECMWF", "FIO", "FIO-QLNM", "GCESS",
        "HAMMOZ-Consortium", "ICHEC", "INM", "IPSL", "KIOST", "LASG-IAP", "LLNL",
        "MESSy-Consortium", "MIROC", "MOHC", "MPI-M", "MRI", "NASA-GISS",
        "NASA-GMAO", "NASA-GSFC", "NCAR", "NCC", "NCEP", "NERC", "NIMS-KMA", "NIWA",
        "NMR-KMA", "NOAA-GFDL", "NTU", "NUIST", "PCMDI", "PNNL-WACCEM", "RSMAS",
        "RTE-RRTMGP-Consortium", "RUBISCO", "SNU", "THU", "UA", "UCI", "UCSB", "UHH"
    ] |
    sort_by(length) | reverse;

# The CMIP5 name of a driving model (input: as in the ESGF results, often
# prefixed by its institution, e.g. MOHC-HadGEM2-ES)
def _model_id: $model_synonyms[0][.] // .;

def _institution_id:
    . as $model |
    [_institutions[] | select(. as $institution | $model | startswith($institution))] |
    .[0] // "";

# A dataset id with the driving models replaced by their CMIP5 names
def _fix_id($driving_models):
    split(".") | .[4] = ($driving_models | join(";")) | join(".");

def _clean:
    [.driving_model[] | _model_id] as $driving_models |
    .driving_model_institution = [.driving_model[] | _institution_id] |
    .driving_model = $driving_models |
    .master_id |= _fix_id($driving_models);

# --- Mapping

# (with the variables of the ids for the datasets of variables_from_id, without
# the datasets excluded, see mapping/data-issues.json)
[inputs | .response.docs[] | fix_variables($data_issues[0]) | select(excluded($data_issues[0]) | not) | _clean] as $datasets |
($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
($kg_variables[0] | iri_set) as $kg |
$mip_index[0] as $mip_index |
# the variables defined locally and the IRIs of the variables of the CMIP5
# tables, from the configuration
local_variables($standard_output[0]; $level_variables[0]; $local_spec[0]; $entries_by_name; $kg) as $local_variables |
cordex_variable_index($entries_by_name; $mip_index) as $variable_index |
[
    $datasets[] |
    .time_frequency[0] as $frequency |
    # (the variables of a model with their own units, model_variables in
    # mapping/data-issues.json, are those of the model)
    . as $record |
    [
        .variable[] |
        . as $variable |
        (($record | model_variable($data_issues[0]; $variable)) | if . then model_variable_iri else null end) //
        (
            $variable | cordex_variable_name($level_variables[0]; $local_spec[0]) |
            variable_iri_of(.; $frequency; $variable_index; $entries_by_name; $mip_index; $local_variables; $kg)
        )
    ] as $variables |
    cordex_dataset_jsonld($variables)
] |
# each node once
unique |
{
    "@context": esgf_context,
    "@graph": .
}
