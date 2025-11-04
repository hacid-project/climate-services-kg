def to_camel_case:
    split(" ") |
    map((.[:1] | ascii_upcase) + (.[1:] | ascii_downcase)) |
    join("");

walk((
    select(.Name?) |
    (.Name | to_camel_case) as $hazard_id |
    ."@type" = "ccso:HazardType" |
    .Label = .Name |
    ."@id" = @uri "hazards:\($hazard_id)" |
    del(.Name)
) // .) |


{
    "@context": {
        rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        owl: "http://www.w3.org/2002/07/owl#",
        xsd: "http://www.w3.org/2001/XMLSchema#",
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
        ops: "https://w3id.org/hacid/data/cs/wf/ops/",
        hazards: "https://w3id.org/hacid/data/cs/hazard-types/",
        Id: "@id",
        Label: "rdfs:label",
        Description: "rdfs:comment",
        Specializations: "top:isSpecializedBy"
    },
    "@id": "hazards:ClimateHazardType",
    "@type": "ccso:HazardType",
    Label: "Climate hazard type",
    Specializations: .
}

