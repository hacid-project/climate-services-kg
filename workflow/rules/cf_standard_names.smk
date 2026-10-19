# Mapping of the CF standard name table (https://cfconventions.org/Data/cf-standard-names/)
# to JSON-LD with jq: a variable for each entry and the aliases
# (rdf/standard-names.jsonld).


rule cf_standard_names:
    input:
        "data-sources/cf-standard-names/rdf/standard-names.jsonld",


# The table, in the version of config.yaml (cf_standard_names)
rule cf_standard_names_table:
    output:
        "data-sources/cf-standard-names/data/cf-standard-name-table.xml",
    params:
        url="{url}/{version}/src/cf-standard-name-table.xml".format(**config["cf_standard_names"]),
    shell:
        "curl -sSfL -o {output:q} {params.url:q}"


# Conversion to JSON by xq (of the Python package yq), with the conventions of
# xmltodict: attributes as "@" keys, text of the elements without attributes as
# strings, empty elements as null, repeated elements as arrays (entry and alias
# always)
rule cf_standard_names_json:
    input:
        "data-sources/cf-standard-names/data/cf-standard-name-table.xml",
    output:
        "data-sources/cf-standard-names/data/cf-standard-name-table.json",
    shell:
        "xq --xml-force-list entry --xml-force-list alias . {input:q} > {output:q}"


rule cf_standard_names_map:
    input:
        table="data-sources/cf-standard-names/data/cf-standard-name-table.json",
        mapping="data-sources/cf-standard-names/mapping/standard-names.jq",
    output:
        "data-sources/cf-standard-names/rdf/standard-names.jsonld",
    log:
        "logs/cf_standard_names/map.log",
    shell:
        "jq -f {input.mapping:q} {input.table:q} > {output:q} 2> {log:q}"
