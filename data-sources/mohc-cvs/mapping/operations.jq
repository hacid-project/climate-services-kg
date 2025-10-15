def to_camel_case:
    split(" ") |
    map((.[:1] | ascii_upcase) + (.[1:] | ascii_downcase)) |
    join("");

walk((
    select(.Name?) |
    (.Label = .Name) |
    (.Id = (.Name | to_camel_case)) |
    del(.Name)
) // .) |

{
    "@context": {
        rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        data: "https://w3id.org/hacid/onto/data/",
        index: "https://w3id.org/hacid/data/cs/metoffice/indices/",
        sector: "https://w3id.org/hacid/data/cs/climdex/sectors/",
        parameter: "https://w3id.org/hacid/data/cs/climdex/parameters/",
        variable: "https://w3id.org/hacid/data/cs/variables/mip/",
        unit: "https://w3id.org/hacid/data/cs/unitsofmeasure/",
        dimension: "https://w3id.org/hacid/data/cs/dimensions/",
        aggregation: "https://w3id.org/hacid/data/cs/climdex/index-time-aggregations/",
        temporalgrid: "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/quantizations/",
        Id: "@id",
        Label: "rdfs:label",
        Description: "rdfs:comment",
        Specializations: "top:isSpecializedBy"
    },
    "@graph": .
}

