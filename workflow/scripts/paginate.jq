# The items (outputs of items) in arrays (pages) of $size items, the last one
# possibly shorter
def paginate(items; $size):
    # foreach, each page extended in place: items wrapped in an array, so that
    # null marks the end; .[0] the page being filled, .[1] the page completed
    foreach ((items | [.]), null) as $item (
        [[], null];
        if $item == null then
            [[], (.[0] | if length > 0 then . else null end)]
        else
            .[0][.[0] | length] = $item[0] |
            if (.[0] | length) == $size then
                [[], .[0]]
            else
                .[1] = null
            end
        end;
        .[1] | values
    );

# The same for the inputs
def paginate($size): paginate(inputs; $size);
