# Ingestion of variable definitions from multiple editions of the CMOR tables.
#
#   git repository (storage plugin) --extract--> data/{source}/{edition}.json
#                                   --map (jq)--> rdf/{source}/{edition}.jsonld

CMOR_TABLES_DIR = "data-sources/cmor-tables"
CMOR_TABLES_SOURCES = config["cmor_tables"]["sources"]


def cmor_tables_editions(source):
    """Editions of a source as a dict {name: git ref}."""
    editions = {}
    for edition in CMOR_TABLES_SOURCES[source]["editions"]:
        if isinstance(edition, dict):
            editions[str(edition["name"])] = str(edition["ref"])
        else:
            editions[str(edition)] = f"refs/tags/{edition}"
    return editions


CMOR_TABLES_EDITIONS = {
    source: cmor_tables_editions(source) for source in CMOR_TABLES_SOURCES
}


wildcard_constraints:
    source="|".join(CMOR_TABLES_SOURCES),
    edition="[^/]+",


rule cmor_tables:
    input:
        [
            f"{CMOR_TABLES_DIR}/rdf/{source}/{edition}.jsonld"
            for source, editions in CMOR_TABLES_EDITIONS.items()
            for edition in editions
        ],


rule cmor_tables_extract:
    input:
        # The whole clone of the repository (all editions are read from it)
        repo=lambda wc: storage.git(CMOR_TABLES_SOURCES[wc.source]["repository"]),
        cmor2_parser=f"{CMOR_TABLES_DIR}/mapping/cmor2-table.jq",
    output:
        f"{CMOR_TABLES_DIR}/data/{{source}}/{{edition}}.json",
    log:
        "logs/cmor_tables/extract/{source}/{edition}.log",
    params:
        repository=lambda wc: CMOR_TABLES_SOURCES[wc.source]["repository"],
        ref=lambda wc: CMOR_TABLES_EDITIONS[wc.source][wc.edition],
        format=lambda wc: CMOR_TABLES_SOURCES[wc.source]["format"],
        tables=lambda wc: CMOR_TABLES_SOURCES[wc.source]["tables"],
        script=f"{workflow.basedir}/scripts/extract-cmor-tables.sh",
    shell:
        "bash {params.script:q} {input.repo:q} {params.ref:q} {params.format:q}"
        " {params.tables:q} {input.cmor2_parser:q}"
        " {wildcards.source:q} {wildcards.edition:q} {params.repository:q}"
        " > {output:q} 2> {log:q}"


rule cmor_tables_map_variables:
    input:
        data=f"{CMOR_TABLES_DIR}/data/{{source}}/{{edition}}.json",
        mapping=f"{CMOR_TABLES_DIR}/mapping/variables.jq",
    output:
        f"{CMOR_TABLES_DIR}/rdf/{{source}}/{{edition}}.jsonld",
    log:
        "logs/cmor_tables/map_variables/{source}/{edition}.log",
    shell:
        "jq -f {input.mapping:q} {input.data:q} > {output:q} 2> {log:q}"
