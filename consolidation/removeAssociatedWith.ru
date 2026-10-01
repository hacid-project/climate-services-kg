PREFIX top: <https://w3id.org/hacid/onto/top-level/> 

DELETE WHERE {
    GRAPH ?g {
        top:associatedWith ?p ?o
    }
};

DELETE WHERE {
    GRAPH ?g {
        ?s ?p top:associatedWith
    }
};
