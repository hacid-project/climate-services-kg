# climate-services-kg

Code and data used to populate the climate services knowledge graph for the HACID project

## Snakemake workflow

Parts of the ingestion are being moved to a [Snakemake](https://snakemake.github.io/) workflow
(`workflow/Snakefile`, configured in `config/config.yaml`).
It requires `git`, `jq` and the Python packages in `workflow/requirements.txt`:

```bash
pip install -r workflow/requirements.txt
snakemake --cores 4 mapping            # all the mappings to the KG (default target)
snakemake --cores 4 sources_analysis   # all the analyses of the sources
snakemake --cores 4 cmor_tables        # just the variables of the CMOR tables
```

### CMOR tables

Variable definitions are ingested from editions (git tags) of the CMOR tables
of each era, configured with the repository of its tables in `config/cmor-tables-eras.json`:
`cmip5` ([cmip5-cmor-tables](https://github.com/PCMDI/cmip5-cmor-tables)),
`cmip6` ([cmip6-cmor-tables](https://github.com/PCMDI/cmip6-cmor-tables)) and
`cmip6plus` ([mip-cmor-tables](https://github.com/PCMDI/mip-cmor-tables)),
each edition `{era}/{version}` checked out through the git storage plugin (in `.snakemake/storage/git/`)
and its tables collected in `data-sources/cmor-tables/data/{era}/{version}.json` (legacy CMOR 2
plain-text tables of CMIP5 being converted to JSON by `mapping/cmor2-tables.jq`).

The KG has the MIP variables, i.e. the variables of the current edition, and the previous
variables kept separate from them (see `data-sources/cmor-tables/mapping/mip-mapping.md`), so only
the current edition and the editions with previous variables are retrieved
(`snakemake --cores 4 cmor_tables`):

1. `data-sources/cmor-tables/rdf/current/{era}/{version}.jsonld`: all the variables of the
   current edition (`mapping/variables.jq`);
2. `data-sources/cmor-tables/rdf/previous/{era}/{version}.jsonld`: only the variables of the
   `keep`, `sign_change` and `unit_change` entries of each previous edition
   (`mapping/mip-previous-variables.jq`).

Changing a mapping reruns only the affected steps.

The evolution of the variable definitions across all the editions listed in `config/config.yaml` (additions, deletions,
modifications, names used for different quantities) is analysed in
`data-sources/cmor-tables/analysis/` (`snakemake --cores 4 cmor_tables_analysis`, see its README).

### CMIP5 datasets

The CMIP5 datasets found on ESGF (`data-sources/cmip5/data/cmip5.json`, see `query.txt`) are mapped
by `data-sources/cmip5/mapping/datasets.jq` to `data-sources/cmip5/rdf/datasets.jsonld`
(`snakemake --cores 4 cmip5`): datasets, simulation, ensemble and experiment outputs, simulations,
models and their spatial and temporal grids. The variables of the datasets are the MIP variables
resolved through `data-sources/cmor-tables/mapping/mip-mapping.json` from their definitions in the
CMIP5 CMOR tables (e.g. a CMIP5 `tos`, in K, is `.../variables/mip/cmip6/6.0.19/tos`).
