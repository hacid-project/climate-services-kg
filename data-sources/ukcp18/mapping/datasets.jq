# Mapping of the UKCP18 datasets (input, read with -n: their metadata, a JSON
# value for each, as the lines of data/ceda_ukcp18_metadata.jsonl) to their
# JSON-LD nodes (output: one node per result, without context; see frame.jq):
# each dataset, its simulation and their links. The datasets are read and
# mapped one at a time: the mapping of a dataset depends only on its metadata
# and on the data and specifications of mapping/ and data/.
#
# Arguments: --slurpfile mip_index <data/mip-mapping-index.json> (index of
# data-sources/cmor-tables/mapping/mip-mapping.json, mip_mapping_index); the
# modules of mapping and of data-sources/cmor-tables/mapping must be in the
# library path (-L), run from data-sources/ukcp18.

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

["scenario", "collection", "domain", "resolution", "frequency"] as $id_comps_to_check |

$mip_index[0] as $mip_index |

# The JSON-LD resources without null values
def clean: walk( if type == "object" or type =="array" then map_values( select(values) ) end );

# each dataset (a JSON value of the input, read with -n) mapped on its own
inputs |
(
    IDS::fix_variable |
    IDS::fix_units |
    # resolved once, used by the dataset and its simulation
    .variable_iri = VARIABLES::variable_iri($mip_index) |

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
) |
clean
)
