# Functions mapping to JSON-LD the CMIP5 datasets and simulations, shared by
# the mapping of the CMIP5 datasets (datasets.jq) and by the mappings of the
# sources referring to them (e.g. the CORDEX-CMIP5 downscalings and the UKCP18
# datasets), so that each of them can give the nodes of the simulations and
# datasets it refers to, with the same IRIs and triples, also when they are
# missing from the CMIP5 search results.
#
# The functions take their values from the metadata (in the ESGF search
# results, the facets: model, experiment, ensemble, product...), not from the
# dataset ids. Their input is an object whose keys are documented with each
# function; the optional keys can be missing or null.
#
# The nodes are JSON-LD nodes, without empty values, using the prefixes of
# esgf_context (rdfs, xsd, top, ccso, data); the same node can be given more
# than once (e.g. for each dataset of a simulation) and must be merged, e.g.
# with unique or by a JSON-LD processor.
#
# Needs the module esgf (this directory) and the modules of
# data-sources/cmor-tables/mapping in the library path (-L); a program using
# esgf_context or the other functions of esgf.jq must include esgf as well
# (the definitions of an included module are not passed on).

include "esgf";

# Nodes without null or empty values
def _nodes: with_entries(select(.value != null and .value != []));

# Reference to a node (null without IRI)
def _id_or_null($iri): if $iri != null then id($iri) else null end;

# --- Models

# CMIP5 models whose name (the ESGF facet model) is not their model id (as in
# the dataset ids of the DRS and in the IRIs of the simulations): {<name>:
# <id>}. Those of the CMIP5 search results (data/cmip5.json), and those not in
# the search results referred to by other sources (BCC-CSM1.1, BCC-CSM1.1(m),
# CESM1(BGC), from the CMIP5 conventions). For the other models the name and
# the id are the same.
def _cmip5_model_ids:
    {
        "ACCESS1.0": "ACCESS1-0",
        "ACCESS1.3": "ACCESS1-3",
        "BCC-CSM1.1": "bcc-csm1-1",
        "BCC-CSM1.1(m)": "bcc-csm1-1-m",
        "CESM1(BGC)": "CESM1-BGC",
        "CSIRO-Mk3.6.0": "CSIRO-Mk3-6-0",
        "GFDL-CM2.1": "GFDL-CM2p1",
        "INM-CM4": "inmcm4"
    };

# CMIP5 model id of a model (input: its name, as the ESGF facet model, e.g.
# CSIRO-Mk3.6.0): as given by _cmip5_model_ids (e.g. CSIRO-Mk3-6-0, inmcm4),
# otherwise the name with each "." replaced by "-". An id is kept as it is.
def cmip5_model_id: _cmip5_model_ids[.] // gsub("\\."; "-");

# Name of a CMIP5 model (input: its model id, e.g. CSIRO-Mk3-6-0), as the ESGF
# facet model and in the IRIs of the models (e.g. CSIRO-Mk3.6.0): as given by
# _cmip5_model_ids, otherwise the id itself
def cmip5_model_name:
    . as $id |
    first(_cmip5_model_ids | to_entries[] | select(.value == $id) | .key) // $id;

# IRI of a model (input: its name, as the ESGF facet model)
def cmip5_model_iri: ns + "models/\(quote)";

# IRI of an institute (input: its acronym, as the ESGF facet institute)
def cmip5_institute_iri: ns + "organizations/\(quote)";

# Nodes of a global climate model and of the institutes maintaining it.
#
# Input:
# - name: the name of the model (as the ESGF facet model, e.g. CSIRO-Mk3.6.0);
# - institutes (optional): the acronyms of the institutes maintaining it (as
#   the ESGF facet institute, e.g. CSIRO-QCCCE).
def cmip5_model_jsonld:
    .name as $name |
    [.institutes[]? | cmip5_institute_iri] as $institutes |
    (
        {
            "@id": ($name | cmip5_model_iri),
            "@type": "ccso:GlobalClimateModel",
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

# Ids and IRIs of a CMIP5 simulation, of its ensemble, of its experiment and of
# their outputs.
#
# Input:
# - model: the CMIP5 model id (see cmip5_model_id, e.g. CSIRO-Mk3-6-0);
# - experiment: the experiment (e.g. rcp45);
# - ensemble: the ensemble member (e.g. r1i1p1);
# - product (optional): the product (e.g. output1), for the IRIs of the
#   outputs of the simulation and of the ensemble.
def cmip5_simulation_iris:
    . as {$model, $experiment, $ensemble, $product} |
    "cmip5.\($model).\($experiment).\($ensemble)" as $simulation_id |
    "cmip5.\($model).\($experiment)" as $ensemble_id |
    {
        simulation_id: $simulation_id,
        simulation: (ns + "simulations/\($simulation_id)"),
        output_id: (if $product != null then "\($simulation_id).\($product)" else null end),
        output: (if $product != null then ns + "datasets/\($simulation_id).\($product)" else null end),
        ensemble_id: $ensemble_id,
        ensemble: (ns + "simulations/\($ensemble_id)"),
        ensemble_output_id: (if $product != null then "\($ensemble_id).\($product)" else null end),
        ensemble_output: (if $product != null then ns + "datasets/\($ensemble_id).\($product)" else null end),
        experiment: (ns + "mips/cmip5/experiments/\($experiment)"),
        experiment_output: (ns + "datasets/cmip5.\($experiment)/output"),
        space: (ns + "simulations/\($simulation_id)/geodetic-grid")
    };

# IRI of a CMIP5 simulation (input as for cmip5_simulation_iris)
def cmip5_simulation_iri: cmip5_simulation_iris.simulation;

# IRI of the output of a CMIP5 simulation for a product (input as for
# cmip5_simulation_iris, with the product)
def cmip5_simulation_output_iri: cmip5_simulation_iris.output;

# Nodes of a CMIP5 simulation, of its ensemble (the simulations of the same
# model and experiment), of its experiment, of their outputs for a product,
# and of the output of CMIP5, with the spatial grid of the simulation (the
# whole globe). Without a product, the outputs of the simulation and of the
# ensemble are not given.
#
# Input:
# - model, experiment, ensemble, product (optional): as for
#   cmip5_simulation_iris;
# - models (optional): the names of the models used (as the ESGF facet model,
#   see cmip5_model_jsonld for their nodes);
# - variables (optional): the IRIs of the variables of which the outputs hold
#   specializations;
# - datasets (optional): the IRIs of the datasets that are components of the
#   output of the simulation;
# - description (optional): comments on the output of the simulation.
def cmip5_simulation_jsonld:
    cmip5_simulation_iris as $iris |
    ([.experiment] | scenario_iris | map(id(.))) as $refers_to_scenario |
    ([.variables[]?] | map(id(.))) as $holds_variable |
    ([.models[]? | cmip5_model_iri] | map(id(.))) as $uses_model |
    id(ns + "dimensions/geodetic/all/specialization") as $geodetic_specialization |
    (
        # Output of the simulation
        {
            "@id": $iris.output,
            "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ($iris.output_id | en),
            "ccso:productId": .product,
            "rdfs:comment": [.description[]? | en],
            "data:holdsSpecializationOfVariable": $holds_variable,
            "data:dependsOnVariable": id($iris.space),
            "top:hasComponent": [.datasets[]? | id(.)],
            "data:isSpecializedAccordingTo": $geodetic_specialization,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Simulation
        {
            "@id": $iris.simulation,
            "@type": ["ccso:SingleSimulation", "ccso:GlobalClimateSimulation"],
            "rdfs:label": ($iris.simulation_id | en),
            "top:componentIdentifier": .ensemble,
            "data:hasOutput": _id_or_null($iris.output),
            "ccso:usesModel": $uses_model,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Ensemble
        {
            "@id": $iris.ensemble,
            "@type": ["ccso:PerturbedParameterClimateEnsembleSimulation", "ccso:GlobalClimateSimulation"],
            "rdfs:label": ($iris.ensemble_id | en),
            "top:hasComponent": id($iris.simulation),
            "data:hasOutput": _id_or_null($iris.ensemble_output),
            "ccso:usesModel": $uses_model,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Output of the ensemble
        {
            "@id": $iris.ensemble_output,
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ($iris.ensemble_output_id | en),
            "data:holdsSpecializationOfVariable": $holds_variable,
            "top:hasComponent": id($iris.output),
            "data:isSpecializedAccordingTo": $geodetic_specialization,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Experiment
        {
            "@id": $iris.experiment,
            "@type": ["ccso:ClimateModelIntercomparisonExperiment", "ccso:GlobalClimateSimulation"],
            "top:hasComponent": id($iris.ensemble),
            "data:hasOutput": id($iris.experiment_output),
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Output of the experiment
        {
            "@id": $iris.experiment_output,
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": ("output of cmip5.\(.experiment)" | en),
            "data:holdsSpecializationOfVariable": $holds_variable,
            "top:hasComponent": _id_or_null($iris.ensemble_output),
            "data:isSpecializedAccordingTo": $geodetic_specialization,
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Output of CMIP5
        {
            "@id": (ns + "mips/cmip5/output"),
            "top:hasComponent": id($iris.experiment_output)
        },
        # Spatial grid
        {
            "@id": $iris.space,
            "@type": "data:DimensionalSpace",
            "data:basedOnDimensionalSpace": id(ns + "dimensions/geodetic/reference-frames/WGS84"),
            "data:hasExactBoundingRegion": id(ns + "dimensions/geodetic/all")
        }
    ) |
    # (no outputs without a product)
    select(."@id" != null) |
    _nodes;

# --- Datasets

# Nodes of a CMIP5 dataset of the ESGF search results, with its temporal grid
# (its time interval rounded to the time frequency, see temporal_grid in
# esgf.jq), its simulation (cmip5_simulation_jsonld) and its models
# (cmip5_model_jsonld).
#
# Input: the ESGF metadata of the dataset, with the keys (lists of one value
# but model and institute, see the CMIP5 search results, data/cmip5.json):
# - master_id: the id of the dataset (for its IRI and label);
# - product, model (the model names), experiment, ensemble, time_frequency;
# - institute: the institutes maintaining the models;
# - datetime_start, datetime_stop (optional): the time interval of the
#   dataset;
# - description (optional): comments on the output of the simulation.
# The model of the simulation is the first model (its id, cmip5_model_id).
#
# Arguments: $variables, the IRIs of the variables of the dataset (e.g.
# resolved with cmip5_dataset_variable_iri, see datasets.jq).
def cmip5_dataset_jsonld($variables):
    (ns + "datasets/\(.master_id)") as $dataset |
    ([.experiment[]] | scenario_iris | map(id(.))) as $refers_to_scenario |
    temporal_grid as $time |
    ($time | temporal_iris) as $time_iris |
    $time_iris.region as $region |
    $time_iris.specialization as $time_specialization |
    (if $time_iris.variable != null then $time_iris else null end) as $time_grid |
    {
        model: (.model[0] | cmip5_model_id),
        experiment: .experiment[0],
        ensemble: .ensemble[0],
        product: .product[0]
    } as $simulation |
    ($simulation | cmip5_simulation_iris) as $iris |
    (
        # Dataset
        {
            "@id": $dataset,
            "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
            "rdfs:label": .master_id,
            "data:holdsSpecializationOfVariable": ($variables | map(id(.))),
            "data:dependsOnVariable": [id($iris.space), ($time_grid.variable | values | id(.))],
            "data:isSpecializedAccordingTo": [
                ($time_specialization | values | id(.)),
                id(ns + "dimensions/geodetic/all/specialization")
            ],
            "ccso:refersToScenario": $refers_to_scenario
        },
        # Simulation
        (
            $simulation + {
                models: .model,
                variables: $variables,
                datasets: [$dataset],
                description: .description
            } |
            cmip5_simulation_jsonld
        ),
        # Models
        (.institute as $institutes | .model[] | {name: ., $institutes} | cmip5_model_jsonld),
        # Temporal grid
        (
            $time | values |
            {
                "@id": $time_specialization,
                "@type": "data:VariableSpecialization",
                "data:isSpecializationOn": id(ns + "dimensions/time"),
                "data:hasSelectedRegion": id($region)
            },
            {
                "@id": $region,
                "@type": "data:TemporalRegion",
                "data:hasStartDateTime": (.start | typed("xsd:dateTime")),
                "data:hasEndDateTime": (.end | typed("xsd:dateTime")),
                "rdfs:label": ("Time interval \(.start) - \(.end)" | en),
                "rdfs:comment": ("Time interval starting at date time \(.start) and ending at date time \(.end)." | en)
            },
            (
                $time_grid | values |
                {
                    "@id": .variable,
                    "@type": "data:DimensionalSpace",
                    "data:basedOnDimensionalSpace": id(ns + "dimensions/time/reference-frames/gregorian"),
                    "data:adoptsQuantization": id(.quantization),
                    "data:hasExactBoundingRegion": id($region)
                },
                {
                    "@id": .quantization,
                    "@type": "data:\($time.dimensional_space_type)",
                    "data:basedOnDimensionalSpace": id(ns + "dimensions/time"),
                    "data:hasResolutionValue": ($time.step | typed("xsd:duration")),
                    "data:hasPeriodValue": ($time.period | typed("xsd:duration")),
                    "data:hasInPeriodResolutionValue": ($time.in_period_step | typed("xsd:duration")),
                    "data:hasOffsetValue": ($time.offset | typed("xsd:duration"))
                }
            )
        )
    ) |
    _nodes;
