import "./data/model-variants" as $model_variants;
import "./mapping/utils" as UTILS;
import "./mapping/time" as TIME;
import "./mapping/ukcp18-time" as UKCP18_TIME;
import "./mapping/jsonld" as JSONLD;

def scenario_uri:
    {
        "rcp45": "RCP4.5",
        "rcp85": "RCP8.5",
        "rcp26": "RCP2.6",
        "rcp60": "RCP6"
    } as $scenario_map |
    @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.])";

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
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
            }
        }
    else
        {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/cmip5.\($model).\(.scenario).\($variant)",
            has_output: @uri "https://w3id.org/hacid/data/cs/datasets/cmip5.\($model).\(.scenario).\($variant).output"
        }
    end as $simulation_with_output |

    # ($simulation_with_output | .has_output? | JSONLD::id) // .has_external_output)) as $output_id |

    $simulation_with_output +      
    {
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)",
            "@type": ["ccso:EnsembleSimulation", "ccso:GlobalClimateSimulation"],
            label: "ukcp18.global.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/output",
                label: "ukcp18.global.\(.scenario)",
                "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                has_part: ($simulation_with_output | .has_output | JSONLD::id) #$output_id
            }
        }
    };

def dataset_to_rcm_simulation:
    dataset_to_gcm_simulation as $gcm_simulation |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario).\(.model_variant_id)/output",
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        label: "ukcp18.regional.\(.scenario).\(.model_variant_id)",
        derived_from: ($gcm_simulation.has_output | JSONLD::id),
        dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
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
            downscaling_of: ($gcm_simulation.ensemble | JSONLD::id),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land-rcm/datasets/\(.scenario)/output",
                "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                has_part: ($output | JSONLD::id)
            }
        },
        downscaling_of: ($gcm_simulation | JSONLD::id),
        has_output: $output
    };

def dataset_to_cpm_simulation:
    dataset_to_rcm_simulation as $rcm_simulation |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario).\(.model_variant_id)/output",
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        label: "ukcp18.local.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        derived_from: ($rcm_simulation.has_output | JSONLD::id),
        dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
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
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                has_part: ($output | JSONLD::id)
            }
        },
        downscaling_of: ($rcm_simulation | JSONLD::id),
        has_output: $output
    };

def dataset_to_cordex_simulation:
    @uri "cordex.output.EUR-11.\(.institution_id).\(.driving_model_id).\(.scenario).\(.driving_model_ensemble_member).\(.model_id).\(.rcm_version_id).\(.frequency).\(.variable)" as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/cordex.EUR-11.\(.driving_model_id).\(.scenario).\(.model_id).\(.rcm_version_id).\(.driving_model_ensemble_member)",
        has_output: $output,
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.eurocordex.\(.scenario)",
            "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
            label: "ukcp18.eurocordex.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/EuroCORDEX/datasets/\(.scenario)/output",
                "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
                label: "ukcp18.eurocordex.\(.scenario)",
                scenario: (.scenario | scenario_uri),
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                has_part: $output
            }
        }
    };

def dataset_to_gcm_derived_projection:
    (.scenario = "rcp85" | dataset_to_gcm_simulation) as $gcm_simulation |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario).\(.model_variant_id)/output",
        "@type": "ccso:SingleProjection",
        label: "ukcp18.derived.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        derived_from: ($gcm_simulation.has_output | JSONLD::id),
        dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario).\(.model_variant_id)",
        "@type": "ccso:StatisticalDerivation",
        label: "ukcp18.derived.\(.scenario).\(.model_variant_id)",
        scenario: (.scenario | scenario_uri),
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario)",
            "@type": "ccso:StatisticalDerivation",
            label: "ukcp18.derived.\(.scenario)",
            scenario: (.scenario | scenario_uri),
            input: ($gcm_simulation.ensemble | JSONLD::id),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.derived.\(.scenario)/output",
                "@type": "ccso:EnsembleProjection",
                label: "ukcp18.derived.\(.scenario)",
                scenario: (.scenario | scenario_uri),
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                derived_from: ($gcm_simulation.ensemble | JSONLD::id),
                has_part: ($output | JSONLD::id)
            }
        },
        input: ($gcm_simulation | JSONLD::id),
        has_output: $output
    };

def dataset_to_probabilistic_projection:
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.prob.\(.scenario)/output",
        "@type": ["ccso:ProbabilisticProjection", "ccso:ScenarioBasedProjection"],
        label: "ukcp18.prob.\(.scenario)",
        scenario: (.scenario | scenario_uri),
        dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
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
        dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
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
            input: ($gcm_simulation.ensemble | JSONLD::id),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/derivations/ukcp18.indices.\(.scenario)/output",
                "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
                label: "ukcp18.indices.\(.scenario)",
                scenario: (.scenario | scenario_uri),
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                derived_from: ($gcm_simulation.ensemble | JSONLD::id),
                has_part: ($output | JSONLD::id)
            }
        },
        input: ($gcm_simulation | JSONLD::id),
        has_output: $output
    };

