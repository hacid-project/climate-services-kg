# Mapping of the CMIP5 datasets (ESGF search results, see
# data-sources/cmip5/query.txt) to JSON-LD with jq.


rule cmip5:
    input:
        "data-sources/cmip5/rdf/datasets.jsonld",


rule cmip5_map_datasets:
    input:
        datasets="data-sources/cmip5/data/cmip5.json",
        mapping="data-sources/cmip5/mapping/datasets.jq",
    output:
        "data-sources/cmip5/rdf/datasets.jsonld",
    log:
        "logs/cmip5/map_datasets.log",
    shell:
        "jq -f {input.mapping:q} {input.datasets:q} > {output:q} 2> {log:q}"
