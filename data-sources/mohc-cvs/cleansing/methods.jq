import "./data/operations" as $operations;
import "./utils/string" as string_utils;

# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");


(
    [
        $operations[0].[] |
        recurse(.Specializations[]?) |
        .Name |
        {key: ., value: true}
    ] | from_entries
) as $operation_names |

def fix_alias_list:
    if .Alias? then
        (
            .Alias | map(string_utils::capitalize_first) |
            reduce .[] as $alias (
                {list: [], continue: true};
                if .continue then
                    if $alias | (startswith("variants") or startswith("Variants")) then
                        .continue = false
                    else
                        .list += [$alias]
                    end
                end
            )
        ).list as $alias_list |
        if ($alias_list | length) > 0 then
            .Alias = $alias_list
        else
            del(.Alias)
        end
    end;

def check_operation:
    .;
#    if in($operation_names) then
#        {Result: "OK", Operation: .}
#    else
#        {Result: "KO", Operation: ., All: $operation_names}
#    end;

[
    .[] |
    .Definition = ."Is this process used in specific situations? State those situations." |
    del(."Is this process used in specific situations? State those situations.") |
    with_entries(select(.value | length > 0) | (.value |= trim)| (.key |= trim)) |
    if .TypeOfAnalysis | startswith("Statistical analys") then
        .Category = "Statistical analyses" |
        .TypeOfAnalysis |= .["Statistical analyses - " | length : ] |
        if .TypeOfAnalysis == "" then empty end
    end |
    if .AppliedInTask? then
        .ApplicableToOperation = (
            .AppliedInTask | split(";") |
            map(trim | string_utils::capitalize_first | check_operation)
        ) |
        del(.AppliedInTask)
    end |
    fix_alias_list
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
