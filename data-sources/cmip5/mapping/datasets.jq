# Mapping of the CMIP5 datasets (ESGF search results) to JSON-LD.
#
# Input: the response of an ESGF search of CMIP5 datasets (data/cmip5.json, see
# query.txt), {"response": {"docs": [...]}}.
#
# Port of the RML mapping rml/cmip5.ttl and of its functions in ws-data-rml.py.
# For each dataset (master_id cmip5.<product>.<institute>.<model>.<experiment>.
# <time_frequency>.<realm>.<cmor_table>.<ensemble>):
# - the dataset, its simulation output (all the datasets of the same model,
#   experiment, ensemble member and product), the outputs of the ensemble and of
#   the experiment, and the output of CMIP5;
# - the simulation, the ensemble, the experiment and the model, with its
#   institute;
# - the variables of the dataset, its spatial grid and its temporal grid (the
#   time interval of the dataset rounded to the time frequency).
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
# data-sources/cmor-tables/mapping and of this directory (esgf.jq) must be in
# the library path (-L).

include "variables-jsonld";
include "mip-variables";
include "esgf";

# --- Mapping

($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
$mip_index[0] as $mip_index |
# the IRIs of the variables of the CMIP5 tables, from the configuration
cmip5_variable_index($entries_by_name; $mip_index) as $variable_index |
[
    .response.docs[] |
    (.master_id | split(".")) as $parts |
    {
        product: $parts[1],
        institute: $parts[2],
        model: $parts[3],
        experiment: $parts[4],
        ensemble: $parts[-1]
    } as $id |

    (ns + "datasets/\(.master_id)") as $dataset |
    (ns + "datasets/cmip5.\($id.model).\($id.experiment).\($id.ensemble).\($id.product)") as $output |
    (ns + "simulations/cmip5.\($id.model).\($id.experiment).\($id.ensemble)") as $simulation |
    (ns + "simulations/cmip5.\($id.model).\($id.experiment)") as $ensemble |
    (ns + "datasets/cmip5.\($id.model).\($id.experiment).\($id.product)") as $ensemble_output |
    (ns + "mips/cmip5/experiments/\($id.experiment)") as $experiment |
    (ns + "datasets/cmip5.\($id.experiment)/output") as $experiment_output |
    "\($simulation)/geodetic-grid" as $space |
    [.model[] | ns + "models/\(quote)"] as $models |
    [.institute[] | ns + "organizations/\(quote)"] as $institutes |
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
    (.experiment | scenario_iris) as $scenarios |
    temporal_grid as $time |
    ($time | temporal_iris) as $time_iris |
    $time_iris.region as $region |
    $time_iris.specialization as $time_specialization |
    (if $time_iris.variable != null then $time_iris else null end) as $time_grid |
    ($scenarios | map(id(.))) as $refers_to_scenario |
    ($variables | map(id(.))) as $holds_variable |
    id(ns + "dimensions/geodetic/all/specialization") as $geodetic_specialization |

    # Dataset
    {
        "@id": $dataset,
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": .master_id,
        "data:holdsSpecializationOfVariable": $holds_variable,
        "data:dependsOnVariable": [id($space), ($time_grid.variable | values | id(.))],
        "data:isSpecializedAccordingTo": [($time_specialization | values | id(.)), $geodetic_specialization],
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the simulation
    {
        "@id": $output,
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment).\($id.ensemble).\($id.product)" | en),
        "ccso:productId": $id.product,
        "rdfs:comment": [.description[]? | en],
        "data:holdsSpecializationOfVariable": $holds_variable,
        "data:dependsOnVariable": id($space),
        "top:hasComponent": id($dataset),
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Simulation
    {
        "@id": $simulation,
        "@type": ["ccso:SingleSimulation", "ccso:GlobalClimateSimulation"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment).\($id.ensemble)" | en),
        "top:componentIdentifier": $id.ensemble,
        "data:hasOutput": id($output),
        "ccso:usesModel": ($models | map(id(.))),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Ensemble
    {
        "@id": $ensemble,
        "@type": ["ccso:PerturbedParameterClimateEnsembleSimulation", "ccso:GlobalClimateSimulation"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment)" | en),
        "top:hasComponent": id($simulation),
        "data:hasOutput": id($ensemble_output),
        "ccso:usesModel": ($models | map(id(.))),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the ensemble
    {
        "@id": $ensemble_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment).\($id.product)" | en),
        "data:holdsSpecializationOfVariable": $holds_variable,
        "top:hasComponent": id($output),
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Experiment
    {
        "@id": $experiment,
        "@type": ["ccso:ClimateModelIntercomparisonExperiment", "ccso:GlobalClimateSimulation"],
        "top:hasComponent": id($ensemble),
        "data:hasOutput": id($experiment_output),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the experiment
    {
        "@id": $experiment_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("output of cmip5.\($id.experiment)" | en),
        "data:holdsSpecializationOfVariable": $holds_variable,
        "top:hasComponent": id($ensemble_output),
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of CMIP5
    {
        "@id": (ns + "mips/cmip5/output"),
        "top:hasComponent": id($experiment_output)
    },
    # Model
    (
        [.model[] | en] as $labels |
        $models[] |
        {
            "@id": .,
            "@type": "ccso:GlobalClimateModel",
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
    # Spatial grid
    {
        "@id": $space,
        "@type": "data:DimensionalSpace",
        "data:basedOnDimensionalSpace": id(ns + "dimensions/geodetic/reference-frames/WGS84"),
        "data:hasExactBoundingRegion": id(ns + "dimensions/geodetic/all")
    },
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
