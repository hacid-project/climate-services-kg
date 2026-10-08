# Ingestion of variable definitions from multiple editions of the CMOR tables.
#
# Each edition is checked out through the git storage plugin, its tables are
# collected in data/{source}/{edition}.json (legacy CMOR 2 tables converted to
# JSON) and mapped with jq to rdf/{source}/{edition}.jsonld.


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
