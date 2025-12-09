PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

DELETE {
    GRAPH ?g {?s rdfs:label ?other_label}
}
WHERE {
  	{
		SELECT ?s (COUNT(1) AS ?num_labels) #(GROUP_CONCAT(?l; separator=",") AS ?labels)
		WHERE {
    		?s rdfs:label ?l.
  		FILTER(LANG(?l) = "en")
		}
		GROUP BY ?s
		HAVING (?num_labels > 1)
	}
  	OPTIONAL {
    	?s rdfs:label ?common_label.
    	FILTER NOT EXISTS {
      		?s rdfs:label ?non_derived_label.
      		FILTER(!STRSTARTS(?non_derived_label, ?common_label))
      		FILTER(!STRENDS(?non_derived_label, ?common_label))
    	}
        GRAPH ?g {?s rdfs:label ?other_label}.
    	FILTER(?other_label != ?common_label)
  	}
}

