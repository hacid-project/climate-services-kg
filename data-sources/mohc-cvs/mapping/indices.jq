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
        label: "rdfs:label",
        comment: "rdfs:comment",
        acronym: "top:acronym",
        definition: "top:definition",
        hasUnitOfMeasure: {
            "@id": "top:hasUnitOfMeasure",
            "@type": "@id"
        },
        hasValuesOn: {
            "@id": "data:hasValuesOn",
            "@type": "@id"
        },
        dependsOnVariable: {
            "@id": "data:dependsOnVariable",
            "@type": "@id"
        },
        definesAggregation: {
            "@id": "data:definesAggregation",
            "@type": "@id"
        },
        aggregatesVariable: {
            "@id": "data:aggregatesVariable",
            "@type": "@id"
        },
        suggestedQuantization: {
            "@id": "data:hasSuggestedQuantization",
            "@type": "@id"
        },
        permitsTemporalResolution: {
            "@id": "ccso:permitsTemporalResolution",
            "@type": "@id"
        },
        basedOnVariable: {
            "@id": "data:derivedFromVariable",
            "@type": "@id"
        },
        generated: {
            "@reverse": "data:holdsSpecializationOfVariable"
        }
    },
    "@graph": [
        .[] |
        {
            "@id": @uri "index:\(.Name)",
            "@type": "data:DependentVariable",
            AssociatedVariable,
            rest: .
        }
    ]
}

