def id:
    if type == "object"
        then ."@id"
    end;

def unpack:
    [
        to_entries | .[] |
        .key as $key | .value | to_entries | .[] |
        .key as $value | .value | to_entries | .[] |
        .value |= {"@id": ., $key: $value}
    ] |
    from_entries;
