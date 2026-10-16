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


# Modules of the mapping and of the analysis of the variables
CORDEX_CMIP5_MODULES = [
    "data-sources/cordex-cmip5/mapping/cordex-variables.jq",
    "data-sources/cmip5/mapping/esgf.jq",
    "data-sources/cmor-tables/mapping/mip-variables.jq",
    "data-sources/cmor-tables/mapping/mip-mapping.json",
]


rule cordex_cmip5_map_datasets:
    input:
        data="data-sources/cordex-cmip5/data",
        mapping="data-sources/cordex-cmip5/mapping/datasets.jq",
        model_synonyms="data-sources/cordex-cmip5/mapping/cmip5-model-synonyms.json",
        cmor_tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmip5"]["cmor_tables"],
        ),
        modules=CORDEX_CMIP5_MODULES,
    output:
        "data-sources/cordex-cmip5/rdf/datasets.jsonld",
    log:
        "logs/cordex_cmip5/map_datasets.log",
    shell:
        "jq -n -L data-sources/cordex-cmip5/mapping -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile model_synonyms {input.model_synonyms:q}"
        " --slurpfile cmor_tables {input.cmor_tables:q}"
        " -f {input.mapping:q} {input.data:q}/cordex-*.json > {output:q} 2> {log:q}"


# --- Variables requested by CORDEX


# The CORDEX standard output (the variables requested for the CORDEX archive,
# CORDEX_standard_output.xls) as JSON tables in the format of the CMOR tables,
# one per frequency
rule cordex_cmip5_standard_output:
    input:
        "data-sources/cordex-cmip5/CORDEX_standard_output.xls",
    output:
        "data-sources/cordex-cmip5/CORDEX_standard_output.json",
    log:
        "logs/cordex_cmip5/standard_output.log",
    script:
        "../scripts/cordex_standard_output.py"


# Check of the variables of the datasets against the standard output and the
# variables of the KG (see analysis/variables-check.jq), as JSON (summary and
# variables) and CSV (variables)
rule cordex_cmip5_variables_check:
    input:
        data="data-sources/cordex-cmip5/data",
        standard_output="data-sources/cordex-cmip5/CORDEX_standard_output.json",
        check="data-sources/cordex-cmip5/analysis/variables-check.jq",
        cmor_tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmip5"]["cmor_tables"],
        ),
        modules=CORDEX_CMIP5_MODULES,
        kg_variables=rules.cmor_tables.input,
    output:
        json="data-sources/cordex-cmip5/analysis/variables-check.json",
        csv="data-sources/cordex-cmip5/analysis/variables-check.csv",
    log:
        "logs/cordex_cmip5/variables_check.log",
    shell:
        "jq -n '[inputs | .[\"@graph\"][] | select(.[\"@type\"] | IN(\"data:Variable\", \"data:DeterministicVariable\")) | .[\"@id\"]] | unique'"
        " {input.kg_variables:q} > {output.json:q}.kg-variables.json 2> {log:q} &&"
        " jq -n -L data-sources/cordex-cmip5/mapping -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile standard_output {input.standard_output:q}"
        " --slurpfile cmor_tables {input.cmor_tables:q}"
        " --slurpfile kg_variables {output.json:q}.kg-variables.json"
        " -f {input.check:q} {input.data:q}/cordex-*.json > {output.json:q} 2>> {log:q} &&"
        " rm {output.json:q}.kg-variables.json &&"
        " jq -r '.variables | (.[0] | keys_unsorted) as $keys | ($keys | @csv), (.[] | [.[$keys[]]] | @csv)'"
        " {output.json:q} > {output.csv:q} 2>> {log:q}"
