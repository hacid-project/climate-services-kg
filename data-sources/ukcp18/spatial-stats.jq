def as_array:
    if type != "array" then
        [.]
    end;

def copy($source; pattern):
    [path(pattern)] as $paths |
    reduce $paths.[] as $path (
        .;
        setpath($path; $source | getpath($path))
    );

def new($source; pattern):
    if $source | type == "array" then [] else {} end |
    copy($source; pattern);

def copy_as_array($source_array; pattern):
    [path(pattern)] as $paths |
    reduce $paths.[] as $path (
        .;
        setpath($path; $source_array | map(getpath($path)))
    );

def group_by(key_filter; aggregate_filter):
    map(
        . as $input_item |
        {
            key: new($input_item;key_filter),
            aggregable: new($input_item;aggregate_filter),
        }
    ) |
    group_by(.key) |
    map(
        . as $group |
        new($group[0].key; key_filter) |
        copy_as_array($group | map(.aggregable); aggregate_filter)
    );

{
    resolution: {
        "country/region/river": [
            "country",
            "region",
            "river"
        ]
    }
} as $value_groupings |

(
    $value_groupings |
    with_entries(.value |= with_entries({key:.value.[],value:.key}))
) as $rename_map |

map(
    with_entries(
        .value = ($rename_map[.key]?[.value]? // .value)
    )
) |
group_by(.collection, .resolution, .domain; .scenario) |
map(
    .scenario |= unique
)