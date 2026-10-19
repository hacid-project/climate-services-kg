# Mapping of the controlled vocabularies of CMIP5 (experiments and
# institutions, data/*.csv, kept in the repository as source) to JSON-LD with
# jq.

CMIP5_CVS = ["experiments", "institutions"]


rule cmip5_cvs:
    input:
        expand("data-sources/cmip5-cvs/rdf/{name}.jsonld", name=CMIP5_CVS),


# Conversion to JSON by csvjson (of the Python package csvkit), without type
# inference, and mapping
rule cmip5_cvs_map:
    input:
        data="data-sources/cmip5-cvs/data/{name}.csv",
        mapping="data-sources/cmip5-cvs/mapping/{name}.jq",
    output:
        "data-sources/cmip5-cvs/rdf/{name}.jsonld",
    wildcard_constraints:
        name="|".join(CMIP5_CVS),
    log:
        "logs/cmip5_cvs/map_{name}.log",
    shell:
        "(csvjson --no-inference {input.data:q} | jq -f {input.mapping:q}) > {output:q} 2> {log:q}"
