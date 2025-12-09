PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX top: <https://w3id.org/hacid/onto/top-level/> 

DELETE {
    GRAPH ?g {
        ?region ?p ?o
    }
}
WHERE {
    ?region a data:Region
    GRAPH ?g {
        ?region ?p ?o
    }
    FILTER NOT EXISTS {
        ?s ?p2 ?region
    }
};

DELETE {
    GRAPH ?g {
        ?point ?p ?o
    }
}
WHERE {
    ?point a data:Point
    GRAPH ?g {
        ?point ?p ?o
    }
    FILTER NOT EXISTS {
        ?s ?p2 ?point
    }
};
