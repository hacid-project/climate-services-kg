"""Information about the checkout of an edition of the CMOR tables.

Writes a JSON document with the checked-out commit, its date, the commits it
descends from (to order the editions by git history) and, if the repository
has a MIP_variables.json (mip-cmor-tables), the CMIP6 provenance of its
variable entries.

Run by snakemake (rules cmor_tables_<era>_edition_info).
"""

import json
import os
from datetime import datetime, timezone

import pygit2


def provenance(checkout):
    """[[table, key, cmip6 table, cmip6 key], ...] from MIP_variables.json."""
    path = os.path.join(checkout, "MIP_variables.json")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        variables = json.load(f)
    # later versions wrap the variables, adding version metadata
    variables = variables.get("variables", variables)
    return sorted(
        [table, key, p["mip_table"], p["variable_name"]]
        for key, variable in variables.items()
        for table, table_variable in variable.get("tables", {}).items()
        if (p := table_variable.get("provenance", {}).get("CMIP6"))
    )


def edition_info(checkout, era, version):
    repo = pygit2.Repository(checkout)
    head = repo.head.peel(pygit2.Commit)
    return {
        "era": era,
        "version": version,
        "commit": str(head.id),
        "date": datetime.fromtimestamp(head.commit_time, timezone.utc).date().isoformat(),
        "ancestors": sorted(str(c.id) for c in repo.walk(head.id)),
        "provenance": provenance(checkout),
    }


if "snakemake" in globals():
    info = edition_info(
        snakemake.input.checkout,  # noqa: F821
        snakemake.params.era,  # noqa: F821
        snakemake.wildcards.version,  # noqa: F821
    )
    with open(snakemake.output[0], "w") as f:  # noqa: F821
        json.dump(info, f, indent=1)
