{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        label: "rdfs:label",
        acronym: "top:acronym"
    },
    "@graph": [
        .[] | {
            "@id": @uri "https://w3id.org/hacid/data/cs/organizations/\(.id)",
            "@type": "top:Organization",
            acronym: .id,
            label: .description
        }
    ]
}
