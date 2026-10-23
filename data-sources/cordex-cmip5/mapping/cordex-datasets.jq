# Functions mapping to JSON-LD the CORDEX-CMIP5 datasets and simulations,
# shared by the mapping of the CORDEX-CMIP5 datasets (datasets.jq) and by the
# mappings of the sources referring to them (e.g. the UKCP18 datasets), so
# that each of them can give the nodes of the simulations and datasets it
# refers to, with the same IRIs and triples, also when they are missing from
# the CORDEX search results.
#
# The functions take their values from the metadata (in the ESGF search
# results, the facets: domain, driving_model, experiment, ensemble, rcm_name,
# rcm_version, product...), not from the dataset ids. Their input is an object
# whose keys are documented with each function; the optional keys can be
# missing or null.
#
# The nodes are JSON-LD nodes, without empty values, using the prefixes of
# esgf_context (rdfs, xsd, top, ccso, data, see esgf.jq); the same node can be
# given more than once (e.g. for each dataset of a simulation) and must be
# merged, e.g. with unique or by a JSON-LD processor.
#
# Needs the modules of data-sources/cmip5/mapping (esgf.jq, cmip5-datasets.jq)
# and of data-sources/cmor-tables/mapping in the library path (-L); a program
# giving also the nodes of the driving CMIP5 simulations must include
# cmip5-datasets as well (the definitions of an included module are not passed
# on).

include "esgf";
include "cmip5-datasets";

# Nodes without null or empty values
def _nodes: with_entries(select(.value != null and .value != []));

# --- Models

# IRI of a regional model (input: its name, as the ESGF facet rcm_name)
def cordex_model_iri: ns + "models/\(quote)";

# Nodes of a regional climate model and of the institutes maintaining it.
#
# Input:
# - name: the name of the model (as the ESGF facet rcm_name, e.g. RACMO22E);
# - institutes (optional): the acronyms of the institutes maintaining it (as
#   the ESGF facet institute, e.g. KNMI).
def cordex_model_jsonld:
    .name as $name |
    [.institutes[]? | cmip5_institute_iri] as $institutes |
    (
        {
            "@id": ($name | cordex_model_iri),
            "@type": "ccso:RegionalClimateModel",
            "rdfs:label": ($name | en),
            "ccso:isMaintainedBy": ($institutes | map(id(.)))
        },
        (
            .institutes[]? |
            {
                "@id": cmip5_institute_iri,
                "@type": "top:Organization",
                "top:acronym": .
            }
        )
    ) |
    _nodes;

# --- Simulations

# IRI of the CORDEX grid of a domain (input: the domain, e.g. EUR-11), null for
# a domain without resolution (e.g. AUS), which is not a CORDEX grid (see
# data-sources/cordex-domains)
def cordex_grid_iri: if test("-") then ns + "cordex/grids/\(.)" else null end;

# Ids and IRIs of a CORDEX-CMIP5 simulation, of the ensembles it is part of, of
# its experiment and domain, and of their outputs.
#
# Input:
# - domain: the domain (e.g. EUR-11);
# - driving_model: the CMIP5 model id of the driving model (as in the IRIs of
#   the CMIP5 simulations, see cmip5_model_id, e.g. CNRM-CM5);
# - experiment: the experiment (e.g. rcp45);
# - ensemble: the ensemble member of the driving simulation (e.g. r1i1p1);
# - rcm_name, rcm_version: the regional model (e.g. RACMO22E) and its version
#   (e.g. v1);
# - product (optional): the product (e.g. output), for the IRIs of the outputs
#   of the simulation and of the driving ensemble.
def cordex_simulation_iris:
    . as {$domain, $driving_model, $experiment, $ensemble, $rcm_name, $rcm_version, $product} |
    "cordex.\($domain).\($driving_model).\($experiment).\($rcm_name).\($rcm_version).\($ensemble)" as $simulation_id |
    "cordex.\($domain).\($driving_model).\($experiment).\($rcm_name).\($rcm_version)" as $driving_ensemble_id |
    "cordex.\($domain).\($experiment).\($rcm_name).\($rcm_version)" as $ensemble_id |
    "cordex.\($domain).\($experiment)" as $experiment_id |
    "cordex.\($domain)" as $domain_id |
    (if $product != null then "cordex.\($product).\($domain).\($driving_model).\($experiment).\($rcm_name).\($rcm_version).\($ensemble)" else null end) as $output_id |
    (if $product != null then "cordex.\($product).\($domain).\($driving_model).\($experiment).\($rcm_name).\($rcm_version)" else null end) as $driving_ensemble_output_id |
    {
        simulation_id: $simulation_id,
        simulation: (ns + "simulations/\($simulation_id)"),
        output_id: $output_id,
        output: (if $output_id != null then ns + "datasets/\($output_id)" else null end),
        driving_simulation: ({model: $driving_model, $experiment, $ensemble} | cmip5_simulation_iri),
        driving_ensemble_id: $driving_ensemble_id,
        driving_ensemble: (ns + "simulations/\($driving_ensemble_id)"),
        driving_ensemble_output_id: $driving_ensemble_output_id,
        driving_ensemble_output: (if $driving_ensemble_output_id != null then ns + "datasets/\($driving_ensemble_output_id)" else null end),
        ensemble_id: $ensemble_id,
        ensemble: (ns + "simulations/\($ensemble_id)"),
        ensemble_output: (ns + "datasets/\($ensemble_id)"),
        experiment_id: $experiment_id,
        experiment: (ns + "simulations/\($experiment_id)"),
        experiment_output: (ns + "datasets/\($experiment_id)"),
        domain_id: $domain_id,
        domain: (ns + "simulations/\($domain_id)"),
        domain_output: (ns + "datasets/\($domain_id)"),
        grid: ($domain | cordex_grid_iri)
    };

# IRI of a CORDEX-CMIP5 simulation (input as for cordex_simulation_iris)
def cordex_simulation_iri: cordex_simulation_iris.simulation;

# IRI of the output of a CORDEX-CMIP5 simulation for a product (input as for
# cordex_simulation_iris, with the product)
def cordex_simulation_output_iri: cordex_simulation_iris.output;

# Id of a CORDEX-CMIP5 dataset, as in the DRS (cordex.<product>.<domain>.
# <institute>.<driving_model>.<experiment>.<ensemble>.<rcm_name>.<rcm_version>.
# <time_frequency>.<variable>), for the IRI of a dataset not in the search
# results.
#
# Input: the keys of cordex_simulation_iris, with the product, and:
# - institute: the acronym of the institute (e.g. KNMI);
# - time_frequency: the time frequency (e.g. day);
# - variable: the name of the variable (e.g. tas).
def cordex_dataset_id:
    "cordex.\(.product).\(.domain).\(.institute).\(.driving_model).\(.experiment).\(.ensemble).\(.rcm_name).\(.rcm_version).\(.time_frequency).\(.variable)";

# IRI of a CORDEX-CMIP5 dataset (input: its id, e.g. cordex_dataset_id)
def cordex_dataset_iri: ns + "datasets/\(.)";

# Nodes of a CORDEX-CMIP5 simulation (a downscaling of the CMIP5 simulation of
# the driving model), of the driving ensemble (the simulations of the same
# domain, driving model, experiment and regional model), of the ensemble (of
# the same domain, experiment and regional model), of the experiment, of the
# domain, of their outputs, and of CORDEX-CMIP5 and its output. Their spatial
# grid is the CORDEX grid of the domain (cordex_grid_iri), if any.
#
# Input:
# - domain, driving_model, experiment, ensemble, rcm_name, rcm_version,
#   product: as for cordex_simulation_iris, with the product;
# - models (optional): the names of the regional models used (as the ESGF
#   facet rcm_name, see cordex_model_jsonld for their nodes);
# - variables (optional): the IRIs of the variables of which the outputs hold
#   specializations;
# - datasets (optional): the IRIs of the datasets that are components of the
#   output of the simulation.
def cordex_simulation_jsonld:
    cordex_simulation_iris as $iris |
    ([.experiment] | scenario_iris | map(id(.))) as $refers_to_scenario |
    ([.variables[]?] | map(id(.))) as $variable_ids |
    (if $iris.grid != null then id("\($iris.grid)/ds") else null end) as $geodetic_variable |
    (if $iris.grid != null then id("\($iris.grid)/specialization") else null end) as $geodetic_specialization |
    ([.models[]? | cordex_model_iri] | map(id(.))) as $uses_model |
    (
        # Output of the simulation
        {
            "@id": $iris.output,
            "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ($iris.output_id | en),
            "data:holdsSpecializationOfVariable": $variable_ids,
            "data:dependsOnVariable": $geodetic_variable,
            "data:isSpecializedAccordingTo": $geodetic_specialization,
            "top:hasComponent": [.datasets[]? | id(.)],
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Simulation
        {
            "@id": $iris.simulation,
            "@type": ["ccso:SingleSimulation", "ccso:DynamicalDownscaling"],
            "rdfs:label": ($iris.simulation_id | en),
            "ccso:isDownscalingOf": id($iris.driving_simulation),
            "data:hasOutput": id($iris.output),
            "ccso:usesModel": $uses_model,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Driving ensemble
        {
            "@id": $iris.driving_ensemble,
            "@type": ["ccso:EnsembleSimulation", "ccso:DynamicalDownscaling"],
            "rdfs:label": ($iris.driving_ensemble_id | en),
            "top:hasComponent": id($iris.simulation),
            "data:hasOutput": id($iris.driving_ensemble_output),
            "ccso:usesModel": $uses_model,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Output of the driving ensemble
        {
            "@id": $iris.driving_ensemble_output,
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ($iris.driving_ensemble_output_id | en),
            "data:holdsSpecializationOfVariable": $variable_ids,
            "top:hasComponent": id($iris.output),
            "data:dependsOnVariable": $geodetic_variable,
            "data:isSpecializedAccordingTo": $geodetic_specialization,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Ensemble
        {
            "@id": $iris.ensemble,
            "@type": ["ccso:ClimateModelIntercomparisonExperiment", "ccso:DynamicalDownscaling"],
            "rdfs:label": ($iris.ensemble_id | en),
            "top:hasComponent": id($iris.driving_ensemble),
            "data:hasOutput": id($iris.ensemble_output),
            "ccso:usesModel": $uses_model,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Output of the ensemble
        {
            "@id": $iris.ensemble_output,
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ($iris.ensemble_id | en),
            "data:holdsSpecializationOfVariable": $variable_ids,
            "top:hasComponent": id($iris.driving_ensemble_output),
            "data:dependsOnVariable": $geodetic_variable,
            "data:isSpecializedAccordingTo": $geodetic_specialization,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Experiment
        {
            "@id": $iris.experiment,
            "@type": ["ccso:ClimateModelIntercomparisonExperiment", "ccso:DynamicalDownscaling"],
            "rdfs:label": ($iris.experiment_id | en),
            "top:hasComponent": id($iris.ensemble),
            "data:hasOutput": id($iris.experiment_output),
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Output of the experiment
        {
            "@id": $iris.experiment_output,
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ("output of \($iris.experiment_id)" | en),
            "data:holdsSpecializationOfVariable": $variable_ids,
            "top:hasComponent": id($iris.ensemble_output),
            "data:dependsOnVariable": $geodetic_variable,
            "data:isSpecializedAccordingTo": $geodetic_specialization,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Domain
        {
            "@id": $iris.domain,
            "@type": "top:Action",
            "rdfs:label": ($iris.domain_id | en),
            "top:hasComponent": id($iris.experiment),
            "data:hasOutput": id($iris.domain_output)
        },
        # Output of the domain
        {
            "@id": $iris.domain_output,
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ("output of \($iris.domain_id)" | en),
            "top:hasComponent": id($iris.experiment_output),
            "data:dependsOnVariable": $geodetic_variable,
            "data:isSpecializedAccordingTo": $geodetic_specialization
        },
        # CORDEX-CMIP5 and its output
        {
            "@id": (ns + "mips/cordex-cmip5"),
            "top:hasComponent": id($iris.domain)
        },
        {
            "@id": (ns + "mips/cordex-cmip5/output"),
            "top:hasComponent": id($iris.domain_output)
        }
    ) |
    _nodes;

# --- Datasets

# Nodes of a CORDEX-CMIP5 dataset of the ESGF search results, with its
# temporal grid (its time interval rounded to the time frequency, see
# temporal_grid in esgf.jq), its simulation (cordex_simulation_jsonld) and its
# regional models (cordex_model_jsonld).
#
# Input: the ESGF metadata of the dataset, with the keys (lists of one value
# but rcm_name and institute, see the CORDEX search results,
# data/cordex-<n>.json):
# - master_id: the id of the dataset (for its IRI and label);
# - product, domain, experiment, ensemble, rcm_name (the regional models),
#   rcm_version, time_frequency;
# - driving_model: the CMIP5 model id of the driving model (in the search
#   results prefixed by its institution, e.g. MOHC-HadGEM2-ES, normalised by
#   datasets.jq);
# - institute: the institutes maintaining the regional models;
# - datetime_start, datetime_stop (optional): the time interval of the
#   dataset.
# The regional model of the simulation is the first one.
#
# Arguments: $variables, the IRIs of the variables of the dataset (e.g.
# resolved with variable_iri_of, see datasets.jq).
def cordex_dataset_jsonld($variables):
    (ns + "datasets/\(.master_id)") as $dataset |
    ([.experiment[]] | scenario_iris | map(id(.))) as $refers_to_scenario |
    temporal_grid as $time |
    ($time | temporal_iris) as $time_iris |
    (.domain[0] | cordex_grid_iri) as $grid |
    (
        # Dataset
        {
            "@id": $dataset,
            "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": .master_id,
            "data:isSpecializationOfVariable": ($variables | map(id(.))),
            "data:dependsOnVariable": [
                ($grid | values | id("\(.)/ds")),
                ($time_iris.variable | values | id(.))
            ],
            "data:isSpecializedAccordingTo": [
                ($grid | values | id("\(.)/specialization")),
                ($time_iris.specialization | values | id(.))
            ],
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Simulation
        (
            {
                domain: .domain[0],
                driving_model: .driving_model[0],
                experiment: .experiment[0],
                ensemble: .ensemble[0],
                rcm_name: .rcm_name[0],
                rcm_version: .rcm_version[0],
                product: .product[0],
                models: .rcm_name,
                variables: $variables,
                datasets: [$dataset]
            } |
            cordex_simulation_jsonld
        ),
        # Regional models
        (.institute as $institutes | .rcm_name[] | {name: ., $institutes} | cordex_model_jsonld),
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
    ) |
    _nodes;
