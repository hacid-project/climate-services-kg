PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>

INSERT {
    GRAPH ?g {
        ?s ?property ?s
    }
}
WHERE {
    GRAPH ?g {
        ?s a ?class
    }
    ?class rdfs:subClassOf+ [
        a owl:Restriction;
        owl:onProperty ?property;
        owl:hasSelf true
    ].
    ?class rdfs:label ?label.
  	FILTER NOT EXISTS {
        ?s ?property ?s
    }
};
