import "./data/model-variants" as $model_variants;
import "./mapping/utils" as UTILS;
import "./mapping/time" as TIME;
import "./mapping/ukcp18-time" as UKCP18_TIME;
import "./mapping/jsonld" as JSONLD;
import "./mapping/ukcp18-variables" as VARIABLES;
import "./data/cmip5-model-synonyms" as $model_synonyms_source;
# (the shared functions of the CMIP5 and CORDEX-CMIP5 mappings, see
# data-sources/cmip5/mapping/cmip5-datasets.jq and
# data-sources/cordex-cmip5/mapping/cordex-datasets.jq, in the library path)
import "cmip5-datasets" as CMIP5;
import "cordex-datasets" as CORDEX;


def scenario_uri:
    {
        "rcp45": "RCP4.5",
        "rcp85": "RCP8.5",
        "rcp26": "RCP2.6",
        "rcp60": "RCP6"
    } as $rcp_scenario_map |
    {
        "sres-a1b": "A1B"
    } as $sres_scenario_map |
    if . and $rcp_scenario_map[.] then
        @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($rcp_scenario_map[.])"
    elif . and $sres_scenario_map[.] then
        @uri "https://w3id.org/hacid/data/cs/scenarios/SRES/\($sres_scenario_map[.])"
    else null
    end;

def gwl_uri:
    {
        "gwl2": "GWL2",
        "gwl4": "GWL4"
    } as $gwl_map |
    if . and $gwl_map[.] then
        @uri "https://w3id.org/hacid/data/cs/GWLs/\($gwl_map[.])"
    else null
    end;

def normalize_model_id:
    $model_synonyms_source::model_synonyms_source[0]
    as $model_synonyms |
    if . and $model_synonyms[.] then
        $model_synonyms[.]
    end |
    gsub("\\."; "-");

def get_model_variant_from_id:
    (
        (
            {
                "HadGEM3-GC3.05": {
                    "01": "r1i1p1",
                    "02": "r1i1p0605",
                    "03": "r1i1p0834",
                    "04": "r1i1p1113",
                    "05": "r1i1p1554",
                    "06": "r1i1p1649",
                    "07": "r1i1p1843",
                    "08": "r1i1p1935",
                    "09": "r1i1p2123",
                    "10": "r1i1p2242",
                    "11": "r1i1p2305",
                    "12": "r1i1p2335",
                    "13": "r1i1p2491",
                    "14": "r1i1p2832",
                    "15": "r1i1p2868"
                },
                # "ACCESS1.3": {
                #     "23": "r1i1p1"
                # },
                # "IPSL-CM5A-MR": {
                #     "25": "r1i1p1"
                # },
                # "MRI-CGCM3": {
                #     "27": "r1i1p1"
                # },
                "MPI-ESM-LR": {
                    "29": "r1i1p1"
                }
            } | to_entries | [
                .[] |
                .key as $model |
                .value |
                to_entries |
                .[] |
                .value = {model: $model, variant: .value}
            ] | from_entries
        ) + (
            $model_variants[0] | with_entries(.value |= {model: .model_id, variant: .parent_experiment_rip})
        )
    ) as $model_variant_from_id |
    $model_variant_from_id[.];

# The CMIP5 runs that the UKCP18 global datasets of CMIP5 members would refer
# to, but that are not in CMIP5 ("<model id>.<experiment>.<ensemble>"): the
# rcp26 datasets of these members cover only the historical period (up to 2005,
# 2009 for EC-EARTH, whose historical run goes up to 2012), so they come from
# the historical run alone
def _runs_not_in_cmip5:
    {
        "ACCESS1-3.rcp26.r1i1p1": true,
        "CESM1-BGC.rcp26.r1i1p1": true,
        "CMCC-CM.rcp26.r1i1p1": true,
        "EC-EARTH.rcp26.r1i1p1": true
    };

# Accessors of the results of the dataset_to_*_simulation functions: a node
# (a simulation, or the processing of a source, see the CMIP5 members and
# dataset_to_cordex_simulation), with has_output, the output the datasets are
# part of (or rescaled versions of), and in these private keys:
# - _simulations, _outputs: the simulations and their outputs (of other
#   sources) the output derives from, if not the node and its output;
# - _ensemble: the UKCP18 ensemble, if not given by the key ensemble;
# - _members: nodes giving the membership of the simulations in the ensemble;
# - _extra: the nodes of the simulations of other sources (e.g. CMIP5).
def simulation_ids: if ._simulations then ._simulations[] else JSONLD::id end;
def simulation_outputs: if ._outputs then ._outputs[] else .has_output | JSONLD::id end;
def simulation_ensemble: ._ensemble // .ensemble;
def extra_nodes: ._extra[]?;
# All the nodes of a result
def nodes: del(._simulations, ._outputs, ._ensemble, ._members, ._extra), ._members[]?, extra_nodes;

# The ensemble of the UKCP18 global simulations of a scenario (input: a
# dataset), whose output has the output of a member ($output)
def _global_ensemble($output):
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)",
        "@type": ["ccso:EnsembleSimulation", "ccso:GlobalClimateSimulation"],
        label: "ukcp18.global.\(.scenario)",
        scenario: (.scenario | scenario_uri),
        has_output: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/output",
            label: "ukcp18.global.\(.scenario)",
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            dependent_variable: VARIABLES::variable_iri,
            sub_dataset: $output
        }
    };

# The simulation of a global dataset (input: its metadata): a HadGEM3-GC3.05
# simulation of UKCP18, or for a CMIP5 member the processing by UKCP18 of the
# outputs of its CMIP5 runs (the historical run and the run of the scenario, if
# in CMIP5, see _runs_not_in_cmip5; product output1), whose output (a UKCP18
# dataset, derived from those outputs) is the output of the member; the CMIP5
# runs, with the model (its CMIP5 model id and name, cmip5_model_id and
# cmip5_model_name), are members of the ensemble
def dataset_to_gcm_simulation:
    (.model_variant_id | get_model_variant_from_id) as {$model, $variant} |
    if $model == "HadGEM3-GC3.05" then 
        {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario).\(.model_variant_id)",
            "@type": ["ccso:GlobalClimateSimulation", "ccso:SingleSimulation"],
            label: "ukcp18.global.\(.scenario).\(.model_variant_id)",
            model: @uri "https://w3id.org/hacid/data/cs/models/\($model)",
            scenario: (.scenario | scenario_uri),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario).\(.model_variant_id)/output",
                "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
                label: "ukcp18.global.\(.scenario).\(.model_variant_id)",
                dependent_variable: VARIABLES::variable_iri
            }
        } as $simulation |
        $simulation + {ensemble: _global_ensemble($simulation.has_output | JSONLD::id)}
    else
        ($model | CMIP5::cmip5_model_id) as $model_id |
        ($model_id | CMIP5::cmip5_model_name) as $model_name |
        [
            "historical",
            (.scenario | select(_runs_not_in_cmip5["\($model_id).\(.).\($variant)"] | not))
        ] as $experiments |
        [$experiments[] | {model: $model_id, experiment: ., ensemble: $variant, product: "output1", models: [$model_name]}] as $runs |
        [$runs[] | CMIP5::cmip5_simulation_iris] as $iris |
        "ukcp18.global.\(.scenario).\(.model_variant_id)" as $id |
        (@uri "https://w3id.org/hacid/data/cs/ukcp18/land-gcm/datasets/\(.scenario).\(.model_variant_id)") as $output |
        _global_ensemble($output) as $ensemble |
        {
            "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land-gcm/processing/\(.scenario).\(.model_variant_id)",
            "@type": "data:DataTransformation",
            label: "processing of \([$iris[].simulation_id] | join(", ")) for \($id)",
            input: [$iris[].output],
            has_output: {
                "@id": $output,
                "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
                label: $id,
                scenario: (.scenario | scenario_uri),
                dependent_variable: VARIABLES::variable_iri,
                derived_from: [$iris[].output]
            },
            _simulations: [$iris[].simulation],
            _outputs: [$iris[].output],
            _ensemble: $ensemble,
            _members: [$iris[] | {"@id": .simulation, ensemble: $ensemble}],
            _extra: [($runs[] | CMIP5::cmip5_simulation_jsonld), ({name: $model_name} | CMIP5::cmip5_model_jsonld)]
        }
    end;

def dataset_to_rcm_simulation:
    dataset_to_gcm_simulation as $gcm_simulation |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario).\(.model_variant_id)/output",
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        label: "ukcp18.regional.\(.scenario).\(.model_variant_id)",
        derived_from: [$gcm_simulation | simulation_outputs],
        dependent_variable: VARIABLES::variable_iri
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario).\(.model_variant_id)",
        "@type": ["ccso:DynamicalDownscaling", "ccso:SingleSimulation"],
        label: "ukcp18.regional.\(.scenario).\(.model_variant_id)",
        model: "https://w3id.org/hacid/data/cs/models/HadREM3-GA705",
        scenario: (.scenario | scenario_uri),
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario)",
            "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
            label: "ukcp18.regional.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            downscaling_of: ($gcm_simulation | simulation_ensemble | JSONLD::id),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land-rcm/datasets/\(.scenario)/output",
                "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
                dependent_variable: VARIABLES::variable_iri,
                sub_dataset: ($output | JSONLD::id)
            }
        },
        downscaling_of: [$gcm_simulation | simulation_ids],
        has_output: $output,
        _extra: [$gcm_simulation | extra_nodes]
    };

def dataset_to_cpm_simulation:
    dataset_to_rcm_simulation as $rcm_simulation |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario).\(.model_variant_id)/output",
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        label: "ukcp18.local.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        derived_from: ($rcm_simulation.has_output | JSONLD::id),
        dependent_variable: VARIABLES::variable_iri
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario).\(.model_variant_id)",
        "@type": ["ccso:DynamicalDownscaling", "ccso:SingleSimulation"],
        label: "ukcp18.local.\(.scenario).\(.model_variant_id)",
        model: "https://w3id.org/hacid/data/cs/models/HadREM3-RA11M",
        scenario: (.scenario | scenario_uri),
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario)",
            "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
            label: "ukcp18.local.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            downscaling_of: ($rcm_simulation.ensemble | JSONLD::id),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land-cpm/datasets/\(.scenario)/output",
                "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
                label: "ukcp18.local.\(.scenario)",
                scenario: (.scenario | scenario_uri),
                dependent_variable: VARIABLES::variable_iri,
                sub_dataset: ($output | JSONLD::id)
            }
        },
        downscaling_of: ($rcm_simulation | JSONLD::id),
        has_output: $output,
        _extra: [$rcm_simulation | extra_nodes]
    };

# The simulation of a EuroCORDEX dataset (input: its metadata): the processing
# by UKCP18 of the outputs of the CORDEX-CMIP5 simulations (the historical one
# and the one of the scenario, as the datasets cover both periods; product
# output), whose output (a UKCP18 dataset of a time frequency and variable,
# derived from those outputs, with the id of a CORDEX-CMIP5 dataset of the
# scenario, cordex_dataset_id) is part of the output of the ensemble; the
# CORDEX-CMIP5 simulations (with their driving CMIP5 simulations and their
# regional model) are members of the ensemble
def dataset_to_cordex_simulation:
    (.model_id | normalize_model_id) as $rcm_name |
    {
        domain: "EUR-11",
        driving_model: (.driving_model_id | normalize_model_id),
        ensemble: .driving_model_ensemble_member,
        rcm_name: $rcm_name,
        rcm_version: .rcm_version_id,
        product: "output",
        models: [$rcm_name]
    } as $simulation |
    [("historical", .scenario) as $experiment | $simulation + {$experiment}] as $runs |
    [$runs[] | CORDEX::cordex_simulation_iris] as $iris |
    (
        $simulation + {experiment: .scenario, institute: .institution_id, time_frequency: .frequency, variable} |
        CORDEX::cordex_dataset_id
    ) as $product_id |
    (@uri "https://w3id.org/hacid/data/cs/ukcp18/EuroCORDEX/datasets/\($product_id)") as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.eurocordex.\(.scenario)",
        "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
        label: "ukcp18.eurocordex.\(.scenario)",
        scenario: (.scenario | scenario_uri),
        has_output: {
            "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/EuroCORDEX/datasets/\(.scenario)/output",
            "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
            label: "ukcp18.eurocordex.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            dependent_variable: VARIABLES::variable_iri,
            sub_dataset: $output
        }
    } as $ensemble |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/EuroCORDEX/processing/\($product_id)",
        "@type": "data:DataTransformation",
        label: "processing of \([$iris[].simulation_id] | join(", ")) for ukcp18.eurocordex.\(.scenario)",
        input: [$iris[].output],
        has_output: {
            "@id": $output,
            "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
            label: "ukcp18.\($product_id)",
            scenario: (.scenario | scenario_uri),
            dependent_variable: VARIABLES::variable_iri,
            derived_from: [$iris[].output]
        },
        _simulations: [$iris[].simulation],
        _outputs: [$iris[].output],
        _ensemble: $ensemble,
        _members: [$iris[] | {"@id": .simulation, ensemble: $ensemble}],
        _extra: [($runs[] | CORDEX::cordex_simulation_jsonld), ({name: $rcm_name} | CORDEX::cordex_model_jsonld)]
    };

def dataset_to_gcm_derived_projection:
    (.scenario = "rcp85" | dataset_to_gcm_simulation) as $gcm_simulation |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario).\(.model_variant_id)/output",
        "@type": "ccso:SingleProjection",
        label: "ukcp18.derived.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        gwl: (.scenario | gwl_uri),
        derived_from: ($gcm_simulation.has_output | JSONLD::id),
        dependent_variable: VARIABLES::variable_iri
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario).\(.model_variant_id)",
        "@type": [
            "ccso:StatisticalProjectionTransformation",
            "ccso:SingleProjectionProduction"
        ],
        label: "ukcp18.derived.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        gwl: (.scenario | gwl_uri),
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario)",
            "@type": [
                "ccso:StatisticalProjectionTransformation",
                "ccso:EnsembleProjectionProduction"
            ],
            label: "ukcp18.derived.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            gwl: (.scenario | gwl_uri),
            input: ($gcm_simulation | simulation_ensemble | .has_output | JSONLD::id),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario)/output",
                "@type": "ccso:EnsembleProjection",
                label: "ukcp18.derived.\(.scenario)",
                scenario: (.scenario | scenario_uri),
                gwl: (.scenario | gwl_uri),
                dependent_variable: VARIABLES::variable_iri,
                derived_from: ($gcm_simulation | simulation_ensemble | .has_output | JSONLD::id),
                sub_dataset: ($output | JSONLD::id)
            }
        },
        input: ($gcm_simulation.has_output | JSONLD::id),
        has_output: $output
    };

def dataset_to_probabilistic_projection:
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.prob.\(.scenario)/output",
        "@type": ["ccso:ProbabilisticProjection", "ccso:ScenarioBasedProjection"],
        label: "ukcp18.prob.\(.scenario)",
        scenario: (.scenario | scenario_uri),
        dependent_variable: VARIABLES::variable_iri
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.prob.\(.scenario)",
        "@type": ["ccso:ProbabilisticProjectionProduction", "ccso:StatisticalProjectionTransformation"],
        label: "ukcp18.prob.\(.scenario)",
        scenario: (.scenario | scenario_uri),
        has_output: $output
    };

def dataset_to_gcm_indices:
    dataset_to_gcm_simulation as $gcm_simulation |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.indices.\(.scenario).\(.model_variant_id)/output",
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        label: "ukcp18.indices.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        derived_from: ($gcm_simulation.has_output | JSONLD::id),
        dependent_variable: VARIABLES::variable_iri
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.indices.\(.scenario).\(.model_variant_id)",
        "@type": ["ccso:SingleProjectionProduction", "ccso:StatisticalProjectionTransformation"],
        label: "ukcp18.indices.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.indices.\(.scenario)",
            "@type": ["ccso:EnsembleProjectionProduction", "ccso:StatisticalProjectionTransformation"],
            label: "ukcp18.indices.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            input: ($gcm_simulation | simulation_ensemble | .has_output | JSONLD::id),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.indices.\(.scenario)/output",
                "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
                label: "ukcp18.indices.\(.scenario)",
                scenario: (.scenario | scenario_uri),
                dependent_variable: VARIABLES::variable_iri,
                derived_from: ($gcm_simulation | simulation_ensemble | .has_output | JSONLD::id),
                sub_dataset: ($output | JSONLD::id)
            }
        },
        input: ($gcm_simulation.has_output | JSONLD::id),
        has_output: $output
    };

