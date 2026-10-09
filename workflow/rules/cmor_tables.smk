# Ingestion of variable definitions from multiple editions of the CMOR tables.
#
# Each edition is checked out through the git storage plugin, its tables are
# collected in data/{source}/{edition}.json (legacy CMOR 2 tables converted to
# JSON) and mapped with jq to rdf/{source}/{edition}.jsonld.
#
# The evolution of the variable definitions across the editions is analysed in
# analysis/ (see analysis/README.md).


wildcard_constraints:
    source="[^/]+",
    edition="[^/]+",


rule cmor_tables:
    input:
        expand(
            "data-sources/cmor-tables/rdf/{edition}.jsonld",
            edition=config["cmor_tables"]["editions"],
        ),


# Legacy CMOR 2 tables (CMIP5)
rule cmor_tables_cmor2:
    input:
        checkout=storage.git("https://github.com/PCMDI/{source}-cmor-tables.git#{edition}"),
        parser="data-sources/cmor-tables/mapping/cmor2-tables.jq",
    output:
        "data-sources/cmor-tables/data/{source}/{edition}.json",
    wildcard_constraints:
        source="cmip5",
    log:
        "logs/cmor_tables/cmor2/{source}/{edition}.log",
    shell:
        "jq -R -n -f {input.parser:q} {input.checkout:q}/Tables/CMIP5_* > {output:q} 2> {log:q}"


# CMOR 3 JSON tables
rule cmor_tables_json:
    input:
        checkout=storage.git("https://github.com/PCMDI/{source}-cmor-tables.git#{edition}"),
    output:
        "data-sources/cmor-tables/data/{source}/{edition}.json",
    log:
        "logs/cmor_tables/json/{source}/{edition}.log",
    shell:
        "jq -s . {input.checkout:q}/Tables/*.json > {output:q} 2> {log:q}"


ruleorder: cmor_tables_cmor2 > cmor_tables_json


rule cmor_tables_map_variables:
    input:
        tables="data-sources/cmor-tables/data/{source}/{edition}.json",
        mapping="data-sources/cmor-tables/mapping/variables.jq",
    output:
        "data-sources/cmor-tables/rdf/{source}/{edition}.jsonld",
    log:
        "logs/cmor_tables/map_variables/{source}/{edition}.log",
    shell:
        "jq -f {input.mapping:q} {input.tables:q} > {output:q} 2> {log:q}"


# --- Analysis of the evolution of the variable definitions


# Commit, date, ancestors (to order the editions) and, for mip-cmor-tables,
# CMIP6 provenance of the entries
rule cmor_tables_edition_info:
    input:
        checkout=storage.git("https://github.com/PCMDI/{source}-cmor-tables.git#{edition}"),
    output:
        "data-sources/cmor-tables/data/{source}/{edition}/info.json",
    log:
        "logs/cmor_tables/edition_info/{source}/{edition}.log",
    script:
        "../scripts/cmor_tables_edition_info.py"


rule cmor_tables_analysis:
    input:
        tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmor_tables"]["editions"],
        ),
        info=expand(
            "data-sources/cmor-tables/data/{edition}/info.json",
            edition=config["cmor_tables"]["editions"],
        ),
        cf_table="data-sources/cf-standard-names/data/skip/cf-standard-name-table.xml",
    output:
        steps="data-sources/cmor-tables/analysis/release-steps.csv",
        deletions="data-sources/cmor-tables/analysis/deletions.csv",
        standard_name_changes="data-sources/cmor-tables/analysis/standard-name-changes.csv",
        same_name_different_quantity="data-sources/cmor-tables/analysis/same-name-different-quantity.csv",
        same_name_different_units="data-sources/cmor-tables/analysis/same-name-different-units.csv",
        repository_transitions="data-sources/cmor-tables/analysis/repository-transitions.csv",
        summary="data-sources/cmor-tables/analysis/summary.json",
    params:
        editions=config["cmor_tables"]["editions"],
    log:
        "logs/cmor_tables/analysis.log",
    script:
        "../scripts/cmor_tables_analysis.py"
