[ .[] |
#    select(.id) |
#    (.id | split("_")) as $id_comps |
#    .num = $id_comps[5] |
#    (
#        $id_comps[7][:-3] as $date_interval_str |
#        if ($date_interval_str | strings) then
#            ($date_interval_str | split("-")) as $date_interval |
#            .start_date = $date_interval[0] |
#            .end_date = $date_interval[1]
#        end
#    ) as $date_interval |
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