def print_cache:

    def _print_cache($cache):

        def _print:
            .,
            if . == $cache.oldest_item then
                empty
            else
                $cache.by_key[.].prev | _print
            end;

        if $cache | not then
            []
        else
            [$cache.most_recent_item | _print]
        end;

    _print_cache(.);

# The items (outputs of items) without the repetitions of the same key (item |
# f, a string) among the last $cache_size distinct keys; the items with a null
# key are all kept
def best_effort_unique_by(items; f; $cache_size):

    # The cache (the state of foreach, with keep: whether the input is kept):
    # only scalars and entries are bound to variables, never the cache or
    # by_key, that are then updated in place instead of copied for each input
    def _filter_input($id):
        if $id == null then
            .keep = true
        elif .size == 0 then
            {
                by_key: {($id): {}},
                most_recent_item: $id,
                oldest_item: $id,
                size: 1,
                keep: true
            }
        elif $id == .most_recent_item then
            .keep = false
        else
            .most_recent_item as $most_recent_item |
            .oldest_item as $oldest_item |
            .by_key[$id] as $id_entry |
            .by_key[$id] = {prev: $most_recent_item} |
            .by_key[$most_recent_item].next = $id |
            .most_recent_item = $id |
            if $id_entry then
                .keep = false |
                .by_key[$id_entry.next].prev = $id_entry.prev |
                if $id == $oldest_item then
                    .oldest_item = $id_entry.next
                else
                    .by_key[$id_entry.prev].next = $id_entry.next
                end
            elif .size == $cache_size then
                .keep = true |
                .oldest_item = .by_key[$oldest_item].next |
                del(.by_key[$oldest_item])
            else
                .keep = true |
                .size += 1
            end
        end;

    # foreach, not a recursion on input: each output of a recursion goes back
    # through all the previous calls, quadratic in the number of inputs. The
    # key is computed in the source of foreach, not in its update: a generator
    # in f (e.g. any) would leave choice points holding the cache, then copied
    # instead of updated in place
    foreach (items | . as $item | f | [$item, .]) as [$item, $id] (
        {size: 0};
        _filter_input($id);
        if .keep then $item else empty end
    );

# The same for the inputs
def best_effort_unique_by(f; $cache_size): best_effort_unique_by(inputs; f; $cache_size);

# The items without the repetitions of the same @id among the last $cache_size
# distinct ids
def best_effort_unique(items; $cache_size): best_effort_unique_by(items; ."@id"; $cache_size);

# The same for the inputs
def best_effort_unique($cache_size): best_effort_unique(inputs; $cache_size);
