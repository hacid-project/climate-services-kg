# Mapping of the CORDEX-CMIP5 datasets (ESGF search results, see
# data-sources/cordex-cmip5/download-data.sh, published on Zenodo) to JSON-LD
# with jq.


rule cordex_cmip5:
    input:
        "data-sources/cordex-cmip5/rdf/datasets.jsonld",


# Metadata of the CORDEX-CMIP5 datasets (https://doi.org/10.5281/zenodo.23364077):
# the pages of the ESGF search results, data/cordex-<n>.json (the archive also
# has macOS metadata files, ._*, which are skipped)
rule cordex_cmip5_metadata:
    input:
        storage.zenodo("zenodo://record/23364077/cordex-cmip5.tar.gz"),
    output:
        directory("data-sources/cordex-cmip5/data"),
    shell:
        "mkdir -p {output:q} &&"
        " tar -xzf {input:q} -C {output:q} --exclude='._*' --no-same-owner --warning=no-unknown-keyword"


rule cordex_cmip5_map_datasets:
    input:
        data="data-sources/cordex-cmip5/data",
        mapping="data-sources/cordex-cmip5/mapping/datasets.jq",
        model_synonyms="data-sources/cordex-cmip5/mapping/cmip5-model-synonyms.json",
        modules=[
            "data-sources/cmip5/mapping/esgf.jq",
            "data-sources/cmor-tables/mapping/mip-variables.jq",
            "data-sources/cmor-tables/mapping/mip-mapping.json",
        ],
    output:
        "data-sources/cordex-cmip5/rdf/datasets.jsonld",
    log:
        "logs/cordex_cmip5/map_datasets.log",
    shell:
        "jq -n -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile model_synonyms {input.model_synonyms:q}"
        " -f {input.mapping:q} {input.data:q}/cordex-*.json > {output:q} 2> {log:q}"
