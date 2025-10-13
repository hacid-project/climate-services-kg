# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

. as $input |

[$input.[] | keys] | flatten | unique | 
[ .[] |
    debug |
    . as $key |
    {
        key: .,
        value: [
            $input | .[] | .[$key]
        ] | flatten | group_by(.) |
        [ .[] |
            if .[0] then {key: .[0], value: length} else empty end
        ] | from_entries
    }
] | from_entries