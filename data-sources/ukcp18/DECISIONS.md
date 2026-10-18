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

## Variables (`mapping/ukcp18-variables.jq`)

- **Resolution to the MIP variables.** From the variable name in the CMIP5
  era (UKCP18 is based on CMIP5 models), its units and, for the land-gcm
  datasets, the CMIP5 table of the source data (`cmip5_table_id`).
- **UKCP18 variables** not in the CMOR tables are defined in
  `.../variables/ukcp/`:
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
- **Labels.** The label of a UKCP18 variable is the most common among its
  datasets, preferring the long names in plain words, and a doubled
  "anomaly" in long names already ending with it is removed.
