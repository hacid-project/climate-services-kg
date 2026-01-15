"https://hacid-backend.istc.cnr.it/api/knowledge-graph/" as $data_source_prefix |

[
    .[].children.[] | select(.data |length > 0) |
    .data as $data_type |
    {
        key: .task_label,
        value: (
            .metadata |
            if .entity_type then .entity_type = true end |
            if .data_source
                then .data_source |=
                    if startswith($data_source_prefix)
                        then .[($data_source_prefix| length):]
                    end
            end |
            .data_type = $data_type
        )
    }
] | from_entries