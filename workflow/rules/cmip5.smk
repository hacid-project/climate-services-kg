# Mapping of the CMIP5 datasets (ESGF search results, see
# data-sources/cmip5/query.txt) to JSON-LD with jq.
#
# The variables of the datasets are resolved to the MIP variables
# (data-sources/cmor-tables/mapping/mip-mapping.md) from their definitions in
# the CMIP5 CMOR tables.


rule cmip5:
    input:
        "data-sources/cmip5/rdf/datasets.jsonld",


rule cmip5_map_datasets:
    input:
        datasets="data-sources/cmip5/data/cmip5.json",
        mapping="data-sources/cmip5/mapping/datasets.jq",
        cmor_tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmip5"]["cmor_tables"],
        ),
        modules=[
            "data-sources/cmor-tables/mapping/variables-jsonld.jq",
            "data-sources/cmor-tables/mapping/mip-variables.jq",
            "data-sources/cmor-tables/mapping/mip-mapping.json",
        ],
    output:
        "data-sources/cmip5/rdf/datasets.jsonld",
    log:
        "logs/cmip5/map_datasets.log",
    shell:
        "jq -L data-sources/cmor-tables/mapping"
        " --slurpfile cmor_tables {input.cmor_tables:q}"
        " -f {input.mapping:q} {input.datasets:q} > {output:q} 2> {log:q}"
