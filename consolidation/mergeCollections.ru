PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/> 
PREFIX vars: <https://w3id.org/hacid/data/cs/variables/>

INSERT {
    GRAPH <https://w3id.org/hacid/data/cs/variables> {
        <https://w3id.org/hacid/data/cs/variables>
            a top:Collection;
            rdfs:label "Standard variables"@en;
            rdfs:comment "Collection of all the standard variables represented in this knowledge graph."@en;
            top:hasPart ?var_collection;
            top:hasMember ?var.
    }
}
WHERE {
    VALUES ?var_collection {vars:mip vars:CF}.
    ?var top:isMemberOf ?var_collection
};

INSERT {
    GRAPH <https://w3id.org/hacid/data/cs/indices> {
        <https://w3id.org/hacid/data/cs/indices>
            a top:Collection;
            rdfs:label "Standard indices"@en;
            rdfs:comment "Collection of all the standard indices represented in this knowledge graph."@en;
            top:hasPart ?index_collection;
            top:hasMember ?index.
    }
}
WHERE {
    VALUES ?index_collection {
        <https://w3id.org/hacid/data/cs/climdex/indices>
        <https://w3id.org/hacid/data/cs/Climate-ADAPT/indices>
        <https://w3id.org/hacid/data/cs/Copernicus-CCS/indices>
        <https://w3id.org/hacid/data/cs/ETCCDI/indices>
        <https://w3id.org/hacid/data/cs/UK-CRI/indices>
    }.
    ?index_collection top:hasMember ?index
};

