PREFIX owl: <http://www.w3.org/2002/07/owl#>

DELETE {
    GRAPH ?g {?alias ?p ?o}
}
INSERT {
    GRAPH ?g {?id ?p ?o}
}
WHERE {
  	?alias owl:sameAs ?id
	GRAPH ?g {?alias ?p ?o}
	FILTER(?p != owl:sameAs)
};

DELETE {
    GRAPH ?g {?s ?p ?alias}
}
INSERT {
    GRAPH ?g {?s ?p ?id}
}
WHERE {
  	?alias owl:sameAs ?id
	GRAPH ?g {?s ?p ?alias}
	FILTER(?p != owl:sameAs)
};

DELETE WHERE {
  	GRAPH ?g {?alias owl:sameAs ?id}
};
