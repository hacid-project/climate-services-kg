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

The metadata of the CMIP5 datasets found on ESGF (see `query.txt`) is downloaded from Zenodo
([10.5281/zenodo.23363413](https://doi.org/10.5281/zenodo.23363413)) through the Zenodo storage plugin
to `data-sources/cmip5/data/cmip5.json` and mapped by `data-sources/cmip5/mapping/datasets.jq` to `data-sources/cmip5/rdf/datasets.jsonld`
(`snakemake --cores 4 cmip5`): datasets, simulation, ensemble and experiment outputs, simulations,
models and their spatial and temporal grids. The variables of the datasets are the MIP variables
resolved through `data-sources/cmor-tables/mapping/mip-mapping.json` from their definitions in the
CMIP5 CMOR tables (e.g. a CMIP5 `tos`, in K, is `.../variables/mip/cmip6/6.0.19/tos`).

### CORDEX-CMIP5 datasets

The metadata of the CORDEX-CMIP5 datasets found on ESGF (see `download-data.sh`), in pages of the search results, is
downloaded from Zenodo ([10.5281/zenodo.23364077](https://doi.org/10.5281/zenodo.23364077)) through the Zenodo
storage plugin to `data-sources/cordex-cmip5/data/cordex-<n>.json` and mapped by
`data-sources/cordex-cmip5/mapping/datasets.jq` to `data-sources/cordex-cmip5/rdf/datasets.jsonld`
(`snakemake --cores 4 cordex_cmip5`): datasets, the outputs of their simulations, driving ensembles, ensembles,
experiments and domains, the simulations (downscalings of the CMIP5 simulations of the driving models), the regional
models and the spatial (CORDEX domain) and temporal grids. The driving models are normalised to the CMIP5 model names
(`mapping/cmip5-model-synonyms.json`), also in the dataset ids. The variables of the datasets are the MIP variables
resolved, as for CMIP5, from their definitions in the CMIP5 CMOR tables of their time frequency (e.g. a CORDEX `sic`
is `.../variables/mip/siconc`); the CORDEX variables not in the CMOR tables (e.g. `ta200`, `ua100m`, `pr-bc`) keep the
IRI `.../variables/mip/<variable>`, which is not a variable of the KG.

The variables requested for the CORDEX archive (`data-sources/cordex-cmip5/CORDEX_standard_output.xls`, the CORDEX
standard output) are converted to JSON tables in the format of the CMOR tables, one per frequency
(`CORDEX_standard_output.json`, rule `cordex_cmip5_standard_output`), and the variables of the datasets are checked
against them and against the variables of the KG in `data-sources/cordex-cmip5/analysis/variables-check.json` (summary
and variables) and `.csv` (`snakemake --cores 4 cordex_cmip5_variables_check`, part of `sources_analysis`): for each
variable and time frequency, the number of datasets, whether it is requested at that frequency, the units and standard
names of the standard output and those found in the datasets, and the resolved MIP variable.

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
   The UKCP18 variables not defined in the CMOR tables are defined in `https://w3id.org/hacid/data/cs/variables/ukcp/`:
   - each `<variable>Anom` with respect to a baseline period is an anomaly (`data:isAnomalyOf`) of the MIP variable
     `<variable>`, `.../ukcp/<variable>Anom/<start year>-<end year>` (e.g. `.../ukcp/tasAnom/1981-2000`), with its
     baseline period (`data:hasBaselineRegion`, a `data:TemporalRegion`, without representing the baseline variable);
     it is a `data:RelativeAnomaly` for a percentage change (`prAnom`, `cltAnom`, `hussAnom`), otherwise a
     `data:AbsoluteAnomaly`;
   - the indices (`jetlat`, `jetstr`, `naodjf`, `wtype8`, `wtype30`) and `pr1day`, `pr5day` are derived
     (`data:derivedFromVariable`) from the MIP variables `ua`, `psl` and `pr`;
   - the variables whose units differ from those of the MIP variable (e.g. `tas` in degC, `pr` in mm/day) have a local
     version, `.../ukcp/<variable>/<units>`, with its units, which is a linear transformation
     (`data:isLinearTransformationOf`) of the MIP variable if the units are convertible;
   - the return levels of the probabilistic datasets (land-prob) are variables,
     `.../ukcp/<variable>/<return period>` (e.g. `.../ukcp/tasmax/rp20`), derived from the base variable
     (`data:derivedFromVariable`). A return level is a form of aggregation and, like the others (min, max,
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
