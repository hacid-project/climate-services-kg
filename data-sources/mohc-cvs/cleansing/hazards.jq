import "./cleansing/fix_index_names" as fix_index_module;
import "./data/indices" as $mapped_indices;
import "./data/climdex_index_names" as $climdex_index_names;

(
    $mapped_indices[0] |
    .Climdex = ($climdex_index_names[0] | map({key: ., value: true}) | from_entries)
) as $grouped_indices |

# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

[
    .[] |
    with_entries(select(.value | length > 0) | .value |= trim) |
    .Definition = .HazardDefinition |  del(.HazardDefinition) |
    if .HazardAlias then .Aliases = [.HazardAlias] |  del(.HazardAlias) end |
    if .AssociatedIndices then
        .AssociatedIndices |= (map(split("+")) | flatten | fix_index_module::fix_indices($grouped_indices))
    end
#    .BackwardDependency |= (select(length > 0) | split("\n") | .[] | trim | select(length > 0)) |
#    .Role |= map($role_map[.] // "unknown") |
] as $all_hazard_types |

[
    $all_hazard_types | .[] | select(.HazardSubtype? | not) |
    .Name = .Hazard |
    if .OverarchingType? then .Name = .OverarchingType end |
    if (.Name | (endswith("flooding") or endswith("inundation"))) then .HazardSupertype = "Flooding" end |
    del(.Hazard)
] as $generic_hazard_types |

(
    [
        $all_hazard_types | .[] | select(.HazardSubtype?) |
        .Name = .HazardSubtype |
        del(.HazardSubtype)
    ] | group_by(.Hazard) |
    [
        .[] | {
            key: .[0].Hazard,
            value: map(del(.Hazard))
        }
    ]| from_entries
) as $specific_hazard_types |

[
    $generic_hazard_types | .[] |
    if (.Name | in($specific_hazard_types)) then
        .Specializations = $specific_hazard_types[.Name]
    end
] | group_by(.HazardSupertype) |
[
    (.[] | select(.[0].HazardSupertype) | {
        Name: .[0].HazardSupertype,
        Specializations: map(del(.HazardSupertype))
    }),
    (.[] | select(.[0].HazardSupertype | not) | .[])
]
