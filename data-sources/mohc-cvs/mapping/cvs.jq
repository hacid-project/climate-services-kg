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

def member_spec($scheme_id):
    {
        "@id": @uri "schemes:\($scheme_id)/\(.)",
        "@type": "top:Concept",
        label: .
    };

{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        schemes: "https://w3id.org/hacid/data/cs/wf/schemes/",
        label: "rdfs:label",
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
            {members: .members | map(member_spec($id))}
        elif .range then
            {
                members: [
                    . as $ctxt |
                    .range |
                    range(.min // 0; .max + (.step // 1); .step // 1) |
                    interpolate($ctxt.labelTemplate // "\\(.)") | 
                    member_spec($id)
                ]
            }
        end
    ]
}