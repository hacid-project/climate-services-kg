# Mapping of the CORDEX-CMIP5 domains and grids (domain tables of WCRP-CORDEX,
# https://github.com/WCRP-CORDEX/domain-tables) to JSON-LD with jq.


rule cordex_domains:
    input:
        "data-sources/cordex-domains/rdf/domains.jsonld",


# Conversion of a table of grids (rotated or regular) to JSON by csvjson (of
# the Python package csvkit), without type inference: an array of objects, one
# for each row, with the columns as keys and the values as strings (missing
# values as null)
rule cordex_domains_grids_json:
    input:
        checkout=storage.git("{repo}#{version}".format(**config["cordex_domains"])),
    output:
        "data-sources/cordex-domains/data/CORDEX-CMIP5_{grids}_grids.json",
    wildcard_constraints:
        grids="rotated|regular",
    shell:
        "csvjson --no-inference {input.checkout:q}/CORDEX-CMIP5_{wildcards.grids}_grids.csv > {output:q}"


# The rotated and the regular grids together, each with its type (rotated or
# regular) and the id of its domain (area_id, the first 3 characters of its
# domain_id, e.g. EUR)
rule cordex_domains_grids:
    input:
        rotated="data-sources/cordex-domains/data/CORDEX-CMIP5_rotated_grids.json",
        regular="data-sources/cordex-domains/data/CORDEX-CMIP5_regular_grids.json",
    output:
        "data-sources/cordex-domains/data/CORDEX-CMIP5.json",
    shell:
        "jq -n --slurpfile rotated {input.rotated:q} --slurpfile regular {input.regular:q}"
        " '[($rotated[0][] | {{type: \"rotated\"}} + .), ($regular[0][] | {{type: \"regular\"}} + .)]"
        " | map({{type, area_id: .domain_id[0:3]}} + .)' > {output:q}"


rule cordex_domains_map:
    input:
        grids="data-sources/cordex-domains/data/CORDEX-CMIP5.json",
        mapping="data-sources/cordex-domains/mapping/domains.jq",
    output:
        "data-sources/cordex-domains/rdf/domains.jsonld",
    log:
        "logs/cordex_domains/map.log",
    shell:
        "jq -f {input.mapping:q} {input.grids:q} > {output:q} 2> {log:q}"
