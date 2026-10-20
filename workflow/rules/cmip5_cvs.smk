# Mapping of the controlled vocabularies of CMIP5 (experiments and
# institutions, data/*.csv, kept in the repository as source) to JSON-LD with
# jq.

# Source files of each vocabulary: the institutions of the CMIP5 datasets
# missing from institutions.csv are added in institutions-added.csv
CMIP5_CVS = {
    "experiments": ["experiments.csv"],
    "institutions": ["institutions.csv", "institutions-added.csv"],
}


rule cmip5_cvs:
    input:
        expand("data-sources/cmip5-cvs/rdf/{name}.jsonld", name=CMIP5_CVS),


# Concatenation of the source files by csvstack and conversion to JSON by
# csvjson (of the Python package csvkit), without type inference, and mapping
rule cmip5_cvs_map:
    input:
        data=lambda wildcards: [f"data-sources/cmip5-cvs/data/{f}" for f in CMIP5_CVS[wildcards.name]],
        mapping="data-sources/cmip5-cvs/mapping/{name}.jq",
    output:
        "data-sources/cmip5-cvs/rdf/{name}.jsonld",
    wildcard_constraints:
        name="|".join(CMIP5_CVS),
    log:
        "logs/cmip5_cvs/map_{name}.log",
    shell:
        "(csvstack {input.data:q} | csvjson --no-inference | jq -f {input.mapping:q}) > {output:q} 2> {log:q}"
