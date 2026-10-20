# Check of the institutions taken from the ESGF publisher configuration
# ($esgf, data/institutions-esgf.json) against the CSV files previously used
# (the input: their rows, with the file of each, from csvstack and csvjson).
#
# For each institution (by id, ignoring the case) its status:
# - same: same name in ESGF and in a CSV file;
# - different: different names;
# - only_esgf, only_csv: in one of the two only;
# and, for those in ESGF, the issues of its name:
# - no_name: no name found;
# - not_parsed: the name is a whole description, without "<model>, " (it may
#   be the name of a model or of a project);
# - other_candidates: other names from the lines of its models.

map(.file |= sub("^.*/"; "")) as $csv |
($esgf[0] | map({key: .id, value: .}) | from_entries) as $by_esgf |
($csv | map({key: (.id | ascii_upcase), value: .}) | from_entries) as $by_csv |
[($by_esgf | keys[]), ($by_csv | keys[])] | unique |
map(
    . as $id |
    $by_esgf[$id] as $e |
    $by_csv[$id] as $c |
    {
        id: $id,
        status: (
            if $e == null then "only_csv"
            elif $c == null then "only_esgf"
            elif $e.description == $c.description then "same"
            else "different"
            end
        ),
        esgf: (if $e then {acronym: $e.acronym, name: $e.description, models: $e.models} else null end),
        csv: (if $c then {file: $c.file, id: $c.id, name: $c.description} else null end),
        issues: (
            if $e == null then []
            else [
                (if $e.description == null then "no_name" else empty end),
                (if $e.candidates[0].parsed == false then "not_parsed" else empty end),
                (if ($e.candidates | length) > 1 then "other_candidates" else empty end)
            ]
            end
        ),
        other_candidates: (if $e then [$e.candidates[1:][].name] else [] end)
    } |
    with_entries(select(.value != null and .value != []))
) |
{
    summary: {
        status: (group_by(.status) | map({key: .[0].status, value: length}) | from_entries),
        issues: ([.[].issues // [] | .[]] | group_by(.) | map({key: .[0], value: length}) | from_entries)
    },
    institutions: .
}
