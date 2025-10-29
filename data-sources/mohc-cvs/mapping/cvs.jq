def interpolate($str):
    . as $input |
    [$str | match("\\\\\\(([^)]+)\\)"; "g")] as $matches |
    [$matches.[].offset, $str | length] as $str_end |
    [0, ($matches.[] | .offset + .length)] as $str_start |
    [
        range($str_start | length) |
        $str[$str_start[.]:$str_end[.]]
    ] as $str_parts |
    [
        (
            range($str_parts | length - 1) |
            ($str_parts[.], $input)
        ),
        $str_parts[-1]
    ] | join("");

{
    "@context": {
        top: "https://w3id.org/hacid/onto/top-level/",
        schemes: "https://w3id.org/hacid/data/cs/wf/schemes/",
        members: {
            "@reverse": "top:inScheme",
            "@type": "@id"
        }
    },
    "@graph": [
        to_entries | .[].value.scheme | select(.id?) |
        .id as $id |
        {
            "@id": @uri "schemes:\($id)",
            "@type": "top:ConceptScheme"
        } +
        if .members then
            {members: .members | map(@uri "schemes:\($id)/\(.)")}
        elif .range then
            {
                members: [
                    . as $ctxt |
                    .range |
                    range(.min // 0; .max + (.step // 1); .step // 1) |
                    interpolate($ctxt.labelTemplate // "\\(.)") | 
                    @uri "schemes:\($id)/\(.)"
                ]
            }
        end
    ]
}