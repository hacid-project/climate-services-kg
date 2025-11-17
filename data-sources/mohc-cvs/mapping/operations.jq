import "./data/cv-map" as $cv_map_inputs;

$cv_map_inputs as [$cv_map_input] |

def to_camel_case:
    split("[ -/]";"g") |
    map((.[:1] | ascii_upcase) + (.[1:] | ascii_downcase)) |
    join("");

{
    text: "xsd:string",
    date: "xsd:date",
    number: "xsd:decimal",
    integer: "xsd:integer",
    duration: "xsd:duration"
} as $datatypes_map |

def cv_to_owl:
    if .class then
        {
            "@id": .class,
            "@type": "owl:Class"
        }
    elif .scheme then
        .scheme |
        (strings, (objects | @uri "schemes:\(.id)")) as $scheme_uri |
        {
            "@type": "owl:Restriction",
            onProperty: "top:inScheme",
            "owl:hasValue": $scheme_uri
        }
    elif .collection then
        .collection |
        (strings, (objects | @uri "collections:\(.id)")) as $collection_uri |
        {
            "@type": "owl:Restriction",
            onProperty: "top:isMemberOf",
            "owl:hasValue": {
                "@id": $collection_uri
            }
        }
    elif .union then
        {
            "@type": "owl:Class",
            unionOf: [.union[] | cv_to_owl]
        }
    else
        {src: ., "@type": "unknown-cv"}
    end;

def type_to_owl:
    if .type | in($datatypes_map) then
        {
            "@id": $datatypes_map[.type],
            "@type": "rdfs:Datatype"
        }
    elif .type == "geodetic-region" then
        {
            "@id": "data:GeodeticRegion",
            "@type": "owl:Class"
        }
    elif .type == "annually-recurring-interval" then
        {
            "@id": "data:AnnuallyRecurringInterval",
            "@type": "owl:Class"
        }
    elif .type == "range" then
        if .items.type == "uri" then
            {
                "@type": "owl:Class",
                intersectionOf:  [
                    "top:Interval",
                    {
                        "@type": "owl:Restriction",
                        onProperty: "top:hasBoundaryValue",
                        "owl:allValuesFrom": (.items | type_to_owl)
                    }
                ]
            }
        else 
            {
                intersectionOf:  [
                    {
                        "@type": "owl:Restriction",
                        onProperty: "owl:onDatatype",
                        "owl:allValuesFrom": (.items | type_to_owl)
                    },
                    {
                        "@type": "owl:Restriction",
                        onProperty: "owl:withRestrictions",
                        "owl:cardinality": 1
                    }
                ]
            }
        end
    elif .type == "range-or-exact" then
        {
            "@type": "owl:Class",
            unionOf:  [
                (.items | type_to_owl),
                (.type = "range" | type_to_owl)
            ]
        }
    elif .type == "uri" then
        $cv_map_input[.cv] | cv_to_owl
    else
        {src: ., "@type": "unknown-type"}
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
            "@type": "top:InformationRole",
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
        schemes: "https://w3id.org/hacid/data/cs/wf/schemes/",
        collections: "https://w3id.org/hacid/data/cs/wf/collections/",
        Id: "@id",
        Label: "rdfs:label",
        Description: "rdfs:comment",
        Specializations: "top:isSpecializedBy",
        ExpectedType: "top:hasExpectedType",
        InformationRoles: "top:definesRole",
        unionOf: {
            "@id": "owl:unionOf",
            "@type": "@id",
            "@container": "@list"
        },
        intersectionOf: {
            "@id": "owl:intersectionOf",
            "@type": "@id",
            "@container": "@list"
        },
        onProperty: {
            "@id": "owl:onProperty",
            "@type": "@id"
        }
    },
    "@id": "ops:CaseOperation",
    "@type": "top:Operation",
    Label: "Case operation",
    Specializations: [
        (.[] | select(."@id" == "ops:CreateCase")),
        {
            "@id": "ops:HandleCase",
            "@type": "top:Operation",
            Label: "Handle case",
            Specializations: [
                .[] | select(."@id" != "ops:CreateCase")
            ]
        }
    ]
}

