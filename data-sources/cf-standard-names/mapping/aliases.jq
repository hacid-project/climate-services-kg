{
    "@context": {
        owl: "http://www.w3.org/2002/07/owl#",
        cf: "https://w3id.org/hacid/data/cs/variables/cf/",
        top: "https://w3id.org/hacid/onto/top-level/"
    },
    "@graph": .standard_name_table.alias | map({
        "@id": "cf:\(.id)",
        "owl:sameAs": {
            "@id": "cf:\(.entry_id)",
            "top:altLabel": .id
        }
    })
}