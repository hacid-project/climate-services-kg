import "./data/operations" as $operations;

# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

[
    .[] |
    .Definition = ."Is this process used in specific situations? State those situations." |
    del(."Is this process used in specific situations? State those situations.") |
    with_entries(select(.value | length > 0) | (.value |= trim)| (.key |= trim))
] as $all_items |

[
    $all_items | .[] | select(.Method? | not) |
    .Name = .TypeOfAnalysis |
    del(.TypeOfAnalysis)
] as $analisis_types |

(
    [
        $all_items | .[] | select(.Method?) |
        .Name = .Method |
        del(.Method)
    ] | group_by(.TypeOfAnalysis) |
    [
        .[] | {
            key: .[0].TypeOfAnalysis,
            value: map(del(.TypeOfAnalysis))
        }
    ]| from_entries
) as $methods |

[
    $analisis_types | .[] |
    if (.Name | in($methods)) then
        .Methods = $methods[.Name]
    end
] 