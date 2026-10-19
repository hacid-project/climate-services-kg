# Mapping of the climate indices of Climdex/Climpact to JSON-LD with jq: the
# indices (data/table.md, the table of the indices of the Climpact user guide)
# and their classification by sector (data/by-sector.json, curated from the
# Climdex page of the indices by sector), both kept in the repository as
# source. The units and time grids they use and that are defined nowhere else
# are in added-units.ttl and added-grids.ttl.


rule climdex:
    input:
        "data-sources/climdex/rdf/climdex.jsonld",
        "data-sources/climdex/rdf/climdex-sectors.jsonld",


# The indices, parsing the Markdown table (read as a raw string)
rule climdex_map_indices:
    input:
        table="data-sources/climdex/data/table.md",
        mapping="data-sources/climdex/mapping/climdex.jq",
    output:
        "data-sources/climdex/rdf/climdex.jsonld",
    log:
        "logs/climdex/map_indices.log",
    shell:
        "jq -R -s -f {input.mapping:q} {input.table:q} > {output:q} 2> {log:q}"


rule climdex_map_sectors:
    input:
        sectors="data-sources/climdex/data/by-sector.json",
        mapping="data-sources/climdex/mapping/by_sector.jq",
    output:
        "data-sources/climdex/rdf/climdex-sectors.jsonld",
    log:
        "logs/climdex/map_sectors.log",
    shell:
        "jq -f {input.mapping:q} {input.sectors:q} > {output:q} 2> {log:q}"
