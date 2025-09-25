{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        label: "rdfs:label",
        comment: "rdfs:comment",
        acronym: "top:acronym",
        isPartOf: {
            "@id": "top:isPartOf",
            "@type": "@id"
        }
    },
    "@graph": [
        {
            "@id": "https://w3id.org/hacid/data/cs/mips/cmip5",
            "@type": "top:Action",
            label: "CMIP5",
            comment: "Coupled Model Intercomparison Project Phase 5"
        },
        (
            .[] | {
                "@id": @uri "https://w3id.org/hacid/data/cs/mips/cmip5/experiments/\(.id)",
                "@type": ["ccso:EnsembleSimulation", "ccso:GlobalClimateSimulation"],
                acronym: .id,
                label: .description,
                isPartOf: "https://w3id.org/hacid/data/cs/mips/cmip5",
            }
        )
    ]
}
