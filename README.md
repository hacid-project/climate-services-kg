# climate-services-kg

Code and data used to populate the climate services knowledge graph for the HACID project

## Snakemake workflow

Parts of the ingestion are being moved to a [Snakemake](https://snakemake.github.io/) workflow
(`workflow/Snakefile`, configured in `config/config.yaml`).
It requires `git`, `jq` and the Python packages in `workflow/requirements.txt`:

```bash
pip install -r workflow/requirements.txt
snakemake --cores 4               # whole workflow
snakemake --cores 4 cmor_tables   # just the CMOR tables
```

### CMOR tables

Variable definitions are ingested from multiple editions (git tags) of the CMOR tables
repositories [cmip5-cmor-tables](https://github.com/PCMDI/cmip5-cmor-tables),
[cmip6-cmor-tables](https://github.com/PCMDI/cmip6-cmor-tables) and
[mip-cmor-tables](https://github.com/PCMDI/mip-cmor-tables),
each edition checked out through the git storage plugin (in `.snakemake/storage/git/`).
For each source and edition:

1. `data-sources/cmor-tables/data/{source}/{edition}.json`: all the tables of the edition,
   legacy CMIP5 plain-text tables being converted to JSON (`mapping/cmor2-tables.jq`);
2. `data-sources/cmor-tables/rdf/{source}/{edition}.jsonld`: the variables mapped to JSON-LD
   (`mapping/variables.jq`).

Editions are listed in `config/config.yaml`. Changing a mapping reruns only the affected steps.

The evolution of the variable definitions across the editions (additions, deletions,
modifications, names used for different quantities) is analysed in
`data-sources/cmor-tables/analysis/` (`snakemake --cores 4 cmor_tables_analysis`, see its README).
