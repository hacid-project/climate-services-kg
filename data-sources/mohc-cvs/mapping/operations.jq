def to_camel_case:
    split(" ") |
    map((.[:1] | ascii_upcase) + (.[1:] | ascii_downcase)) |
    join("");

def type_to_owl:
    if .type == "text" then
        {"@id": "xsd:string"}
    elif .type == "date" then
        {"@id": "xsd:date"}
    elif .type == "number" then
        {"@id": "xsd:decimal"}
    elif .type == "integer" then
        {"@id": "xsd:integer"}
    elif .type == "duration" then
        {"@id": "xsd:duration"}
    elif .type == "geodetic-region" then
        {
            "@id": "data:GeodeticRegion",
            "@type": "owl:Class"
        }
    elif .type == "range" then
        if .items.type == "uri" then
            {
                "@type": "owl:Class",
                "owl:intersectionOf":  [
                    {"@id": "top:Interval"},
                    {
                        "@type": "owl:Restriction",
                        "owl:onProperty": "top:hasBoundaryValue",
                        "owl:allValuesFrom": (.items | type_to_owl)
                    }
                ]
            }
        else 
            {
                "owl:intersectionOf":  [
                    {
                        "@type": "owl:Restriction",
                        "owl:onProperty": "owl:onDatatype",
                        "owl:allValuesFrom": (.items | type_to_owl)
                    },
                    {
                        "@type": "owl:Restriction",
                        "owl:onProperty": "owl:withRestrictions",
                        "owl:cardinality": 1
                    }
                ]
            }
        end
    elif .type == "range-or-exact" then
        {
            "@type": "owl:Class",
            "owl:unionOf":  [
                (.items | type_to_owl),
                (.type = "range" | type_to_owl)
            ]
        }
    else
        {src: ., "@type": "unknown"}
    end |
    if ."@type" | not then
        ."@type" = "rdfs:Datatype"
    end;

walk((
    select(.Name?) |
    (.Name | to_camel_case) as $op_id |
    ."@type" = "top:Operation" |
    .Label = .Name |
    ."@id" = @uri "ops:\($op_id)" |
    del(.Name) |
    if .AssociatedData then
        .InformationRoles = [{
            "@type": "top:OperationInformationRole",
            "@id": @uri "ops:\($op_id)/associated-data",
            ExpectedType: .AssociatedData | type_to_owl
        }] |
        del(.AssociatedData)
    end
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
        Id: "@id",
        Label: "rdfs:label",
        Description: "rdfs:comment",
        Specializations: "top:isSpecializedBy"
    },
    "@graph": .
}

