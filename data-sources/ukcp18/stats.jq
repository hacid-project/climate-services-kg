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
    .[] | #range(length) as $entry_index | .[$entry_index] |

    .collection as $collection |
    select($collection != "marine-sim") |
    select($collection != "EuroCORDEX") |

    (. +
        (
            if .return_period
                then "\($collection)-rp"
                else $collection
            end as $collection |
            .id | decompose_id($collection) |
            .collection |=
                if in($id_collection_map)
                    then $id_collection_map[.]
                end
        )
    ) |

    del (.id)
] as $fixed_input |

[$fixed_input | .[] | keys] | flatten | unique | 
[ .[] |
    debug |
    . as $key |
    {
        key: .,
        value: [
            $fixed_input | .[] | .[$key]
        ] | group_by(.) |
        [ .[] |
            if .[0] then {key: .[0], value: length} else empty end
        ] | from_entries
    }
] | from_entries