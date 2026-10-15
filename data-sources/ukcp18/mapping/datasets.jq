import "./data/spatial-grid-map" as $spatial_grid_maps;
import "./mapping/utils" as UTILS;
import "./mapping/time" as TIME;
import "./mapping/ukcp18-time" as UKCP18_TIME;
import "./mapping/simulations" as SIMULATIONS;
import "./mapping/jsonld" as JSONLD;
import "./mapping/ukcp18-variables" as VARIABLES;
import "./mapping/ukcp18-ids" as IDS;

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

["scenario", "collection", "domain", "resolution", "frequency"] as $id_comps_to_check |

map(IDS::fix_variable) |
IDS::fix_units |
VARIABLES::with_variable_iris |

(map(select(.collection != "marine-sim")) | VARIABLES::ukcp_variable_nodes) as $ukcp_variables |

[
    $mohc_models.[],
    $ukcp_variables.[],
    ( .[] |

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

        IDS::id_comp_struct as $id_comp_struct |

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
        
        if $id_comp_struct.model_variant_id then
            .model_variant_id = $id_comp_struct.model_variant_id
        end |

        if $id_comp_struct.date_interval then
            .date_interval = $id_comp_struct.date_interval
        else
            .gwl = $id_comp_struct.timeslice_or_gwl
        end |

        UKCP18_TIME::dataset_to_interval as $time_interval |

        .scenario |= if . == "a1b" then "sres-a1b" end |
        .id |= sub("_a1b_"; "_sres-a1b_") |

        (
            {
                "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                "@type": [
                    if $collection == "land-prob"
                        then "ccso:ProbabilisticProjection"
                        else "ccso:SingleProjection"
                    end,
                    # its kind of distribution representation, as its variable
                    (VARIABLES::distribution_representation_type | values)
                ],
                label: "ukcp18.\(.id[:-3])",
                single_dependent_variable: VARIABLES::variable_iri,
                independent_variable: [
                    UKCP18_TIME::dataset_to_variable($time_interval),
                    $spatial_grid_map[.domain][.resolution]
                ],
                specialization_criterion: [
                    $time_interval | TIME::specialization
                ]
            },
            if $collection == "land-cpm" then
                SIMULATIONS::dataset_to_cpm_simulation
            elif $collection == "land-rcm" then
                SIMULATIONS::dataset_to_rcm_simulation
            elif $collection == "land-gcm" then
                SIMULATIONS::dataset_to_gcm_simulation
            elif $collection == "EuroCORDEX" then
                SIMULATIONS::dataset_to_cordex_simulation
            elif $collection == "land-derived" then
                SIMULATIONS::dataset_to_gcm_derived_projection
            elif $collection == "land-prob" then
                SIMULATIONS::dataset_to_probabilistic_projection
            elif $collection == "land-indices" then
                SIMULATIONS::dataset_to_gcm_indices
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
                    sub_dataset: {
                        "@id": @uri "https://w3id.org/hacid/data/cs/ukcp18/datasets/\(.id)",
                    }
                }
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
            "@reverse": "top:hasComponent"
        }
    } +
    (
        {
            "@type": {
                "@id": {
                    has_output: "data:hasOutput",
                    sub_dataset: "top:hasComponent",
                    dependent_variable: "data:holdsSpecializationOfVariable",
                    single_dependent_variable: "data:isSpecializationOfVariable",
                    independent_variable: "data:dependsOnVariable",
                    downscaling_of: "ccso:isDownscalingOf", 
                    model: "ccso:usesModel", 
                    scenario: "ccso:refersToScenario", 
                    gwl: "ccso:refersToGlobalWarmingLevel", 
                    maintained_by: "ccso:isMaintainedBy",
                    specialization_criterion: "data:isSpecializedAccordingTo",
                    specialization_on: "data:isSpecializationOn",
                    selected_region: "data:hasSelectedRegion",
                    based_on_ds: "data:basedOnDimensionalSpace",
                    discretization: "data:hasDiscretization",
                    exact_bounding_region: "data:hasExactBoundingRegion",
                    is_member_of: "top:isMemberOf",
                    is_anomaly_of: "ccso:isAnomalyOf",
                    is_absolute_anomaly_of: "ccso:isAbsoluteAnomalyOf",
                    is_relative_anomaly_of: "ccso:isRelativeAnomalyOf",
                    is_probabilistic_representation_of: "data:isProbabilisticRepresentationOf",
                    derived_from_variable: "data:derivedFromVariable",
                    is_linear_transformation_of: "data:isLinearTransformationOf",
                    has_unit_of_measure: "top:hasUnitOfMeasure",
                    has_values_on: "data:hasValuesOn",
                },
                "http://www.w3.org/2001/XMLSchema#dateTime": {
                    start_datetime: "data:hasStartDateTime",
                    end_datetime: "data:hasEndDateTime"
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
                    comment: "rdfs:comment",
                    acronym: "top:acronym"
                }
            }

        } | JSONLD::unpack
    )
) as $context |

{
    "@context": $context,
    "@graph": $resources
} |
walk( if type == "object" or type =="array" then map_values( select(values) ) end )
