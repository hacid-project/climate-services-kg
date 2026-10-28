# UKCP18: decisions on issues and inconsistencies

Decisions taken in mapping the UKCP18 datasets (the CEDA metadata,
`data/ceda_ukcp18_metadata.jsonl`) to the KG, with the place where each
one is applied. The datasets whose variable is not a variable of the KG are
extracted for review in `analysis/unmapped-variables.json.gz` (currently none).

## Source data

- The metadata is published on Zenodo
  ([10.5281/zenodo.23515656](https://doi.org/10.5281/zenodo.23515656)), in
  JSON Lines (a dataset per line), with the same content as the previous
  version, a JSON array
  ([10.5281/zenodo.23362544](https://doi.org/10.5281/zenodo.23362544)): the
  datasets are read and mapped one at a time.
- **marine-sim.** The `marine-sim` collection is not mapped: each of its
  versions has its own id structure (`mapping/datasets.jq`).
- **Ids not matching the metadata: the id wins** (`mapping/datasets.jq`). The
  components of the id (scenario, collection, domain, resolution, frequency)
  are checked against the metadata, and the datasets whose id does not match
  are listed in `logs/ukcp18/map_datasets.log`. Those datasets were not
  mapped at all (no node, and no other IRI they were merged into): 45,694
  datasets, 814 of land-cpm, land-rcm and land-derived and 44,880 of
  EuroCORDEX. All the mismatches are in the resolution or in the frequency,
  and the id is right in all of them (it is the name of the file at CEDA, and
  agrees with the dates of the file and with the other datasets of the
  collection), so the dataset is now mapped with the resolution and frequency
  of its id (logged as "taken from the id"); a mismatch in the other
  components (none currently) still excludes the dataset (logged as "not
  mapped"):
  - **Climatologies without their period** (`ann-20y`, `seas-30y`, ... in the
    id, `ann`, `seas`, ... in the metadata): all the 20 and 30 year
    climatologies of EuroCORDEX (44,880: 7,480 for each of `ann-20y`,
    `ann-30y`, `mon-20y`, `mon-30y`, `seas-20y`, `seas-30y`) and 610 of
    land-derived (112 `ann-20y`, 224 `ann-30y`, 114 `seas-20y`, 160
    `seas-30y`, e.g.
    `sfcWind_rcp26_land-derived_uk_region_07_seas-30y_198012-201011.nc`). The
    other collections, and the other climatologies of land-derived, give the
    period in the frequency of the metadata as well.
  - **Monthly datasets with frequency `day`**: 132 of land-rcm, regional
    splits (`country`, `region`, `river`) of the CMIP5 driven members 23, 25,
    27 and 29 (e.g. `clt_rcp85_land-rcm_uk_country_23_mon_198012-208011.nc`):
    their dates (one file for 1980-2080) are those of the monthly datasets,
    while the daily ones are split by decade.
  - **Regional averages with the resolution of the grid**: 72 of land-cpm,
    `wsgmax10m` on the `country` and `river` splits (36 each, e.g.
    `wsgmax10m_rcp85_land-cpm_uk_country_01_day_19801201-20001130.nc`), with
    resolution `2.2km` (the grid they are computed from) in the metadata.

  All the datasets are now in the KG under their id: 263,911 of land-cpm,
  land-rcm and land-derived (previously 263,097) and 68,255 of EuroCORDEX
  (previously 23,375).

## Wrong or missing values (`mapping/ukcp18-ids.jq`)

- **Wrong variable.** Some datasets have a wrong variable in their metadata
  (`ensemble_member` in the EuroCORDEX datasets, `var__` for `evspsblveg`,
  `air_temperature` for `tasAnom`): the variable is taken from their id
  (`fix_variable`), and the units of `ensemble_member` are dropped.
- **Missing units.** Missing units (null or `None`) are those of the other
  datasets of the same collection and variable, all with the same units: 16
  variables of EuroCORDEX (13,159 datasets). They are listed in
  `mapping/missing-units.json` (`fix_units`), so that each dataset is mapped
  on its own (previously they were taken from the whole input).
- **CF names as variable names.** Some datasets name the variable by its CF
  standard name (`air_pressure_at_sea_level`, `subsurface_runoff_flux`), while
  their ids use the CMIP names: they are `psl` and `mrrob`
  (`_variable_renames` in `mapping/ukcp18-variables.jq`).

## Variables (`mapping/ukcp18-variables.jq`, `mapping/ukcp-variables.json`)

- **Local variables, generated from `mapping/ukcp-variables.json`.** The
  local variables of the datasets (`.../variables/ukcp/`) are generated from a
  compact specification maintained by hand, as
  `data-sources/cmor-tables/mapping/mip-mapping.json` for the MIP variables,
  not from the metadata of the datasets: the same specification gives their
  mapping to the KG (`mapping/variables.jq`, `rdf/variables.jsonld`) and the
  variable of each dataset (`variable_iri`). The ids are relative to
  `.../variables/ukcp/` and the variables they refer to are MIP variables
  (CMIP5 `out_name`s, resolved through `mip-mapping.json`) or local ones. The
  specification has:
  - `variables`: the UKCP18 variables not in the CMOR tables (id, `label`,
    `units`, the MIP variables they are `derived_from`), `<id>`, the variables
    of the datasets with that name;
  - `other_units`: the MIP variables used in other units (`label`, the
    `units`, each `linear` or not), `<variable>/<units>`, the variables of the
    datasets with that name and units;
  - `anomalies`: the anomaly variables (id, `anomaly_of`, `label`, `type`
    absolute or relative, `units`), the baseline periods (id, `label`, `start`
    and `end` year, the ids of the `datasets`, e.g. `b8100`), and the
    `distributions` of their probabilistic datasets: an anomaly for each
    variable and baseline, `<id>/<baseline>`, the variable of the datasets
    with that name and baseline period;
  - `return_levels`: the variables with return levels (local or MIP, with a
    `label` and `units` for the MIP ones), the return periods (id, `years`),
    and the `distributions` of their datasets: a return level for each
    variable and period, `<variable>/<period>`, derived from the variable;
  - `distributions`: the distribution representations (id, `label`, `type`,
    and `inverse_units` for the densities): for each anomaly or return level
    and each of its distributions, `<base>/<distribution>`, the variable of
    the probabilistic datasets (`prob_data_type`) of the base.

  The labels are generated from those of the specification (e.g. "Mean air
  temperature anomaly with respect to 1981-2000 (tasAnom, 1981-2000)",
  "Quantile function of maximum air temperature 20-year return level (tasmax,
  rp20, cdf)"). The specification was written to give the same variables (160,
  same triples) and the same variable for each dataset as the logic previously
  in `mapping/ukcp18-variables.jq` (deriving them from the metadata of the
  datasets, up to commit 1e72213). The check `analysis/variables-check.json`
  (`sources_analysis`) reports the datasets of each local variable, the local
  variables of no dataset, and the datasets without a local variable whose
  units are not those of their MIP variable (a local variable may be missing).
- **Resolution to the MIP variables.** The other datasets have the MIP
  variable of their variable name in the CMIP5 era (UKCP18 is based on CMIP5
  models), units and, for the land-gcm datasets, the CMIP5 table of the source
  data (`cmip5_table_id`).
- **The local variables** are:
  - **Indices** (`jetlat`, `jetstr`, `naodjf`, `wtype8`, `wtype30`) and
    `pr1day`, `pr5day`: derived (`data:derivedFromVariable`) from the MIP
    variables `ua`, `psl` and `pr`; `beta` (soil moisture stress factor) is
    defined without links.
  - **Anomalies** (`<variable>Anom`): one variable per baseline period,
    `.../ukcp/<variable>Anom/<start year>-<end year>`, a `data:AbsoluteAnomaly`
    or, for a percentage change, a `data:RelativeAnomaly` of the MIP variable
    (`data:isAnomalyOf`). The baseline period is linked with the shortcut
    `data:hasBaselineRegion` (the baseline variable, `data:hasBaseline`, is not
    represented), as an interval of calendar years (UKCP18 climatologies may use
    years from December to November). The baseline ids `b<start><end>` give the
    last two digits of the years (e.g. `b8100` is 1981-2000).
  - **Other units.** A variable whose units differ from those of the MIP
    variable (e.g. `tas` in degC) has a local version,
    `.../ukcp/<variable>/<units>`, linked by `data:isLinearTransformationOf` if
    the units are convertible (assuming the density of water for precipitation
    and snow, e.g. mm/day and kg m-2 s-1).
  - **Return levels** (land-prob, `rpN`): `.../ukcp/<variable>/rpN`, derived
    from the base variable (`data:derivedFromVariable`). A return level is a
    form of aggregation and, as the others (min, max, mean, ...), is not
    represented in more detail (no specific class or return period property).
  - **Probabilistic datasets** (land-prob): the variable of a dataset is a
    distribution representation of the previous variable
    (`data:isProbabilisticRepresentationOf`, without modelling the random
    version), `.../pdf`, `.../cdf` or `.../sample`. The UKCP18 "cdf" datasets
    give the values of the variable at percentiles (in the units of the
    variable), i.e. its quantile function: they are `data:QuantileFunction`
    (the IRI keeps `/cdf`). The datasets have the same type as their variable.
- **Labels.** The labels of the specification are the most common long names
  among the datasets of each variable, as previously chosen by the mapping
  (preferring the long names in plain words), except those that were not
  plain words: `beta` ("soil_moisture_stress_factor" in the datasets) is
  "Soil moisture stress factor", `flashrate` ("NUMBER OF LIGHTNING FLASHES")
  is "Number of lightning flashes".

## Simulations and lineage (`mapping/simulations.jq`, `mapping/context.jq`)

- **Links lost in the JSON-LD.** The keys `derived_from`, `input`,
  `is_rescaled_version_of` and `is_part_of` were not terms of the context, so
  they gave no triples (JSON-LD drops the undefined terms): the about 370,000
  datasets on the UK grids and regional splits (rescaled versions of an
  output) were not linked to the output they come from, and the derived
  projections and indices were not linked to their inputs. They are now terms
  of the context: `derived_from` as `data:derivedFromVariable`, `input` as
  `data:hasInput`, `is_rescaled_version_of` as the reverse of
  `data:hasRescaledVersion` and `is_part_of` as the reverse of
  `top:hasComponent` (a dataset is a variable, so the properties of the
  variables relate also datasets). The IRIs of the rescaled ensemble outputs
  (`is_part_of`) now have a `/` between the output and the grid (e.g.
  `.../ukcp18.global.rcp85/output/ukcp18/regional-splits/region`), and the
  inputs of the derived projections and indices are the outputs of the
  simulations (`data:hasInput` relates a process to a dataset), not the
  simulations.
- **CMIP5 members** (land-gcm, members 16 to 28, and the CMIP5 driven
  members of land-rcm and land-cpm, 23, 25, 27, 29). The UKCP18 global
  datasets of a CMIP5 member are derived from the CMIP5 data, regridded and
  joined: every dataset has `cmip5_experiment_id` `historical`, as the series
  join the historical run (from 1899) to the run of the scenario (from 2006).
  The output of a member is a UKCP18 dataset
  (`.../ukcp18/land-gcm/datasets/<scenario>.<member>`), output of a rescaling
  (`ccso:Rescaling`, `ccso:StatisticalProjectionTransformation`:
  `.../ukcp18/land-gcm/processing/<scenario>.<member>`) whose inputs are the
  outputs (product `output1`) of the CMIP5 historical run and of the run of
  the scenario, of which it is a rescaled version (`data:hasRescaledVersion`).
  It is a rescaling rather than an aggregation, as most CMIP5 grids are coarser
  than the 60 km grid of UKCP18; the means over time (monthly, seasonal,
  annual, 20 and 30 years) are aggregations, but the output of a member holds
  all the frequencies. The CMIP5 runs are members of the UKCP18 ensemble, and
  the regional members are downscalings of both. The nodes of the CMIP5 runs
  and of the model are given with the functions of
  `data-sources/cmip5/mapping/cmip5-datasets.jq`, so the runs missing from the
  CMIP5 search results (e.g. `CCSM4`, `bcc-csm1-1`) are in the KG.
- **CMIP5 runs that do not exist** (`_runs_not_in_cmip5`): `ACCESS1-3`,
  `CESM1-BGC`, `CMCC-CM` and `EC-EARTH` (`r1i1p1`) have no `rcp26` run in
  CMIP5: their `rcp26` datasets cover only the historical period (up to 2005,
  2009 for `EC-EARTH`, whose historical run goes up to 2012), so they are
  derived from the historical run alone.
- **Model ids.** The CMIP5 model ids are given by `cmip5_model_id` from the
  `cmip5_model_id` of the datasets (e.g. `ACCESS1.3`, `ACCESS1-3`); the
  extraction of the model variants (`mapping/extract-model-variants.jq`) no
  longer renames `bcc-csm1-1` to `BCC-CSM1-1`, which is not its CMIP5 id.
- **The regional model, HadREM3-GA7-05.** The regional simulations of UKCP18
  (land-rcm) used the model `.../models/HadREM3-GA705` (the name in the UKCP18
  metadata, "Met Office Unified Model Global Atmosphere GA7 model
  (HadREM3-GA705)"), while the CORDEX-CMIP5 EUR-11 simulations of MOHC (also
  members of the EuroCORDEX ensemble of UKCP18, `model_id`
  `MOHC-HadREM3-GA7-05`) use `.../models/HadREM3-GA7-05`. They are the same
  model, HadREM3 in the GA7.05 configuration: the UKCP18 regional projections
  (12 km, HadREM3-GA7-05 driven by HadGEM3-GC3.05 and by CMIP5 models) and the
  MOHC contribution to EURO-CORDEX come from the same model, registered in
  CORDEX as `HadREM3-GA7-05`. The regional simulations of UKCP18 now use
  `.../models/HadREM3-GA7-05`: `HadREM3-GA705` is a synonym of it in
  `data/cmip5-model-synonyms.json` (resolved by `normalize_model_id`), and the
  node of the model (`mapping/models.jq`) has the CORDEX name as label, the
  UKCP18 name in its comment, and MOHC as maintainer.
- **EuroCORDEX datasets.** They were linked to IRIs of CORDEX-CMIP5 datasets
  (`.../datasets/cordex.output.EUR-11.<institute>.<driving model>.rcp85.<ensemble>.<model>.<version>.<frequency>.<variable>`),
  but of frequencies (`ann`, `seas`) or variables (`rls`, `rss`) that CORDEX
  does not publish, or of simulations missing from the CORDEX search results:
  2,302 without a node. The datasets of a simulation, frequency and variable
  are now UKCP18 datasets (`.../ukcp18/EuroCORDEX/datasets/<that id>`), from
  the CORDEX-CMIP5 historical simulation and the one of the scenario (the
  datasets cover 1980 to 2080; product `output`), part of the output of the
  UKCP18 ensemble, of which the CORDEX-CMIP5 simulations are members:
  - the variables computed by UKCP18 (`rls`, `rss`, the net longwave and
    shortwave radiation): output of a `ccso:StatisticalProjectionTransformation`
    (also a `ccso:Aggregation` for the frequencies other than `day` and
    `mon`,
    `.../ukcp18/EuroCORDEX/processing/<that id>`) whose inputs are the outputs
    of the simulations, from which they are derived
    (`data:derivedFromVariable`);
  - the other variables, of the frequencies `ann` and `seas` and of the
    climatologies (`ann-20y`, `mon-30y`, ...): output of a `ccso:Aggregation`
    (also a `ccso:StatisticalProjectionTransformation`) whose inputs are the
    outputs of the simulations, of which they are a rescaled version
    (`data:hasRescaledVersion`);
  - the other variables, `day` and `mon`: made of a part for each period
    (`<that dataset>/historical`, `<that dataset>/rcp85`), each a linear
    transformation (`data:isLinearTransformationOf`) of the CORDEX-CMIP5
    dataset of its period, for the variables in other units (`tas`, `tasmax`,
    `tasmin` in `degC`, `pr`, `prsn` in `mm/day`, `psl` in `hPa`), or
    equivalent to it (`data:isEquivalentTo`: `clt`, `hurs`, `huss`,
    `sfcWind`, `uas`, `vas`, and `snw` in `mm`, with the values of `kg m-2`).
    Not a component of the CORDEX-CMIP5 datasets, whose values are in other
    units. The CORDEX-CMIP5 datasets are given from their parts
    (`cordex_dataset_part_jsonld` in
    `data-sources/cordex-cmip5/mapping/cordex-datasets.jq`, without their
    variables, given by the mapping of the search results), also those missing
    from the search results. Assumed: the monthly datasets of UKCP18 come from
    the monthly ones of CORDEX (not computed from the daily ones, which would
    make them aggregations); not documented in the metadata.

  Each EuroCORDEX dataset is in the KG under its id
  (`.../ukcp18/datasets/<id>`, 68,255), as a component of the dataset of its
  simulation, frequency and variable (or, for the regional splits, as a
  rescaled version of it): 935 simulations and variables, 9,350 such
  datasets for the 10 frequencies (`day`, `mon`, `seas`, `ann` and the six
  climatologies; 3,740 when the climatologies were not mapped), with 3,228
  parts for the periods of the `day` and `mon` ones (not for `rls`, `rss`),
  besides the output of the ensemble.

  The nodes of the simulations (with their driving CMIP5 simulations) and of
  the regional model are given with the functions of
  `data-sources/cordex-cmip5/mapping/cordex-datasets.jq`, so the simulations
  missing from the CORDEX search results (`REMO2015` driven by `EC-EARTH`
  `r12i1p1` and by `HadGEM2-ES`) are in the KG.
- **RegCM4-6 driven by CNRM-CM5.** The UKCP18 metadata give the version `v1`,
  while ESGF has only `v2` of this simulation: as nothing shows that `v1` is a
  metadata error (it may have been replaced by `v2`), the `v1` simulation is
  in the KG, as given.
- **Nodes given once.** The nodes of the CMIP5 and CORDEX-CMIP5 simulations,
  outputs and models are given by each dataset referring to them: the framing
  (`AWK_FRAME_BLOCKS` in `workflow/rules/ukcp18.smk`) writes each of their
  lines once.
