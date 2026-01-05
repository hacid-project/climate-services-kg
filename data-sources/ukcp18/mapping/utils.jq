def lpad($len; $fill):
    tostring | ($len - length) as $l | ($fill * $l)[:$l] + .;

def as_array:
    if type != "array" then [.] end;

def compact:
    if type == "object" then
        with_entries(
            .value |= (
                (as_array | map(compact)) as $compacted_array | 
                $compacted_array
            )
        )
    elif type == "array" then [.] end;

def mix_in($new_data):
    to_entries + ($new_data | to_entries) |
    group_by(.key) |
    map({key:.[0].key, value: map(.value)}) |
    from_entries;

def split_by(filter):
    group_by(filter) | map({key: .[0] | filter, value: map(del(filter))}) | from_entries;
