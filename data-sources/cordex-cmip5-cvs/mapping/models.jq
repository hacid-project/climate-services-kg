{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        label: "rdfs:label",
        comment: "rdfs:comment",
        acronym: "top:acronym",
        isMaintainedBy: {
            "@id": "ccso:isMaintainedBy",
            "@type": "@id"
        },
        isPartOf: {
            "@id": "top:isPartOf",
            "@type": "@id"
        }
    },
    "@graph": [
        .[] | {
            "@id": @uri "https://w3id.org/hacid/data/cs/models/\(.model_id)",
            "@type": "ccso:RegionalClimateModel",
            label: .model_id,
            isMaintainedBy: {
                "@id": @uri "https://w3id.org/hacid/data/cs/organizations/\(.institute_id)",
                acronym: .institute_id,
                label: .institute_name
            }
        }
    ]
}
