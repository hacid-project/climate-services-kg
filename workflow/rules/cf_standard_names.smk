# Mapping of the CF standard name table (https://cfconventions.org/Data/cf-standard-names/)
# to JSON-LD with jq: a variable for each entry (rdf/standard-names.jsonld) and
# the aliases (rdf/aliases.jsonld).


rule cf_standard_names:
    input:
        "data-sources/cf-standard-names/rdf/standard-names.jsonld",
        "data-sources/cf-standard-names/rdf/aliases.jsonld",


# The table, in the version of config.yaml (cf_standard_names)
rule cf_standard_names_table:
    output:
        "data-sources/cf-standard-names/data/cf-standard-name-table.xml",
    params:
        url="{url}/{version}/src/cf-standard-name-table.xml".format(**config["cf_standard_names"]),
    shell:
        "curl -sSfL -o {output:q} {params.url:q}"


rule cf_standard_names_json:
    input:
        xml="data-sources/cf-standard-names/data/cf-standard-name-table.xml",
    output:
        json="data-sources/cf-standard-names/data/cf-standard-name-table.json",
    script:
        "../scripts/cf_standard_names_json.py"


rule cf_standard_names_map:
    input:
        table="data-sources/cf-standard-names/data/cf-standard-name-table.json",
        mapping="data-sources/cf-standard-names/mapping/{name}.jq",
    output:
        "data-sources/cf-standard-names/rdf/{name}.jsonld",
    wildcard_constraints:
        name="standard-names|aliases",
    log:
        "logs/cf_standard_names/map_{name}.log",
    shell:
        "jq -f {input.mapping:q} {input.table:q} > {output:q} 2> {log:q}"
