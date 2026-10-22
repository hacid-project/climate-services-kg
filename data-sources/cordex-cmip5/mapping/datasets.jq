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
# also in the dataset ids. For each dataset (master_id cordex.<product>.
# <domain>.<institute>.<driving_model>.<experiment>.<ensemble>.<rcm_name>.
# <rcm_version>.<time_frequency>.<variable>):
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
#   domain, see data-sources/cordex-domains) and its temporal grid (the time interval of the dataset rounded to
#   the time frequency).
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
# data-sources/cmip5/mapping (esgf.jq) and of data-sources/cmor-tables/mapping
# must be in the library path (-L).

include "esgf";
include "cordex-variables";

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

# (without the datasets excluded in mapping/data-issues.json)
[inputs | .response.docs[] | select(excluded($data_issues[0]) | not) | _clean] as $datasets |
($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
($kg_variables[0] | iri_set) as $kg |
$mip_index[0] as $mip_index |
# the variables defined locally and the IRIs of the variables of the CMIP5
# tables, from the configuration
local_variables($standard_output[0]; $level_variables[0]; $local_spec[0]; $entries_by_name; $kg) as $local_variables |
cordex_variable_index($entries_by_name; $mip_index) as $variable_index |
[
    $datasets[] |
    (.master_id | split(".")) as $parts |
    {
        product: $parts[1],
        domain: $parts[2],
        institute: $parts[3],
        driving_model: $parts[4],
        experiment: $parts[5],
        ensemble: $parts[6],
        model: $parts[7],
        model_version: $parts[8]
    } as $id |

    "cordex.\($id.product).\($id.domain).\($id.driving_model).\($id.experiment).\($id.model).\($id.model_version).\($id.ensemble)" as $output_id |
    "cordex.\($id.domain).\($id.driving_model).\($id.experiment).\($id.model).\($id.model_version).\($id.ensemble)" as $simulation_id |
    "cordex.\($id.domain).\($id.driving_model).\($id.experiment).\($id.model).\($id.model_version)" as $driving_ensemble_id |
    "cordex.\($id.product).\($id.domain).\($id.driving_model).\($id.experiment).\($id.model).\($id.model_version)" as $driving_ensemble_output_id |
    "cordex.\($id.domain).\($id.experiment).\($id.model).\($id.model_version)" as $ensemble_id |
    "cordex.\($id.domain).\($id.experiment)" as $experiment_id |
    "cordex.\($id.domain)" as $domain_id |

    (ns + "datasets/\(.master_id)") as $dataset |
    (ns + "datasets/\($output_id)") as $output |
    (ns + "simulations/\($simulation_id)") as $simulation |
    (ns + "simulations/\($driving_ensemble_id)") as $driving_ensemble |
    (ns + "datasets/\($driving_ensemble_output_id)") as $driving_ensemble_output |
    (ns + "simulations/\($ensemble_id)") as $ensemble |
    (ns + "datasets/\($ensemble_id)") as $ensemble_output |
    (ns + "simulations/\($experiment_id)") as $experiment |
    (ns + "datasets/\($experiment_id)") as $experiment_output |
    (ns + "simulations/\($domain_id)") as $domain |
    (ns + "datasets/\($domain_id)") as $domain_output |
    # (a domain id without resolution, as AUS, is not a CORDEX grid)
    (.domain[0] | if test("-") then ns + "cordex/grids/\(.)" else null end) as $grid |
    [.rcm_name[] | ns + "models/\(quote)"] as $models |
    [.institute[] | ns + "organizations/\(quote)"] as $institutes |
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
    (.experiment | scenario_iris | map(id(.))) as $refers_to_scenario |
    temporal_grid as $time |
    ($time | temporal_iris) as $time_iris |
    ($variables | map(id(.))) as $variable_ids |
    (if $grid != null then id("\($grid)/ds") else null end) as $geodetic_variable |
    (if $grid != null then id("\($grid)/specialization") else null end) as $geodetic_specialization |
    ($models | map(id(.))) as $uses_model |

    # Dataset
    {
        "@id": $dataset,
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": .master_id,
        "data:isSpecializationOfVariable": $variable_ids,
        "data:dependsOnVariable": [($geodetic_variable | values), ($time_iris.variable | values | id(.))],
        "data:isSpecializedAccordingTo": [($geodetic_specialization | values), ($time_iris.specialization | values | id(.))],
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the simulation
    {
        "@id": $output,
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ($output_id | en),
        "data:holdsSpecializationOfVariable": $variable_ids,
        "data:dependsOnVariable": $geodetic_variable,
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "top:hasComponent": id($dataset),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Simulation
    {
        "@id": $simulation,
        "@type": ["ccso:SingleSimulation", "ccso:DynamicalDownscaling"],
        "rdfs:label": ($simulation_id | en),
        "ccso:isDownscalingOf": id(ns + "simulations/cmip5.\($id.driving_model).\($id.experiment).\($id.ensemble)"),
        "data:hasOutput": id($output),
        "ccso:usesModel": $uses_model,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Driving ensemble
    {
        "@id": $driving_ensemble,
        "@type": ["ccso:EnsembleSimulation", "ccso:DynamicalDownscaling"],
        "rdfs:label": ($driving_ensemble_id | en),
        "top:hasComponent": id($simulation),
        "data:hasOutput": id($driving_ensemble_output),
        "ccso:usesModel": $uses_model,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the driving ensemble
    {
        "@id": $driving_ensemble_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ($driving_ensemble_output_id | en),
        "data:holdsSpecializationOfVariable": $variable_ids,
        "top:hasComponent": id($output),
        "data:dependsOnVariable": $geodetic_variable,
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Ensemble
    {
        "@id": $ensemble,
        "@type": ["ccso:ClimateModelIntercomparisonExperiment", "ccso:DynamicalDownscaling"],
        "rdfs:label": ($ensemble_id | en),
        "top:hasComponent": id($driving_ensemble),
        "data:hasOutput": id($ensemble_output),
        "ccso:usesModel": $uses_model,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the ensemble
    {
        "@id": $ensemble_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ($ensemble_id | en),
        "data:holdsSpecializationOfVariable": $variable_ids,
        "top:hasComponent": id($driving_ensemble_output),
        "data:dependsOnVariable": $geodetic_variable,
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Experiment
    {
        "@id": $experiment,
        "@type": ["ccso:ClimateModelIntercomparisonExperiment", "ccso:DynamicalDownscaling"],
        "rdfs:label": ($experiment_id | en),
        "top:hasComponent": id($ensemble),
        "data:hasOutput": id($experiment_output),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the experiment
    {
        "@id": $experiment_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("output of \($experiment_id)" | en),
        "data:holdsSpecializationOfVariable": $variable_ids,
        "top:hasComponent": id($ensemble_output),
        "data:dependsOnVariable": $geodetic_variable,
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Domain
    {
        "@id": $domain,
        "@type": "top:Action",
        "rdfs:label": ($domain_id | en),
        "top:hasComponent": id($experiment),
        "data:hasOutput": id($domain_output)
    },
    # Output of the domain
    {
        "@id": $domain_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("output of \($domain_id)" | en),
        "top:hasComponent": id($experiment_output),
        "data:dependsOnVariable": $geodetic_variable,
        "data:isSpecializedAccordingTo": $geodetic_specialization
    },
    # CORDEX-CMIP5 and its output
    {
        "@id": (ns + "mips/cordex-cmip5"),
        "top:hasComponent": id($domain)
    },
    {
        "@id": (ns + "mips/cordex-cmip5/output"),
        "top:hasComponent": id($domain_output)
    },
    # Regional model
    (
        [.rcm_name[] | en] as $labels |
        $models[] |
        {
            "@id": .,
            "@type": "ccso:RegionalClimateModel",
            "rdfs:label": $labels,
            "ccso:isMaintainedBy": ($institutes | map(id(.)))
        }
    ),
    # Institute
    (
        .institute as $acronyms |
        $institutes[] |
        {
            "@id": .,
            "@type": "top:Organization",
            "top:acronym": $acronyms
        }
    ),
    # Temporal grid
    (
        $time | values |
        {
            "@id": $time_iris.specialization,
            "@type": "data:VariableSpecialization",
            "data:isSpecializationOn": id(ns + "dimensions/time"),
            "data:hasSelectedRegion": id($time_iris.region)
        },
        {
            "@id": $time_iris.region,
            "@type": "data:TemporalRegion",
            "data:hasStartDateTime": (.start | typed("xsd:dateTime")),
            "data:hasEndDateTime": (.end | typed("xsd:dateTime")),
            "rdfs:label": ("Time interval \(.start) - \(.end)" | en),
            "rdfs:comment": ("Time interval starting at date time \(.start) and ending at date time \(.end)." | en)
        },
        (
            select($time_iris.variable != null) |
            {
                "@id": $time_iris.variable,
                "@type": "data:DimensionalSpace",
                "data:basedOnDimensionalSpace": [
                    id(ns + "dimensions/time/reference-frames/gregorian"),
                    id($time_iris.quantization)
                ],
                "data:adoptsQuantization": id($time_iris.quantization),
                "data:hasExactBoundingRegion": id($time_iris.region)
            },
            {
                "@id": $time_iris.quantization,
                "@type": "data:\(.dimensional_space_type)",
                "data:basedOnDimensionalSpace": id(ns + "dimensions/time"),
                "data:hasResolutionValue": (.step | typed("xsd:duration")),
                "data:hasPeriodValue": (.period | typed("xsd:duration")),
                "data:hasInPeriodResolutionValue": (.in_period_step | typed("xsd:duration")),
                "data:hasOffsetValue": (.offset | typed("xsd:duration"))
            }
        )
    )
] |
# without empty values, each node once
map(with_entries(select(.value != null and .value != []))) |
unique |
{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        xsd: "http://www.w3.org/2001/XMLSchema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        data: "https://w3id.org/hacid/onto/data/"
    },
    "@graph": .
}
