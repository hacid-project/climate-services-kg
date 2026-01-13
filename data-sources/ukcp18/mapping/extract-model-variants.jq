[
#    "branch_time",
    "forcing",
    "forcing_note",
    "initialization_method",
    "institute_id",
    "model_id",
#    "parent_experiment",
#    "parent_experiment_id",
    "parent_experiment_rip",
    "physics_version",
    "product",
#    "project_id",
    "realization"
] as $extracted_keys |

map(
    select(.collection == "land-gcm") |
    .variant = (.id[:-3] | split("_").[5]) |
    if .variant == "25" and .cmip5_model_id == "HadGEM2-ES" then
        debug | empty
    end |
    if .cmip5_parent_experiment_rip == "N/A" 
        then .cmip5_parent_experiment_rip = "r\(.cmip5_realization)i\(.cmip5_initialization_method)p\(.cmip5_physics_version)"
    end

) | group_by(.variant) |
map(
    # ([.[] | to_entries | .[] | .key | select(startswith("cmip5_")) | .[6:]] | unique) as $cmip5_keys |
    {
        key: .[0].variant,
        value: (
            . as $items |
            $extracted_keys |
            map(
                . as $key |
                {
                    $key,
                    value: ($items | map(.["cmip5_\($key)"] | values) | unique | if type == "array" then .[0] end)
                } |
                select(.value | length > 0)
            ) |
            from_entries
        )
    } |
    select(.value | to_entries | length > 0)
) |
from_entries
