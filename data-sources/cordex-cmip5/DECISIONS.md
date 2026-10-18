# CORDEX-CMIP5: decisions on issues and inconsistencies

Decisions taken in mapping the CORDEX-CMIP5 datasets (the ESGF search results,
`data/cordex-<n>.json`) to the KG, with the place where each one is applied.
The open cases, left for further analysis, are listed by the check of the
variables (`analysis/variables-check.json`, see the end of this document).

## Source data

- **Pages of the search results.** The datasets are published on Zenodo
  ([10.5281/zenodo.23364077](https://doi.org/10.5281/zenodo.23364077)) as the
  pages of the ESGF search (`download-data.sh`). The archive also holds macOS
  metadata files (`._*`), skipped when extracting. Two pages
  (`cordex-15.json`, `cordex-16.json`) are empty: they contribute nothing.
- **Repeated datasets.** 145,493 records give 145,446 distinct datasets
  (`master_id`): the records of the same dataset in more than one page are
  mapped once.

## Datasets and simulations (`mapping/datasets.jq`)

- **Driving models.** The ESGF results name the driving models in several
  ways (e.g. `MOHC-HadGEM2-ES`, `CNRM-CERFACS-CNRM-CM5`): they are normalised
  to the CMIP5 model names (`mapping/cmip5-model-synonyms.json`), also in the
  dataset ids, as in the former `clean-data.jq`.
- **Domains without resolution.** The domain `AUS` (199 datasets) has no
  resolution suffix, so it is not a CORDEX grid of the KG: these datasets get
  no spatial grid, as in the former RML mapping.
- **Excluded datasets** (`mapping/data-issues.json`, `excluded_datasets`):
  - `emiss` of the NARCliM datasets (UNSW, `WRF360J`, `WRF360K`, `WRF360L`,
    201 datasets): it is the surface emissivity (`surface_emissivity`, no
    units), while `emiss` in the CMIP5 CMOR tables is the emission of sea salt
    aerosol (`kg m-2 s-1`), so the resolution by name would give the wrong
    variable. Excluded for now.

## Variables (`mapping/cordex-variables.jq`, `mapping/variables.jq`)

- **Resolution to the MIP variables.** As for CMIP5 (see
  `data-sources/cmip5/DECISIONS.md`), the variables are resolved from their
  definitions in the CMIP5 CMOR tables. The datasets have no CMOR table: the
  tables of their time frequency are tried first (`frequency_tables`, e.g.
  `day` and `cfDay` for `day`; any table for `1hr` and `sem`, which have no
  CMIP5 table). When the definitions of a variable in several tables resolve
  to the same IRI, that IRI is used (e.g. `sic`, in `day` and `OImon`, is
  `siconc` at any frequency).
- **Variables requested by CORDEX and not in the KG.** The variables of the
  CORDEX standard output (`CORDEX_standard_output.xls`, converted to
  `CORDEX_standard_output.json`) whose MIP variable is not a variable of the KG
  at any of their frequencies (`ta200`, `ua500`, `va500`, `zg200`, `sund`,
  `clh`, `cll`, `clm`, `wsgsmax`) are defined locally as
  `.../variables/cordex/<name>`, mapped as the variables of the CMOR tables
  (`variables_jsonld`), with the entry of the daily table (or else the first
  one).
- **Long names of the pressure-level variables.** The standard output names
  `ta200` just "Air Temperature": the variables at a single pressure level,
  `<base><level>`, take the long name of the analogous MIP variables (of the
  same base on a single pressure level, e.g. `ta500` on `p500`) at their level,
  as in the CMOR tables (e.g. "Air Temperature at 200hPa").
- **Dimensions.** The rotated grid of the standard output (`rlon rlat`) is the
  geodetic dimension, as `longitude latitude` in the CMOR tables (only `rlon`
  is mapped, as `longitude`).
- **Other variables not in the CMOR tables** (not requested by CORDEX, e.g.
  `ua100m`, the pressure levels not requested, the coordinates `crs`,
  `heightv`, `soil_bounds`, `soil_layer`) keep the IRI
  `.../variables/mip/<name>`, which is not a variable of the KG.
- **Bias-corrected variables** (`pr-bc`, `tasmax-bc`, `tasmin-bc`, `pr-fl`,
  432 datasets, all of NARCliM, UNSW, AUS-44i, WRF360J/K): the ESGF metadata
  says nothing about the bias correction. According to the NARCliM
  documentation (Technical Note 3, Evans and Argüeso, 2014), it is a quantile
  mapping of daily precipitation and maximum and minimum temperature; the
  details were not verified (the NetCDF attributes at esgf.nci.org.au could
  not be read). They keep the IRI `.../variables/mip/<name>` for now.

## Standard names and units (`analysis/variables-check.jq`)

The CF standard names and units found in the datasets are compared with the
definitions of the standard output and of the CMIP5 CMOR tables:

- **Standard names.** Other names in a minority of the datasets of a variable
  and frequency are ignored (`minority_other`). Other names in a majority of
  them (`majority_other`) and different definitions in the standard output and
  in the CMOR tables (`definitions_differ`) are left for further analysis.
- **Known aliases** (`mapping/data-issues.json`, `standard_name_aliases`): the
  CNRM `ALADIN63` datasets of the clear-sky radiation fluxes (`rldscs`,
  `rluscs`, `rlutcs`, `rsdscs`, `rsuscs`, `rsutcs`) and of `reffclwtop` use
  descriptive names that are not CF standard names (e.g.
  `clear-sky_surface_downwelling_longwave_radiation`). Their variables, units
  and long names are those of the MIP variables with the same name, so they
  keep the MIP variables, and the names are taken as the CF standard names of
  the MIP variables (e.g. `surface_downwelling_longwave_flux_in_air_assuming_clear_sky`),
  reported separately by the check (`known_alias`).
- **Units.** The units are compared in a canonical form (symbols with
  exponents): the same units written differently are ignored (`equivalent`,
  e.g. `W/m2` for `W m-2`, `kg/m2/s` for `kg m-2 s-1`, `Kg` for `kg`, and
  `kg kg-1` for `1`), while different units (`inconsistent`, e.g. `K` for `m`,
  `1` for `%`, `mm/month` for `kg m-2 s-1`, `None`) are left for further
  analysis.

## Open cases

Listed in the summary of `analysis/variables-check.json`:
`standard_name_majority_other`, `standard_name_definitions_differ`,
`units_inconsistent` and `units_definitions_differ`, and the variables of the
datasets that are not variables of the KG (`not_in_kg`).

## Validation of the port from RML

The jq mapping reproduces the former mapping (`clean-data.jq` and the RML
mapping `rml/cordex.ttl`) on all the data (1,598,421 triples). Running the RML
mapping needed a patched copy of pyrml (the fork commit pinned in
`requirements.txt` no longer exists), and the empty pages had to be skipped, as
they made it fail.
