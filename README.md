# climate-services-kg

Code and data used to populate the climate services knowledge graph for the HACID project

## Snakemake workflow

The ingestion is a [Snakemake](https://snakemake.github.io/) workflow (`workflow/Snakefile`, configured in
`config/config.yaml`): every graph of the KG listed in `graph_names.csv` is either produced by the `mapping` target
or a file written by hand (`data-sources/*.ttl`, `data-sources/climdex/*.ttl`).
It requires `git`, `curl`, `jq` (1.8, as the UKCP18 mapping uses its syntax) and the Python packages in
`workflow/requirements.txt`:

```bash
pip install -r workflow/requirements.txt
snakemake --cores 4 mapping            # all the mappings to the KG (default target)
snakemake --cores 4 sources_analysis   # all the analyses of the sources
snakemake --cores 4 cmor_tables        # just the variables of the CMOR tables
snakemake --cores 4 consolidate        # the KG loaded, consolidated and exported (kg/)
```

The decisions taken for each data source on its issues, inconsistencies and conflicting versions (and the cases left
for further analysis) are documented in its `DECISIONS.md` (`data-sources/cf-standard-names`, `cmor-tables`, `cmip5`,
`cordex-domains`, `cordex-cmip5`, `ukcp18`, `mohc-cvs`, `climdex`, `cmip5-cvs`, `cordex-cmip5-cvs`).

### Consolidation

The rule `consolidate` (`workflow/rules/consolidate.smk`), run on the outputs of `mapping`, builds the KG with the
[Apache Jena](https://jena.apache.org/) command-line tools (which must be on the `PATH`), in three steps:

1. `consolidate_load`: the files of each graph listed in `graph_names.csv` (path or glob pattern, graph name, skip)
   are loaded into a new TDB2 dataset, `kg/tdb2` (`config/config.yaml`, `consolidate.location`; `kg/` is not
   tracked), with `tdb2.tdbloader` (`workflow/scripts/consolidate_load.py`, which writes the graphs and their files
   in `kg/load.json`);
2. `consolidate_updates`: the SPARQL updates listed in `consolidation_updates.csv` (in `consolidation/`) are applied
   in their order with `tdb2.tdbupdate`, seeing the union of the named graphs as the default graph;
3. `consolidate_export`: the dataset is exported as N-Quads, `kg/export/kg.nq.gz`, with `tdb2.tdbdump`.

The JVM options of the tools are in `config/config.yaml` (`consolidate.jvm_args`, `-Xmx16G`: the JSON-LD parser of
Jena reads a whole document in memory, and the UKCP18 datasets are about 1.8 GB). To inspect it, `./serve_kg.sh`
serves the dataset read-only with Fuseki (`fuseki-server` must be on the `PATH`) at `http://localhost:3030/kg`
(SPARQL endpoint `/kg/sparql`), with the union of the named graphs as the default graph (other location as first
argument, further options for `fuseki-server` after it, e.g. `./serve_kg.sh kg/tdb2 --port=3031`; not while the
workflow is writing the dataset). The dataset can also be served by a Fuseki installation pointing its configuration
(`fuseki-conf.ttl`, installed by `setup_kg.sh`) to its location.

### Ontologies

The HACID ontologies used by the KG (`top-level`, `data`, `ccso`) are taken from their repository
([hacid-project/knowledge-graph](https://github.com/hacid-project/knowledge-graph), `ontologies/{name}/{name}.owl`),
at the commit of `config/config.yaml` (`ontologies`), through the git storage plugin, to
`data-sources/ontologies/{name}.owl` (`snakemake --cores 4 ontologies`).

### Global warming levels

The global warming levels (1.5 to 6 °C, by 0.5 °C) are generated with jq (`data-sources/gwls/mapping/gwls.jq`,
without input) to `data-sources/gwls/rdf/gwls.jsonld` (`snakemake --cores 4 gwls`).

### CF standard names

The [CF standard name table](https://cfconventions.org/Data/cf-standard-names/), in the version of
`config/config.yaml` (`cf_standard_names`), is downloaded as XML
(`data-sources/cf-standard-names/data/cf-standard-name-table.xml`), converted to JSON by `xq` (of the Python
package `yq`, with the conventions of [xmltodict](https://github.com/martinblech/xmltodict)) and mapped with jq (`mapping/standard-names.jq`,
`snakemake --cores 4 cf_standard_names`) to `data-sources/cf-standard-names/rdf/standard-names.jsonld`: a
variable for each entry, member of the CF variables, with its units of measure, and the aliases, the same as
(`owl:sameAs`) their entries, with the alias as alternative label.

The XML is also read by the analysis of the CMOR tables (to resolve the aliases).

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

### CMIP5 experiments and institutions

The CMIP5 experiments and institutions are taken from the configuration of the ESGF publisher
([ESGF/config](https://github.com/ESGF/config), through the git storage plugin), parsed in jq
(`data-sources/cmip5-cvs/mapping/esgf-config.jq`): the experiments from the map of their descriptions in
`esg.cmip5.ini`, the institutions joining its institute map with the models table, with some fixes
(`mapping/institution-fixes.json`). They are mapped to `data-sources/cmip5-cvs/rdf/experiments.jsonld` and
`institutions.jsonld` (`snakemake --cores 4 cmip5_cvs`). See `DECISIONS.md`.

### CMIP5 datasets

The metadata of the CMIP5 datasets found on ESGF (see `query.txt`) is downloaded from Zenodo
([10.5281/zenodo.23363413](https://doi.org/10.5281/zenodo.23363413)) through the Zenodo storage plugin
to `data-sources/cmip5/data/cmip5.json` and mapped by `data-sources/cmip5/mapping/datasets.jq` to `data-sources/cmip5/rdf/datasets.jsonld`
(`snakemake --cores 4 cmip5`): datasets, simulation, ensemble and experiment outputs, simulations,
models and their spatial and temporal grids. The variables of the datasets are the MIP variables
resolved through `data-sources/cmor-tables/mapping/mip-mapping.json` from their definitions in the
CMIP5 CMOR tables (e.g. a CMIP5 `tos`, in K, is `.../variables/mip/cmip6/6.0.19/tos`).

### CORDEX-CMIP5 domains and grids

The tables of the CORDEX-CMIP5 grids, rotated and regular, are read from the
[domain tables](https://github.com/WCRP-CORDEX/domain-tables) of WCRP-CORDEX, at the commit of
`config/config.yaml` (`cordex_domains`), through the git storage plugin. Each is converted to JSON by `csvjson`
(of the Python package `csvkit`), the two are merged in `data-sources/cordex-domains/data/CORDEX-CMIP5.json` and
mapped with jq (`mapping/domains.jq`, `snakemake --cores 4 cordex_domains`) to
`data-sources/cordex-domains/rdf/domains.jsonld`: the domains, the grids (dimensional spaces) with their resolution,
bounding regions and specializations, and the rotated dimensional spaces with their poles.

### CORDEX RCMs

The CORDEX regional climate models, with their institutes, are taken from the list of IS-ENES Data
(`CORDEX_RCMs_info.txt` of [IS-ENES-Data.github.io](https://github.com/IS-ENES-Data/IS-ENES-Data.github.io), through
the git storage plugin), parsed in jq (`data-sources/cordex-cmip5-cvs/mapping/rcms-info.jq`) with some fixes
(`mapping/rcm-fixes.json`), and mapped to `data-sources/cordex-cmip5-cvs/rdf/models.jsonld`
(`snakemake --cores 4 cordex_cmip5_cvs`). See `DECISIONS.md`.

### CORDEX-CMIP5 datasets

The metadata of the CORDEX-CMIP5 datasets found on ESGF (see `download-data.sh`), in pages of the search results, is
downloaded from Zenodo ([10.5281/zenodo.23477951](https://doi.org/10.5281/zenodo.23477951)) through the Zenodo
storage plugin to `data-sources/cordex-cmip5/data/cordex-<n>.json` and mapped by
`data-sources/cordex-cmip5/mapping/datasets.jq` to `data-sources/cordex-cmip5/rdf/datasets.jsonld`
(`snakemake --cores 4 cordex_cmip5`): datasets, the outputs of their simulations, driving ensembles, ensembles,
experiments and domains, the simulations (downscalings of the CMIP5 simulations of the driving models), the regional
models and the spatial (CORDEX domain) and temporal grids. The driving models are normalised to the CMIP5 model names
(`mapping/cmip5-model-synonyms.json`), also in the dataset ids. The variables of the datasets are the MIP variables
resolved, as for CMIP5, from their definitions in the CMIP5 CMOR tables of their time frequency (e.g. a CORDEX `sic`
is `.../variables/mip/siconc`). The variables requested by CORDEX (see below) that are not variables of the KG (`ta200`,
`ua500`, `va500`, `zg200`, `sund`, `clh`, `cll`, `clm`, `wsgsmax`) are defined locally from the CORDEX standard output,
with the mapping of the CMOR tables (`variables_jsonld`), as `.../variables/cordex/<variable>` in
`data-sources/cordex-cmip5/rdf/variables.jsonld` (collection `.../variables/cordex`), with the long names of those at a
single pressure level derived from the analogous MIP variables (e.g. `ta200` is "Air Temperature at 200hPa", as `ta500`
on `p500`); the other variables not in the
CMOR tables (e.g. `ua100m`, `pr-bc`) keep the IRI `.../variables/mip/<variable>`, which is not a variable of the KG.

The variables requested for the CORDEX archive (`data-sources/cordex-cmip5/CORDEX_standard_output.xls`, the CORDEX
standard output) are converted to JSON tables in the format of the CMOR tables, one per frequency
(`CORDEX_standard_output.json`, rule `cordex_cmip5_standard_output`), and the variables of the datasets are checked
against them and against the variables of the KG in `data-sources/cordex-cmip5/analysis/variables-check.json` (summary
and variables) and `.csv` (`snakemake --cores 4 cordex_cmip5_variables_check`, part of `sources_analysis`): for each
variable and time frequency, the number of datasets, whether it is requested at that frequency, the units and standard
names of the standard output and those found in the datasets, and the resolved variable. The standard names found
are compared with those of the standard output and of the CMIP5 CMOR tables: other names in a minority of the datasets
are ignored, while other names in a majority of them (`standard_name_majority_other`) and different definitions
(`standard_name_definitions_differ`) are left for further analysis; the units are compared in a canonical form, so that
the same units written differently (e.g. `W/m2` for `W m-2`) are ignored, while different units (e.g. `K` for `m`,
`units_inconsistent`) are left for further analysis. The known issues of the datasets are in
`data-sources/cordex-cmip5/mapping/data-issues.json`: the datasets excluded from the mapping (`emiss` of the NARCliM
models, the surface emissivity, not the CMIP5 `emiss`) and the names known to be used in place of the CF standard names
(the clear-sky radiation fluxes of ALADIN63, `known_alias` in the check), the units known to be wrong (the
geopotential heights in K of RegCM4-3, the placeholder units of `ts` of CCAM-1704 and `prc` of RegCM4-7) and the
variables of a model with their own units (e.g. `pr` in mm and mm/month of BOM-SDM, the fractions in 1 instead of %,
`.../variables/cordex/<model>/<variable>/<units>`); see `data-sources/cordex-cmip5/DECISIONS.md`.

### UKCP18 datasets

The metadata of the UKCP18 datasets (from CEDA) is downloaded from Zenodo
([10.5281/zenodo.23362544](https://doi.org/10.5281/zenodo.23362544)) through the Zenodo storage plugin
and mapped by the jq programs in `data-sources/ukcp18/mapping` (`snakemake --cores 4 ukcp18`):

1. `rdf/spatial-grids.jsonld` and `data/spatial-grid-map.json`: the spatial grids of the UKCP18 resolutions;
2. `data/model-variants.json`: the variants of the models of the land-gcm datasets;
3. `rdf/variables.jsonld`: the local variables of the datasets (`https://w3id.org/hacid/data/cs/variables/ukcp/...`),
   with their units and baseline periods, generated from the specification `mapping/ukcp-variables.json` (see below);
4. `rdf/ceda_ukcp18_metadata_merged.jsonld`: the datasets, with their simulations, models and grids
   (the datasets whose id does not match their metadata are listed in `logs/ukcp18/map_datasets.log`).
   The variable of a dataset is its local variable according to `mapping/ukcp-variables.json`
   (`mapping/ukcp18-variables.jq`), otherwise the MIP variable resolved through
   `data-sources/cmor-tables/mapping/mip-mapping.json` from the variable name (CMIP5 era), units and, for the
   land-gcm datasets, CMIP5 table.

`mapping/ukcp-variables.json` is a compact specification of the local variables, maintained by hand: the UKCP18
variables, the MIP variables in other units, the anomaly variables with the baseline periods, the variables with return
levels with the return periods, and the distribution representations (see `data-sources/ukcp18/DECISIONS.md`). The
local variables are:
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
extracted, to review their mapping, in `data-sources/ukcp18/analysis/unmapped-variables.json.gz`, and the local
variables are checked against the datasets in `data-sources/ukcp18/analysis/variables-check.json` (the datasets of
each local variable, the local variables of no dataset, the datasets without a local variable whose units differ from
those of their MIP variable) (both part of `snakemake --cores 4 sources_analysis`).

The Zenodo plugin requires an access token, which is not needed for published records: a placeholder is
used unless `SNAKEMAKE_STORAGE_ZENODO_ACCESS_TOKEN` is set.

### Climdex/Climpact indices

The climate indices of [Climdex](https://www.climdex.org/learn/indices/) are taken from the table of the indices of
the [Climpact user guide](https://github.com/ARCCSS-extremes/climpact/blob/master/www/user_guide/Climpact_user_guide.md#appendix-a-tables-of-climpact-indices)
(`data-sources/climdex/data/table.md`), and their classification by sector from the
[Climdex page of the indices by sector](https://www.climdex.org/learn/indices/sector/), curated in
`data-sources/climdex/data/by-sector.json`. Both are kept in the repository as source (see `DECISIONS.md`) and mapped
with jq (`mapping/climdex.jq`, `mapping/by_sector.jq`, `snakemake --cores 4 climdex`) to
`data-sources/climdex/rdf/climdex.jsonld` and `climdex-sectors.jsonld`. The units and time grids they use that are
defined nowhere else are in `added-units.ttl` and `added-grids.ttl`.

### Met Office Hadley Centre controlled vocabularies

The controlled vocabularies of climate indices, hazards, methods and operations (tasks), with the schemes of
their values, are kept in the repository as source (`data-sources/mohc-cvs/data/*.json`) and mapped with jq
(`mapping/{name}.jq`, `snakemake --cores 4 mohc_cvs`) to `data-sources/mohc-cvs/rdf/{name}.jsonld`
(`indices`, `hazards`, `methods`, `operations`, `cvs`). The operations are also the input of
`for-hacid-dss/add-metadata.sh`.
