# Mapping of the controlled vocabularies of the Met Office Hadley Centre
# (indices, hazards, methods, operations and the schemes of their values,
# data/*.json, kept in the repository as source) to JSON-LD with jq.

# Mapping (mapping/{name}.jq) of each source file (data/*.json)
MOHC_CVS = {
    "indices": "indices",
    "hazards": "hazards",
    "methods": "methods",
    "operations": "operations",
    "cvs": "cv-map",
}


rule mohc_cvs:
    input:
        expand("data-sources/mohc-cvs/rdf/{name}.jsonld", name=MOHC_CVS),


rule mohc_cvs_map:
    input:
        data=lambda wildcards: f"data-sources/mohc-cvs/data/{MOHC_CVS[wildcards.name]}.json",
        mapping="data-sources/mohc-cvs/mapping/{name}.jq",
        # schemes of the values of the operations
        cv_map="data-sources/mohc-cvs/data/cv-map.json",
    output:
        "data-sources/mohc-cvs/rdf/{name}.jsonld",
    wildcard_constraints:
        name="|".join(MOHC_CVS),
    log:
        "logs/mohc_cvs/map_{name}.log",
    shell:
        "jq --slurpfile cv_map {input.cv_map:q} -f {input.mapping:q} {input.data:q} > {output:q} 2> {log:q}"
