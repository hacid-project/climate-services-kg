# UKCP18: decisions on issues and inconsistencies

Decisions taken in mapping the UKCP18 datasets (the CEDA metadata,
`data/ceda_ukcp18_metadata_merged.json`) to the KG, with the place where each
one is applied. The datasets whose variable is not a variable of the KG are
extracted for review in `analysis/unmapped-variables.json.gz` (currently none).

## Source data

- The metadata is published on Zenodo
  ([10.5281/zenodo.23362544](https://doi.org/10.5281/zenodo.23362544)).
- **marine-sim.** The `marine-sim` collection is not mapped: each of its
  versions has its own id structure (`mapping/datasets.jq`).
- **Ids not matching the metadata.** The datasets whose id does not match
  their metadata are listed in `logs/ukcp18/map_datasets.log`.

## Wrong or missing values (`mapping/ukcp18-ids.jq`)

- **Wrong variable.** Some datasets have a wrong variable in their metadata
  (`ensemble_member` in the EuroCORDEX datasets, `var__` for `evspsblveg`,
  `air_temperature` for `tasAnom`): the variable is taken from their id
  (`fix_variable`), and the units of `ensemble_member` are dropped.
- **Missing units.** Missing units (null or `None`) are taken from the other
  datasets of the same collection and variable, if they all have the same
  units (`fix_units`).
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
