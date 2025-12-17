import "./data/spatial-grid-map" as $spatial_grid_maps;
import "./mapping/utils" as UTILS;

$spatial_grid_maps as [$spatial_grid_map] |

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

{
    "rcp45": "RCP4.5",
    "rcp85": "RCP8.5",
    "rcp26": "RCP2.6",
    "rcp60": "RCP6"
} as $scenario_map |

(
    {
        regular: {
            type: "RegularBinning",
            instances: {
                "1hr": "PT1H",
                "3hr": "PT3H",
                day: "P1D",
                mon: "P1M",
                seas: "P3M",
                ann: "P1Y",
                "ann-20y": "P20Y",
                "ann-30y": "P30Y"
            }
        },
        "regular-periodic": {
            type: "PeriodicRegularBinning",
            instances: {
                "mon-20y": {
                    in_period_step: "P1M",
                    period: "P1Y",
                    step: "P20Y"
                },
                "mon-30y":  {
                    in_period_step: "P1M",
                    period: "P1Y",
                    step: "P30Y"
                },
                "seas-20y":  {
                    in_period_step: "P3M",
                    period: "P1Y",
                    step: "P20Y"
                },
                "seas-30y":  {
                    in_period_step: "P3M",
                    period: "P1Y",
                    step: "P30Y"
                }
            }
        }
    } |
    to_entries | [
        .[] |
        .key as $grid_type | .value |
        .type as $class | .instances | to_entries | .[] |
        .value |=
            if isempty(. | strings) | not then {
                step: .,
                period: null,
                in_period_step: null
            } end + {
                $grid_type,
                $class
            }
    ] | from_entries
) as $frequency_map |

[
    {
        label: "HadGEM3-GC3.05",
        "@type": "ccso:GlobalClimateModel"
    },
    {
        label: "HadREM3-GA705",
        "@type": "ccso:RegionalClimateModel"
    },
    {
        label: "HadREM3-RA11M",
        "@type": "ccso:ConvectionPermittingClimateModel"
    } |
    ."@id" = @uri "https://w3id.org/hacid/data/cs/models/\(.label)" |
    .maintained_by |= {
        "@id": "https://w3id.org/hacid/data/cs/organizations/MOHC"
    }
] as $mohc_models |

[
    {
        for_collections: ["land-gcm", "EuroCORDEX", "land-rcm", "land-cpm", "land-derived"],
        id_structure: ["variable", "scenario", "collection", "domain", "resolution", "model_variant_id", "frequency", "date_interval"]
    },
    {
        for_collections: ["land-prob"],
        id_structure: ["variable", "scenario", "collection", "domain", "resolution", "method", "baseline", "timeslice_or_gwl", "frequency", "date_interval"]
    },
    {
        for_collections: ["land-prob-rp"],
        id_structure: ["variable", "return_period", "scenario", "collection", "domain", "resolution", "method", "baseline", "timeslice_or_gwl", "frequency", "date_interval"]
    },
    {
        for_collections: ["land-indices"],
        id_structure: ["variable", "scenario", "collection", "model_variant_id", "frequency", "date_interval"]
    }
] as $id_structure_by_collection_group |

{
    "land-eurocordex": "EuroCORDEX"
} as $id_collection_map |

["scenario", "collection", "domain", "resolution", "frequency"] as $id_comps_to_check |

(
    [
        $id_structure_by_collection_group |
        .[] |
        .id_structure as $id_structure |
        .for_collections[] |
        {
            key: .,
            value: (
                [
                    range(0; ($id_structure | length)) |
                    {
                        key: $id_structure[.],
                        value: .
                    } 
                ] | from_entries
            )
        }
    ] | from_entries
) as $id_comp_pos_by_collection |

def decompose_id($collection):
    (.[:-3] | split("_")) as $id_comp_list |
    $id_comp_pos_by_collection[$collection] |
    with_entries(.value = $id_comp_list[.value]);

[
    $mohc_models.[],
    ( .[] | #range(length) as $entry_index | .[$entry_index] |

#    "EuroCORDEX": 68255,
#    "land-cpm": 225435,
#    "land-derived": 16744,
#    "land-gcm": 73229,
#    "land-rcm": 21732
#    "land-prob": 56448,
#    "land-indices": 131,
#    "marine-sim": 811


#    There are collections where the id is different because they are created in a different way. For "land_gcm", "land_eurocordex", "land_rcm", "land_cpm", "and "land_derived", the original id structure is preserved:
#    <variable>_<scenario>_<collection>_<domain>_<resolution>_<ensemble_member>_<frequency>_<startDate>-<endDate>.nc
#
#    For others, it differs.
#    For example, the 'land-prob' collection won't include an ensemble member because it aggregates ensemble members to produce probabilistic projections. The structure for these is:
#    <variable>_<scenario>_<collection>_<domain>_<resolution>_<method>_<baseline>_<time_slice>_<frequency>_<startDate>_<endDate>.nc
#    where:
#    <method> is either "pdf" or "cdf"
#    <baseline> is always created as b<baselineStart><baselineEnd>, where <baselineStart> is the last two digits of the start year and <baselineEnd> is the last two digits of the end year
#    <time_slice> is the duration considered in creating the probabilities ("1yr", "20yr", "30yr" etc.).
#
#    Another id type is for "land-indices":
#    <variable>_<scenario>_<collection>_<ensemble_member>_<frequency>_<startDate>-<endDate>.nc
#
#    'marine-sim' is the most inconsistent, with each version having its own ID structure. It's probably best not to include this at all, as it would be a lot of work to unpick.

        .collection as $collection |
        select($collection != "marine-sim") |

        (
            if .return_period then "\($collection)-rp" else $collection end as $collection |
            .id | decompose_id($collection) |
            .collection |= if in($id_collection_map) then $id_collection_map[.] end
        ) as $id_comp_struct |

        (
            . as $all |
            $id_comps_to_check |
            map(
                if ($id_comp_struct[.] and $id_comp_struct[.] != $all[.]) then
                    "[\($all.id)] - Missmatch for \(.): \($id_comp_struct[.]) != \($all[.])!"
                else 
                    empty
                end
            )
        ) as $issues |
        if $issues | any then
            $issues | debug | empty
        end |

        if $id_comp_struct.date_interval then
            ($id_comp_struct.date_interval | split("-")) as $dates |
            ($dates[0] | UTILS::normalize_date(false)) as $start_datetime |
            ($dates[1] | UTILS::normalize_date(true)) as $end_datetime |
            {
                gwl: null,
                temporal_region: {
                    "@id": "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/regions/\($start_datetime)-\($end_datetime)",
                    "@type": "data:TemporalRegion",
                    $start_datetime,
                    $end_datetime,
                    label: "Time interval \($start_datetime) - \($end_datetime)",
                    coment: "Time interval starting at date time \($start_datetime) and ending at date time \($end_datetime)."
                }
            }
        else
            {
                "1y": {duration: "P1Y", end_datetime: "0001-01-01T00:00:00Z"},
                "20y": {duration: "P20Y", end_datetime: "0020-01-01T00:00:00Z"},
                "30y": {duration: "P30Y", end_datetime: "0030-01-01T00:00:00Z"}
            }[.time_slice_type] as {$duration, $end_datetime} |
            {
                gwl: $id_comp_struct.timeslice_or_gwl,
                temporal_region: {
                    "@id": "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/mobile-regions/\($duration)",
                    "@type": "data:TemporalRegion",
                    "0000-01-01T00:00:00Z",
                    $end_datetime,
                    label: "Mobile temporal interval with duration \($duration)",
                    coment: "Time interval with no fixed starting date time and a duration of \($duration)."
                }
            }
        end as {$gwl, $temporal_region} |


        $frequency_map[.frequency] as $grid |
        (
            [
                $grid.grid_type, $grid.step, $grid.period, $grid.in_period_step |
                strings
            ] |
            join("/")
        ) as $grid_type_id |

        (
            {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                "@type": "data:Dataset",
                label: .id[:-3],
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                independent_variable: [
                    {
                        "@id": "\($temporal_region."@id")/quantized/\($grid_type_id)",
                        "@type": "data:DimensionalSpace",
                        based_on_ds: {
                            "@id": "time:gregorian"
                        },
                        discretization: {
                            grid: $grid,
                            "@id": "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/quantizations/\($grid_type_id)",
                            based_on_ds: {
                                "@id": "dimension:time" # xsd:duration
                            },
                            "@type":  @uri "https://w3id.org/hacid/onto/data/\($grid.class)",
                            resolution_value: "\($grid.step)",
                            period_value: "\($grid.period)",
                            in_period_resolution_value: "\($grid.in_period_step)"
                        },
                        exact_bounding_region: $temporal_region."@id"
                    },
                    $spatial_grid_map[.domain][.resolution]
                ],
                specialization_criterion: {
                    "@id": "\($temporal_region."@id")/specialization",
                    "@type": "data:VariableSpecialization",
                    specialization_on: {
                        "@id": "dimension:time"
                    },
                    selected_region: $temporal_region
                }
            },
            if $collection != "land-prob" then
                $id_comp_struct.model_variant_id as $model_variant_id |
                $model_variant_from_id[$model_variant_id] as {model: $model, variant: $variant} |

                if $model == "HadGEM3-GC3.05" then 
                    {
                        gcm_id: @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/\($model_variant_id)",
                        gcm_output_id: @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/\($model_variant_id)/output"
                    }
                else
                    {
                        gcm_id: @uri "https://w3id.org/hacid/data/cs/simulations/cmip5.\($model).\(.scenario).\($variant)",
#                        gcm_output_id: @uri "https://w3id.org/hacid/data/cs/datasets/cmip5.\($model).\(.scenario).\($variant).output"
                        gcm_output_id: @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/\($model_variant_id)/output"
                    }
                end as {$gcm_id, $gcm_output_id} |

                if $collection == "land_cpm" then
                    {
                        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario).\($model_variant_id)",
                        "@type": ["ccso:DynamicalDownscaling", "ccso:SingleSimulation"],
                        model: "https://w3id.org/hacid/data/cs/models/HadREM3-RA11M",
                        scenario: @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.scenario])",
                        component_label: "\($model).\($variant)",
                        ensemble: {
                            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.local.\(.scenario)",
                            "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
                            scenario: @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.scenario])",
                            downscaling_of: @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario)",
                            has_output: {
                                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_cpm/datasets/\(.scenario)/output",
                                "@type": "data:Dataset",
                                variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                                has_part: {
                                    "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_cpm/datasets/\(.scenario)/\($model_variant_id)/output",
                                }
                            }
                        },
                        downscaling_of: @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario).\($model_variant_id)",
                        has_output: {
                            "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_cpm/datasets/\(.scenario)/\($model_variant_id)/output",
                            "@type": "data:Dataset",
                            variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                            has_part: {
                                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                            }
                        }
                    }
                elif $collection == "land_rcm" then
                    {
                        "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario).\($model_variant_id)",
                        "@type": ["ccso:DynamicalDownscaling", "ccso:SingleSimulation"],
                        model: "https://w3id.org/hacid/data/cs/models/HadREM3-GA705",
                        scenario: @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.scenario])",
                        ensemble: {
                            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.regional.\(.scenario)",
                            "@type": ["ccso:EnsembleSimulation","ccso:DynamicalDownscaling"],
                            scenario: @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.scenario])",
                            downscaling_of: @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)",
                            has_output: {
                                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_rcm/datasets/\(.scenario)/output",
                                "@type": "data:Dataset",
                                variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                                has_part: {
                                    "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_rcm/datasets/\(.scenario)/\($model_variant_id)/output",
                                }
                            },
                        },
                        downscaling_of: $gcm_id,
                        has_output: {
                            "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/land_cpm/datasets/\(.scenario)/\($model_variant_id)/output",
                            "@type": "data:Dataset",
                            variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                            has_part: {
                                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                            }
                        }
                    }
                elif $collection == "land_gcm" then
                    {
                        "@id": $gcm_id,
                        ensemble: {
                            "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)",
                            "@type": ["ccso:EnsembleSimulation","ccso:GlobalClimateSimulation"],
                            scenario: @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.scenario])",
                            has_output: {
                                "@id": @uri "https://w3id.org/hacid/data/cs/simulations/ukcp18.global.\(.scenario)/output",
                                "@type": "data:Dataset",
                                variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                                has_part: $gcm_output_id
                            },
                        },
                        has_output: {
                            "@id": $gcm_output_id,
                            "@type": "data:Dataset",
                            variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                            has_part: {
                                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)"
                            }
                        }
                        # "@included": {
                        #     "@id": $gcm_output_id,
                        #     has_part: {
                        #         "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                        #     }
                        # }
                    } +
                    if $model == "HadGEM3-GC3.05" then
                        {
                            "@type": ["ccso:GlobalClimateSimulation", "ccso:SingleSimulation"],
                            model: @uri "https://w3id.org/hacid/data/cs/models/\($model)",
                            scenario: @uri "https://w3id.org/hacid/data/cs/scenarios/RCP/\($scenario_map[.scenario])"
                            # has_output: {
                            #     "@id": $gcm_output_id,
                            #     "@type": "data:Dataset",
                            #     variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)"
                            # }
                        }
                    else {}
                    end
                end
            end
        )
    )   
] as $resources |

{
    rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    rdfs: "http://www.w3.org/2000/01/rdf-schema#",
    top: "https://w3id.org/hacid/onto/top-level/",
    ccso: "https://w3id.org/hacid/onto/ccso/",
    data: "https://w3id.org/hacid/onto/data/",
    index: "https://w3id.org/hacid/data/cs/climdex/indices/",
    sector: "https://w3id.org/hacid/data/cs/climdex/sectors/",
    parameter: "https://w3id.org/hacid/data/cs/climdex/parameters/",
    variable: "https://w3id.org/hacid/data/cs/variables/mip/",
    unit: "https://w3id.org/hacid/data/cs/unitsofmeasure/",
    dimension: "https://w3id.org/hacid/data/cs/dimensions/",
    aggregation: "https://w3id.org/hacid/data/cs/climdex/index-time-aggregations/",
    temporalgrid: "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/quantizations/",
    time: "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/",
    geodetic: "https://w3id.org/hacid/data/cs/dimensions/geodetic/reference-frames/",
    label: {
        "@id": "rdfs:label",
        "@language": "en"
    },
    comment: {
        "@id": "rdfs:comment",
        "@language": "en"
    },
    has_output: "data:hasOutput",
    has_part: "top:hasPart",
    variable: "data:holdsSpecializationOfVariable",
    downscaling_of: "ccso:isDownscalingOf", 
    model: "ccso:usesModel", 
    scenario: "ccso:refersToScenario", 
    maintained_by: "ccso:isMaintainedBy",
    specialization_criterion: "data:isSpecializedAccordingTo",
    specialization_on: "data:isSpecializationOn",
    selected_region: "data:hasSelectedRegion",
    start_datetime: "data:hasStartDateTime",
    end_datetime: "data:hasEndDateTime",
    based_on_ds: "data:basedOnDimensionalSpace",
    discretization: "data:hasDiscretization",
    exact_bounding_region: "data:hasExactBoundingRegion",
    resolution_value: {
        "@id": "data:hasResolutionValue",
        "@type": "http://www.w3.org/2001/XMLSchema#duration"
    },
    period_value: {
        "@id": "data:hasPeriodValue",
        "@type": "http://www.w3.org/2001/XMLSchema#duration"
    },
    in_period_resolution_value: {
        "@id": "data:hasInPeriodResolutionValue",
        "@type": "http://www.w3.org/2001/XMLSchema#duration"
    },
    ensemble: {
        "@reverse": {
            "@id": "ccso:hasMemberSimulation"
        }
    }
} as $context |

{
    "@context": $context,
    "@graph": $resources
}
