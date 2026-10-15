# climate-services-kg

Code and data used to populate the climate services knowledge graph for the HACID project

## Snakemake workflow

Parts of the ingestion are being moved to a [Snakemake](https://snakemake.github.io/) workflow
(`workflow/Snakefile`, configured in `config/config.yaml`).
It requires `git`, `jq` (1.8, as the UKCP18 mapping uses its syntax) and the Python packages in
`workflow/requirements.txt`:

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

### UKCP18 datasets

The metadata of the UKCP18 datasets (from CEDA) is downloaded from Zenodo
([10.5281/zenodo.23362544](https://doi.org/10.5281/zenodo.23362544)) through the Zenodo storage plugin
and mapped by the jq programs in `data-sources/ukcp18/mapping` (`snakemake --cores 4 ukcp18`):

1. `rdf/spatial-grids.jsonld` and `data/spatial-grid-map.json`: the spatial grids of the UKCP18 resolutions;
2. `data/model-variants.json`: the variants of the models of the land-gcm datasets;
3. `rdf/ceda_ukcp18_metadata_merged.jsonld`: the datasets, with their simulations, models and grids
   (the datasets whose id does not match their metadata are listed in `logs/ukcp18/map_datasets.log`).
   Their variables are the MIP variables resolved through `data-sources/cmor-tables/mapping/mip-mapping.json`
   from the variable name (CMIP5 era), units and, for the land-gcm datasets, CMIP5 table (`mapping/ukcp18-variables.jq`).
   The UKCP18 variables not defined in the CMOR tables are defined in `https://w3id.org/hacid/data/cs/variables/ukcp/`
   (with the provisional terms of `data-sources/ontologies/provisional.ttl`):
   - each `<variable>Anom` is the anomaly (`ccso:isAnomalyOf`) of the MIP variable `<variable>`, or its relative
     anomaly (`ccso:isRelativeAnomalyOf`) for a percentage change (`prAnom`, `cltAnom`, `hussAnom`);
   - the indices (`jetlat`, `jetstr`, `naodjf`, `wtype8`, `wtype30`) and `pr1day`, `pr5day` are derived
     (`data:derivedFromVariable`) from the MIP variables `ua`, `psl` and `pr`;
   - the variables whose units differ from those of the MIP variable (e.g. `tas` in degC, `pr` in mm/day) have a local
     version, `.../ukcp/<variable>/<units>`, with its units, which is a linear transformation
     (`data:isLinearTransformationOf`) of the MIP variable if the units are convertible;
   - the return levels of the probabilistic datasets (land-prob) are variables,
     `.../ukcp/<variable>/<return period>` (e.g. `.../ukcp/tasmax/rp20`), specializations of the base variable
     (`data:isSpecializationOfVariable`). A return level is a form of aggregation and, like the others (min, max,
     mean, ...), is not represented in more detail for now (no specific class or return period property);
   - the variable of a probabilistic dataset is a distribution representation of its anomaly or return level
     (`data:isProbabilisticRepresentationOf`, without modelling the random version), `.../<variable>/pdf`, `cdf` or
     `sample`, a `data:ProbabilityDensityFunction`, `data:QuantileFunction` (the UKCP18 "cdf" datasets give the values
     at percentiles) or `data:Sample` with its units (e.g. degC-1 for a pdf); the datasets have the same type.

The datasets whose variable is not a variable of the KG (neither a MIP nor a previous variable, nor a UKCP18
variable linked to MIP variables of the KG) are
extracted, to review their mapping, in `data-sources/ukcp18/analysis/unmapped-variables.json.gz`
(part of `snakemake --cores 4 sources_analysis`).

The Zenodo plugin requires an access token, which is not needed for published records: a placeholder is
used unless `SNAKEMAKE_STORAGE_ZENODO_ACCESS_TOKEN` is set.
