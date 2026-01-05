import "./data/spatial-grid-map" as $spatial_grid_maps;
import "./mapping/utils" as UTILS;
import "./mapping/time" as TIME;
import "./mapping/ukcp18-time" as UKCP18_TIME;
import "./mapping/simulations" as SIMULATIONS;
import "./mapping/jsonld" as JSONLD;

$spatial_grid_maps as [$spatial_grid_map] |

(
    $spatial_grid_map |
    with_entries(
        .value |= with_entries(
            select(.value | contains("WGS84") | not) |
            .value |= ltrimstr("https://w3id.org/hacid/data/cs/")
        )
    )
) as $rescale_map |

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
    .maintained_by =  "https://w3id.org/hacid/data/cs/organizations/MOHC"
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


#    There are collections where the id is different because they are created in a different way. For "land-gcm", "land-eurocordex", "land-rcm", "land-cpm", "and "land-derived", the original id structure is preserved:
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

        UKCP18_TIME::dataset_to_interval($id_comp_struct) as $time_interval |

        if $id_comp_struct.date_interval then
            null
        else
            $id_comp_struct.timeslice_or_gwl
        end as $gwl |

        (
            {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                "@type":
                    if $collection == "land-prob"
                        then "ccso:ProbabilisticProjection"
                        else "ccso:SingleProjection"
                    end,
                label: .id[:-3],
                dependent_variable: @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.variable)",
                independent_variable: [
                    UKCP18_TIME::dataset_to_variable($time_interval),
                    $spatial_grid_map[.domain][.resolution]
                ],
                specialization_criterion: [
                    $time_interval | TIME::specialization
                ]
            },
            if $collection != "land-prob" then
                $id_comp_struct.model_variant_id as $model_variant_id |
                debug |
                if $collection == "land-cpm" then
                    SIMULATIONS::dataset_to_cpm_simulation($model_variant_id)
                elif $collection == "land-rcm" then
                    SIMULATIONS::dataset_to_rcm_simulation($model_variant_id)
                elif $collection == "land-gcm" then
                    SIMULATIONS::dataset_to_gcm_simulation($model_variant_id)
                elif $collection == "EuroCORDEX" then
                    SIMULATIONS::dataset_to_cordex_simulation
                elif $collection == "land-derived" then
                    SIMULATIONS::dataset_to_gcm_derived_projection($model_variant_id)
                elif $collection == "land-prob" then
                    SIMULATIONS::dataset_to_probabilistic_projection
                elif $collection == "land-indices" then
                    SIMULATIONS::dataset_to_gcm_indices($model_variant_id)
                else
                    {}
                end as $simulation |

                $rescale_map[.domain]?[.resolution]? as $rescale |
                if $rescale then
                    $simulation,
                    {
                        "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                        is_rescaled_version_of: ($simulation.has_output | JSONLD::id),
                        is_part_of: (
                            $simulation.ensemble?.has_output | 
                            if . then {
                                "@id": (JSONLD::id + $rescale),
                                "@type": "data:Dataset",
                                is_rescaled_version_of: JSONLD::id
                            }
                            end
                        )
                    }
                else
                    $simulation,
                    {
                        "@id": ($simulation.has_output | JSONLD::id),
                        has_part: {
                            "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                        }
                    }
                end
            end
        )
    )   
] as $resources |

(
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
        ensemble: {
            "@reverse": "ccso:hasMemberSimulation"
        }
    } +
    (
        {
            "@type": {
                "@id": {
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
                },
                "http://www.w3.org/2001/XMLSchema#duration": {
                    resolution_value: "data:hasResolutionValue",
                    period_value: "data:hasPeriodValue",
                    in_period_resolution_value: "data:hasInPeriodResolutionValue"
                }
            },
            "@language": {
                en: {
                    label: "rdfs:label",
                    comment: "rdfs:comment"
                }
            }

        } | JSONLD::unpack
    )
) as $context |

{
    "@context": $context,
    "@graph": $resources
}
