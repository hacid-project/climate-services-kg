# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

[
    .[] |
    with_entries(select(.value | length > 0) | .value |= trim)
#    .BackwardDependency |= (select(length > 0) | split("\n") | .[] | trim | select(length > 0)) |
#    .Role |= map($role_map[.] // "unknown") |
] as $all_hazard_types |

[
    $all_hazard_types | .[] | select(.HazardSubtype? | not) |
    .Name = .Hazard |
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
    .Specializations = (
        select(.Name | in($specific_hazard_types)) |
        $specific_hazard_types[.Name]
    )
] 