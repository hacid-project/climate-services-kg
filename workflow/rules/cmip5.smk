# Mapping of the CMIP5 datasets (ESGF search results, see
# data-sources/cmip5/query.txt, published on Zenodo) to JSON-LD with jq.
#
# The variables of the datasets are resolved to the MIP variables
# (data-sources/cmor-tables/mapping/mip-mapping.md) from their definitions in
# the CMIP5 CMOR tables.


rule cmip5:
    input:
        "data-sources/cmip5/rdf/datasets.jsonld",
        "data-sources/cmip5/rdf/variables.jsonld",


# Metadata of the CMIP5 datasets (https://doi.org/10.5281/zenodo.23363413)
rule cmip5_metadata:
    input:
        storage.zenodo("zenodo://record/23363413/cmip5.json.gz"),
    output:
        "data-sources/cmip5/data/cmip5.json",
    shell:
        "gunzip -c {input:q} > {output:q}"


rule cmip5_map_datasets:
    input:
        datasets="data-sources/cmip5/data/cmip5.json",
        mapping="data-sources/cmip5/mapping/datasets.jq",
        model_variables="data-sources/cmip5/mapping/variables.json",
        mip_index="data-sources/cmor-tables/data/mip-mapping-index.json",
        cmor_tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmip5"]["cmor_tables"],
        ),
        modules=[
            "data-sources/cmip5/mapping/esgf.jq",
            "data-sources/cmip5/mapping/cmip5-datasets.jq",
            "data-sources/cmor-tables/mapping/variables-jsonld.jq",
            "data-sources/cmor-tables/mapping/mip-variables.jq",
            "data-sources/cmor-tables/mapping/mip-mapping.json",
        ],
    output:
        "data-sources/cmip5/rdf/datasets.jsonld",
    log:
        "logs/cmip5/map_datasets.log",
    shell:
        "jq -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile cmor_tables {input.cmor_tables:q} --slurpfile mip_index {input.mip_index:q}"
        " --slurpfile model_variables {input.model_variables:q}"
        " -f {input.mapping:q} {input.datasets:q} > {output:q} 2> {log:q}"


# Variables defined locally for the models (mapping/variables.json)
rule cmip5_map_variables:
    input:
        variables="data-sources/cmip5/mapping/variables.json",
        mapping="data-sources/cmip5/mapping/variables.jq",
        cf_names="data-sources/cf-standard-names/data/standard-names.json",
        cf_fixes="data-sources/cmor-tables/mapping/cf-standard-name-fixes.json",
        modules=[
            "data-sources/cmip5/mapping/esgf.jq",
            "data-sources/cmor-tables/mapping/variables-jsonld.jq",
            "data-sources/cmor-tables/mapping/mip-variables.jq",
            "data-sources/cmor-tables/mapping/mip-mapping.json",
        ],
    output:
        "data-sources/cmip5/rdf/variables.jsonld",
    log:
        "logs/cmip5/map_variables.log",
    shell:
        "jq -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile cf_names {input.cf_names:q} --slurpfile cf_fixes {input.cf_fixes:q}"
        " -f {input.mapping:q} {input.variables:q} > {output:q} 2> {log:q}"
