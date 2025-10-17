import "./cleansing/index_name_map" as $index_name_maps;
import "./cleansing/source_index_group_map" as $source_index_maps;
import "./utils/string" as string_utils;

# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

def fix_index_name:
    $index_name_maps[0] as $index_name_map |
    trim |
    string_utils::capitalize |
    ($index_name_map[.]? | (.[]? // .)) // .;

def group_by_group:
    group_by(.group) |
    map({
        key: .[0].group,
        value: map(.index)
    });

def fix_indices($grouped_indices):

    $source_index_maps[0] as $source_index_map |

    (
        [
            (
                $grouped_indices | to_entries | .[] |
                .key as $group_id |
                .value | to_entries | .[] |
                .value = {
                    group: $group_id,
                    index: .key
                }
            ),
            (
                $source_index_map | to_entries | .[] |
                .key as $group_id |
                .value | to_entries | .[] | {
                    key: .key,
                    value: {
                        group: $group_id,
                        index: .value
                    }
                }
            )
        ] | from_entries
    ) as $index_to_group_map |

    select(length > 0) |
    map(
        fix_index_name |
        (
            $index_to_group_map[.] //
            {
                group: "unknown",
                index: .
            }
        )
    ) |
    group_by_group |
    from_entries;
