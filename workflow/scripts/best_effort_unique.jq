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

def best_effort_unique($cache_size):

    def _filter_input:
        .item."@id" as $id |
        if .cache | not then
            .cache = {
                by_key: {($id): {}},
                most_recent_item: $id,
                oldest_item: $id,
                size: 1
            }
        else 
            if $id == .cache.most_recent_item then
                del(.item)
            else
                .cache.by_key[$id] as $id_entry |
                .cache as $cache |
                .cache |= (
                    .by_key |= (
                        .[$id] = {
                            prev: $cache.most_recent_item
                        } |
                        .[$cache.most_recent_item] |= (.next = $id)
                    ) |
                    .most_recent_item = $id
                ) |
                if $id_entry then
                    del(.item) | 
                    .cache |= (
                        .by_key[$id_entry.next] |= (.prev = $id_entry.prev) |
                        if $id == $cache.oldest_item then
                            .oldest_item = $id_entry.next
                        else
                            .by_key[$id_entry.prev] |= (.next = $id_entry.next)
                        end
                    )
                else
                    .cache |=
                        if .size == $cache_size then
                            .oldest_item = .by_key[$cache.oldest_item].next |
                            .by_key |= del(.[$cache.oldest_item])
                        else
                            .size += 1
                        end
                end
            end
        end;

    def _read_input:
        try (
            {item: input, cache: .} |
            _filter_input |
            ((.item | if not then empty end), (.cache | _read_input))
        ) catch empty;


    null | _read_input;
