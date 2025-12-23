import "./data/spatial-stats" as $SPATIAL_STATS;

$SPATIAL_STATS as [$spatial_stats] |

. as $input |
[
    (
        $spatial_stats.[] |
        select(.collection != "marine-sim") |
        .resolution |= if . == "country/region/river" then "region" end |
        .scenario |= (
            map(
                if startswith("rcp") then
                    if . != "rcp85" and . != "rcp26" then empty end
                elif startswith("gwl") then "gwl2"
                end
            ) |
            unique | .[]
        ) |
        .frequency = ("ann", "mon-20y")
    ) as $kind |
    (
        $input |
        map(
            . as $item |
            select($kind | to_entries | map($item[.key] == .value) | all)
        )
    )[:3].[]
]

