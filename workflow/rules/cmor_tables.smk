# Ingestion of variable definitions from multiple editions of the CMOR tables.
#
# Each edition of a source is checked out by its own git storage provider
# (in .snakemake/storage/<storage tag>/), then each of its tables is mapped:
#
#   checkout --(checkpoint)--> data/{source}/{edition}/tables.txt (table files)
#   [legacy CMOR 2 table --cmor2 to json--> data/{source}/{edition}/{table}.json]
#   CMOR 3 JSON table --map (jq)--> rdf/{source}/{edition}/{table}.jsonld

import glob
import os
import re

CMOR_TABLES_DIR = "data-sources/cmor-tables"
CMOR_TABLES_SOURCES = config["cmor_tables"]["sources"]


def cmor_tables_editions(source):
    """Editions of a source as a dict {name: git head (for custom_heads)}."""
    editions = {}
    for edition in CMOR_TABLES_SOURCES[source]["editions"]:
        if isinstance(edition, dict):
            head = {k: str(v) for k, v in edition.items() if k != "name"}
            editions[str(edition["name"])] = head
        else:
            editions[str(edition)] = {"tag": str(edition)}
    return editions


CMOR_TABLES_EDITIONS = {
    source: cmor_tables_editions(source) for source in CMOR_TABLES_SOURCES
}


def cmor_tables_storage_tag(source, edition):
    return re.sub(r"\W", "_", f"git_cmor_tables_{source}_{edition}")


# A git storage provider for each edition, checking out its own head
for source, editions in CMOR_TABLES_EDITIONS.items():
    for edition, head in editions.items():
        workflow.storage_registry.register_storage(
            provider="git",
            tag=cmor_tables_storage_tag(source, edition),
            keep_local=True,
            custom_heads={CMOR_TABLES_SOURCES[source]["repository"]: head},
        )


def cmor_tables_checkout(source, edition):
    """Storage object of the checkout of an edition (a directory)."""
    return getattr(storage, cmor_tables_storage_tag(source, edition))(
        CMOR_TABLES_SOURCES[source]["repository"]
    )


def cmor_tables_checkout_path(source, edition):
    """Local path of the checkout of an edition."""
    return str(cmor_tables_checkout(source, edition).flags["storage_object"].local_path())


def cmor_tables_table_names(source, edition):
    """Names of the tables of an edition (available after the checkpoint)."""
    with checkpoints.cmor_tables_list.get(source=source, edition=edition).output[0].open() as f:
        return [os.path.basename(line.strip()).removesuffix(".json") for line in f if line.strip()]


wildcard_constraints:
    source="|".join(CMOR_TABLES_SOURCES),
    edition="[^/]+",
    table="[^/]+",


rule cmor_tables:
    input:
        lambda wc: [
            f"{CMOR_TABLES_DIR}/rdf/{source}/{edition}/{table}.jsonld"
            for source, editions in CMOR_TABLES_EDITIONS.items()
            for edition in editions
            for table in cmor_tables_table_names(source, edition)
        ],


checkpoint cmor_tables_list:
    input:
        checkout=lambda wc: cmor_tables_checkout(wc.source, wc.edition),
    output:
        f"{CMOR_TABLES_DIR}/data/{{source}}/{{edition}}/tables.txt",
    params:
        tables=lambda wc: CMOR_TABLES_SOURCES[wc.source]["tables"],
    run:
        files = sorted(
            os.path.relpath(path, input.checkout)
            for path in glob.glob(os.path.join(input.checkout, params.tables))
        )
        with open(output[0], "w") as f:
            f.writelines(f"{file}\n" for file in files)


def cmor_tables_table_file(wc):
    """Path of a table file in the checkout of an edition."""
    tables_dir = os.path.dirname(CMOR_TABLES_SOURCES[wc.source]["tables"])
    extension = ".json" if CMOR_TABLES_SOURCES[wc.source]["format"] == "json" else ""
    return os.path.join(
        cmor_tables_checkout_path(wc.source, wc.edition),
        tables_dir,
        f"{wc.table}{extension}",
    )


rule cmor_tables_cmor2_to_json:
    input:
        table=cmor_tables_table_file,
        parser=f"{CMOR_TABLES_DIR}/mapping/cmor2-table.jq",
    output:
        f"{CMOR_TABLES_DIR}/data/{{source}}/{{edition}}/{{table}}.json",
    log:
        "logs/cmor_tables/cmor2_to_json/{source}/{edition}/{table}.log",
    shell:
        "jq -R -s -f {input.parser:q} {input.table:q} > {output:q} 2> {log:q}"


def cmor_tables_json_table(wc):
    """JSON (CMOR 3) version of a table: legacy CMOR 2 tables are converted."""
    if CMOR_TABLES_SOURCES[wc.source]["format"] == "cmor2":
        return f"{CMOR_TABLES_DIR}/data/{wc.source}/{wc.edition}/{wc.table}.json"
    return cmor_tables_table_file(wc)


rule cmor_tables_map_variables:
    input:
        table=cmor_tables_json_table,
        mapping=f"{CMOR_TABLES_DIR}/mapping/variables.jq",
    output:
        f"{CMOR_TABLES_DIR}/rdf/{{source}}/{{edition}}/{{table}}.jsonld",
    log:
        "logs/cmor_tables/map_variables/{source}/{edition}/{table}.log",
    shell:
        "jq -f {input.mapping:q} {input.table:q} > {output:q} 2> {log:q}"
