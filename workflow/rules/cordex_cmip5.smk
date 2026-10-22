# Mapping of the CORDEX-CMIP5 datasets (ESGF search results, see
# data-sources/cordex-cmip5/download-data.sh, published on Zenodo) to JSON-LD
# with jq.


rule cordex_cmip5:
    input:
        "data-sources/cordex-cmip5/rdf/datasets",
        "data-sources/cordex-cmip5/rdf/variables.jsonld",


# Metadata of the CORDEX-CMIP5 datasets (https://doi.org/10.5281/zenodo.23477951):
# the pages of the ESGF search results, data/cordex-<n>.json
rule cordex_cmip5_metadata:
    input:
        storage.zenodo("zenodo://record/23477951/cordex-cmip5.tar.gz"),
    output:
        directory("data-sources/cordex-cmip5/data"),
    shell:
        "mkdir -p {output:q} &&"
        " tar -xzf {input:q} -C {output:q} --no-same-owner"


# Modules of the mapping and of the analysis of the variables
CORDEX_CMIP5_MODULES = [
    "data-sources/cordex-cmip5/mapping/cordex-variables.jq",
    "data-sources/cmip5/mapping/esgf.jq",
    "data-sources/cmor-tables/mapping/mip-variables.jq",
    "data-sources/cmor-tables/mapping/mip-mapping.json",
]


# Datasets: each page of the search results (data/cordex-<n>.json) mapped on
# its own to a JSON-LD document, rdf/datasets/cordex-<n>.jsonld, to keep small
# the documents to load (the datasets in more than one page are mapped in each
# of them, with the same triples)
rule cordex_cmip5_map_datasets:
    input:
        data="data-sources/cordex-cmip5/data",
        mapping="data-sources/cordex-cmip5/mapping/datasets.jq",
        model_synonyms="data-sources/cordex-cmip5/mapping/cmip5-model-synonyms.json",
        cmor_tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmip5"]["cmor_tables"],
        ),
        standard_output="data-sources/cordex-cmip5/CORDEX_standard_output.json",
        kg_variables=rules.cmor_tables_variable_iris.output,
        mip_index="data-sources/cmor-tables/data/mip-mapping-index.json",
        data_issues="data-sources/cordex-cmip5/mapping/data-issues.json",
        level_variables="data-sources/cordex-cmip5/mapping/level-variables.json",
        modules=CORDEX_CMIP5_MODULES,
    output:
        directory("data-sources/cordex-cmip5/rdf/datasets"),
    log:
        "logs/cordex_cmip5/map_datasets.log",
    shell:
        "mkdir -p {output:q}; : > {log:q};"
        " for page in {input.data:q}/cordex-*.json; do"
        " jq -n -L data-sources/cordex-cmip5/mapping -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile model_synonyms {input.model_synonyms:q}"
        " --slurpfile cmor_tables {input.cmor_tables:q}"
        " --slurpfile standard_output {input.standard_output:q}"
        " --slurpfile kg_variables {input.kg_variables:q}"
        " --slurpfile mip_index {input.mip_index:q}"
        " --slurpfile data_issues {input.data_issues:q}"
        " --slurpfile level_variables {input.level_variables:q}"
        " -f {input.mapping:q} \"$page\" > {output:q}/$(basename \"$page\" .json).jsonld 2>> {log:q};"
        " done"


# Variables defined locally: the variables requested by CORDEX (standard
# output) that are not variables of the KG, mapped as those of the CMOR tables
# (with the long names of the variables at a single pressure level derived from
# the MIP variables)
rule cordex_cmip5_map_variables:
    input:
        mapping="data-sources/cordex-cmip5/mapping/variables.jq",
        standard_output="data-sources/cordex-cmip5/CORDEX_standard_output.json",
        cmor_tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmip5"]["cmor_tables"],
        ),
        kg_variables=rules.cmor_tables_variable_iris.output,
        data_issues="data-sources/cordex-cmip5/mapping/data-issues.json",
        level_variables="data-sources/cordex-cmip5/mapping/level-variables.json",
        cf_names="data-sources/cf-standard-names/data/standard-names.json",
        cf_fixes="data-sources/cmor-tables/mapping/cf-standard-name-fixes.json",
        # tables of the editions of the MIP variables, for the long names
        mip_tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=[MIP_EDITIONS["current"], *MIP_EDITIONS["previous"]],
        ),
        modules=CORDEX_CMIP5_MODULES + ["data-sources/cmor-tables/mapping/variables-jsonld.jq"],
    output:
        "data-sources/cordex-cmip5/rdf/variables.jsonld",
    log:
        "logs/cordex_cmip5/map_variables.log",
    shell:
        "jq -n -L data-sources/cordex-cmip5/mapping -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile standard_output {input.standard_output:q}"
        " --slurpfile cmor_tables {input.cmor_tables:q}"
        " --slurpfile kg_variables {input.kg_variables:q}"
        " --slurpfile data_issues {input.data_issues:q}"
        " --slurpfile level_variables {input.level_variables:q}"
        " --slurpfile cf_names {input.cf_names:q} --slurpfile cf_fixes {input.cf_fixes:q}"
        " -f {input.mapping:q} {input.mip_tables:q} > {output:q} 2> {log:q}"


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
        kg_variables=rules.cmor_tables_variable_iris.output,
        data_issues="data-sources/cordex-cmip5/mapping/data-issues.json",
        level_variables="data-sources/cordex-cmip5/mapping/level-variables.json",
    output:
        json="data-sources/cordex-cmip5/analysis/variables-check.json",
        csv="data-sources/cordex-cmip5/analysis/variables-check.csv",
    log:
        "logs/cordex_cmip5/variables_check.log",
    shell:
        "jq -n -L data-sources/cordex-cmip5/mapping -L data-sources/cmip5/mapping -L data-sources/cmor-tables/mapping"
        " --slurpfile standard_output {input.standard_output:q}"
        " --slurpfile cmor_tables {input.cmor_tables:q}"
        " --slurpfile kg_variables {input.kg_variables:q}"
        " --slurpfile data_issues {input.data_issues:q}"
        " --slurpfile level_variables {input.level_variables:q}"
        " -f {input.check:q} {input.data:q}/cordex-*.json > {output.json:q} 2> {log:q} &&"
        " jq -r '.variables | (.[0] | keys_unsorted) as $keys | ($keys | @csv), (.[] | [.[$keys[]]] | @csv)'"
        " {output.json:q} > {output.csv:q} 2>> {log:q}"
