import "./data/spatial-grid-map" as $spatial_grid_maps;
import "./mapping/utils" as UTILS;
import "./mapping/time" as TIME;
import "./mapping/ukcp18-time" as UKCP18_TIME;

def scenario_uri:
    {
        "rcp45": "RCP4.5",
        "rcp85": "RCP8.5",
        "rcp26": "RCP2.6",
        "rcp60": "RCP6"
    } as $scenario_map |
    @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.scenario])";

def get_model_variant_from_id:
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
            "ACCESS1.3": {
                "23": "r1i1p1"
            },
            "IPSL-CM5A-MR": {
                "25": "r1i1p1"
            },
            "MRI-CGCM3": {
                "27": "r1i1p1"
            },
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
    ) as $model_variant_from_id |
    $model_variant_from_id[.];

def dataset_to_gcm_simulation($model_variant_id):
    ($model_variant_id | get_model_variant_from_id) as {$model, $variant} |
    if $model == "HadGEM3-GC3.05" then 
        {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/\($model_variant_id)",
            "@type": ["ccso:GlobalClimateSimulation", "ccso:SingleSimulation"],
            model: @uri "https://w3id.org/hacid/data/cs/models/\($model)",
            scenario: (.scenario | scenario_uri),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/\($model_variant_id)/output",
                "@type": "data:Dataset",
                variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
            }
        }
    else
        {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/cmip5.\($model).\(.scenario).\($variant)",
            has_external_output: @uri "https://w3id.org/hacid/data/cs/datasets/cmip5.\($model).\(.scenario).\($variant).output"
        }
    end as $simulation_with_output |

    ($simulation_with_output | (.has_output?."@id" // .has_external_output)) as $output_id |

    $simulation_with_output +      
    {
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)",
            "@type": ["ccso:EnsembleSimulation","ccso:GlobalClimateSimulation"],
            scenario: (.scenario | scenario_uri),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/output",
                "@type": "data:Dataset",
                variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                has_part: $output_id
            }
        }
    };

def dataset_to_rcm_simulation($model_variant_id):
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_rcm/datasets/\(.scenario)/\($model_variant_id)/output",
        "@type": "data:Dataset",
        variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario).\($model_variant_id)",
        "@type": ["ccso:DynamicalDownscaling", "ccso:SingleSimulation"],
        model: "https://w3id.org/hacid/data/cs/models/HadREM3-GA705",
        scenario: (.scenario | scenario_uri),
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario)",
            "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
            scenario: (.scenario | scenario_uri),
            downscaling_of: @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)",
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_rcm/datasets/\(.scenario)/output",
                "@type": "data:Dataset",
                variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                has_part: $output."@id"
            }
        },
        downscaling_of: dataset_to_gcm_simulation($model_variant_id)."@id",
        has_output: $output
    };

def dataset_to_cpm_simulation($model_variant_id):
    ($model_variant_id | get_model_variant_from_id) as {$model, $variant} |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_cpm/datasets/\(.scenario)/\($model_variant_id)/output",
        "@type": "data:Dataset",
        variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
    } as $output |
    {
        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario).\($model_variant_id)",
        "@type": ["ccso:DynamicalDownscaling", "ccso:SingleSimulation"],
        model: "https://w3id.org/hacid/data/cs/models/HadREM3-RA11M",
        scenario: (.scenario | scenario_uri),
        component_label: "\($model).\($variant)",
        ensemble: {
            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario)",
            "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
            scenario: (.scenario | scenario_uri),
            downscaling_of: (dataset_to_rcm_simulation($model_variant_id) | .ensemble."@id"),
            has_output: {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_cpm/datasets/\(.scenario)/output",
                "@type": "data:Dataset",
                variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                has_part: $output."@id"
            }
        },
        downscaling_of: (dataset_to_rcm_simulation($model_variant_id) | ."@id"),
        has_output: $output
    };

