import "metadata" as $METADATA;

"https://hacid-backend.istc.cnr.it/api/knowledge-graph/" as $data_source_prefix |

(
    [
        "Define preferred access point",
        "Send climate information",
        "Disseminate climate information"
    ] | map({key: ., value: true}) | from_entries
) as $excluded_ops |

.Specializations.[] | select(."@id" == "ops:HandleCase") | .Specializations |
walk(
    if type == "object" and .Label then
        .Label as $task_label |
        if $task_label | in($excluded_ops) then empty end |
        "https://w3id.org/hacid/data/cs/wf/ops/\(."@id" | .[4:])" as $task_uri |
        $METADATA[0].[$task_label] as $task_metadata |
        {
            $task_label,
            task_description: .Description,
            $task_uri,
            children: (
                (.Specializations // []) |
                map(
                    .parent_task_label = $task_label |
                    .parent_task_uri = $task_uri
                )
            ),
            parent_task_label: null,
            parent_task_uri: "",
            data: "",
            metadata: {}
        } |
        if $task_metadata then
            .data = $task_metadata.data_type |
            .metadata = (
                $task_metadata |
                del(.data_type) |
                if .data_source then
                    .data_source |= "\($data_source_prefix)\(.)"
                end |
                if .entity_type then
                    .entity_type |=
                        if type == "boolean" then
                            "\($task_uri)/associated-data"
                        end
                end
            )
        end
    end
)

    # {
    #     "task_label": "Task - Optional Duration Range",
    #     "task_description": "The task of looking for additional information from existing literature.",
    #     "task_uri": "https://w3id.org/hacid/data/cs/wf/ops/PerformLiteratureReview",
    #     "children": [],
    #     "parent_task_label": "Search additional Information",
    #     "parent_task_uri": "https://w3id.org/hacid/data/cs/wf/ops/SearchAdditionalInformation",
    #     "data": "duration_range",
    #     "metadata": {
    #         "gui_label": "Select temporal resolution",
    #         "gui_start_label": "Minimum temporal resolution",
    #         "gui_end_label": "Maximum temporal resolution",
    #         "gui_single_label": "Temporal resolution",
    #         "optional_single": true
    #     }
    # },
