{
    "@context": {
        rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        gwl: "https://w3id.org/hacid/data/cs/GWLs/",
        label: "rdfs:label",
        comment: {
            "@id": "rdfs:comment",
            "@language": "en"
        },
        value: "rdf:value"
    },
    "@graph": [
        range(1.5;6.5;0.5) | {
            "@id": "gwl:GWL\(.)",
            "@type": "ccso:GlobalWarmingLevel",
            label: "GWL\(.)",
            comment: "Global warming level of \(.)°C, i.e. \(.)°C of global mean temperature increase compared to pre-industrial times (1871-1900)",
            value: .
        }
    ]
}