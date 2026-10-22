# CORDEX-CMIP5: decisions on issues and inconsistencies

Decisions taken in mapping the CORDEX-CMIP5 datasets (the ESGF search results,
`data/cordex-<n>.json`) to the KG, with the place where each one is applied.
The open cases, left for further analysis, are listed by the check of the
variables (`analysis/variables-check.json`, see the end of this document).

## Source data

- **Pages of the search results.** The datasets are published on Zenodo
  ([10.5281/zenodo.23477951](https://doi.org/10.5281/zenodo.23477951)) as the
  pages of the ESGF search (`download-data.sh`). The first version of the
  record (10.5281/zenodo.23364077) also held macOS metadata files (`._*`),
  skipped when extracting; the current version has only the pages, with the
  same content. Two pages
  (`cordex-15.json`, `cordex-16.json`) are empty: they contribute nothing.
- **Repeated datasets.** 145,493 records give 145,446 distinct datasets
  (`master_id`): the records of the same dataset in more than one page are
  mapped in each of the pages, as each page is mapped on its own (to a JSON-LD
  document, `rdf/datasets/cordex-<n>.jsonld`), with the same triples, merged
  when loaded.

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
- **Wrong units of the geopotential heights** (`mapping/data-issues.json`,
  `units_errors`): the RU-CORE `RegCM4-3` datasets (SEA-22) of the
  geopotential heights at the pressure levels (`zg200`, ..., `zg925`, 8
  datasets each) have the units `K`, and, as the other `RegCM4` datasets
  (`RegCM4-4`, `RegCM4-6`, `RegCM4-7`), the standard name and long name of the
  air temperature. Taken as an error in generating the metadata: the datasets
  keep the variables of their names, in `m` (`.../mip/zg500`,
  `.../cordex/zg200`), and the check reports them as known issues.
- **Placeholder metadata** (`units_errors`, `standard_name_aliases`): the
  `ts` of 2 CSIRO `CCAM-1704` datasets (units `units`, standard name and long
  name `long_name`) and the `prc` of 3 ICTP `RegCM4-7` datasets (CAM-22, units
  `None`, standard name `prc`) are taken as local bugs: they keep the MIP
  variables, in `K` and `kg m-2 s-1`.
- **Wrong units of the heat fluxes** (`units_errors`): the `hfls` and `hfss`
  of CSIRO `CCAM-2008` (ANT-44i, AUS-44i, 36 datasets each, versions 20210701
  to 20211112) are in `kg m-2 s-1`, with the standard and long names of the
  heat fluxes. Taken as an error in the units attribute (a hypothesis, see
  below): `kg m-2 s-1` has no meaning for the sensible heat flux, the water
  flux corresponding to the latent heat flux is published separately
  (`evspsbl`, in `kg m-2 s-1`), all the other energy fluxes of `CCAM-2008`
  are in `W m-2`, and the earlier CCAM versions (`CCAM`, 2017, and
  `CCAM-1704`, 2020) give `hfls` and `hfss` in `W m-2`. They keep the MIP
  variables, in `W m-2`.
- **Variables of a model** (`mapping/data-issues.json`, `model_variables`):
  the BoM statistical downscaling (BOM, `BOM-SDM`, domain AUS) gives `pr` in
  `mm` (1 daily dataset, "Total precipitation rate") and in `mm/month` (66
  monthly datasets): a genuinely different use of the variable. Each is a
  variable of its own, `.../variables/cordex/BOM-SDM/pr/mm` and
  `.../variables/cordex/BOM-SDM/pr/mm%2Fmonth`, member of the CORDEX variables
  and of the variables of the model (`.../variables/cordex/BOM-SDM`, associated
  with the model by `top:associatedWith`), derived from the MIP `pr`
  (`data:derivedFromVariable`; no linear transformation, as a monthly total
  depends on the length of the month).

  The same is done for the other units taken as legitimate alternative units,
  or alternative measures of the same phenomena (not checked in the NetCDF
  files, see below), each `.../variables/cordex/<model>/<variable>/<units>`,
  related to the MIP variable as given by its `relation`:

  | Variable | Units | Model (institute/model) | Datasets | Relation to the MIP variable |
  | --- | --- | --- | --- | --- |
  | `pr` | `mm`, `mm/month` | BOM/BOM-SDM | 67 | derived (`pr`) |
  | `hurs` | `1` | NUIM/WRF341E | 12 | linear transformation (`hurs`, `%`) |
  | `hur` | `1` | UCAN/WRF341I | 3 | linear transformation (`hur`, `%`) |
  | `sic` | `1` ("Sea Ice Flag", `sea_ice_flag`) | UCAN/WRF341I | 4 | derived (`siconc`): a flag, not the fraction |
  | `sftlf` | `1` | DMI/HIRHAM5 | 3 | linear transformation (`sftlf`, `%`) |
  | `snw` | `m` (snow depth as liquid water) | CSIRO/CCAM | 36 | linear transformation (`snw`, `kg m-2`, density of water) |
  | `mrso` | `m3/m3` (volumetric soil moisture) | CSIRO/CCAM | 36 | none (the soil depth would be needed) |

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
- **Variables at a single level not requested** (`mapping/level-variables.json`,
  `level_variables` in `mapping/cordex-variables.jq`). The variables of the
  datasets at a single pressure or height level (`<base><level>`, e.g.
  `hus200`, and `<base><level>m`, e.g. `ua50m`) that are neither MIP variables
  of the KG nor requested by CORDEX (83, of 12 bases) are defined locally as
  `.../variables/cordex/<name>`, as the requested ones, from a compact
  specification maintained by hand: for each base, its long name, CF standard
  name and units, and its pressure levels (hPa) and height levels (m). The
  long name is that of the base at the level (e.g. "Specific Humidity at
  200hPa", "Eastward Wind at 50m"). The standard names and units are those of
  the analogous CMIP variables (`cdnc`, `cl`, `cli`, `clw`, `hur`, `hus`, `ta`,
  `ua`, `va`, `wap`, `zg`) for the bases `cdnc`, `clfr`, `clice`, `clwmr`,
  `hur`, `hus`, `ta`, `ua`, `va`, `wap` and `zg`, in the units of the datasets
  (`clfr`, `clice` and `clwmr` in `1`: their ESGF standard names,
  `cloud_fraction`, `ice_mixing_ratio` and `cloud_liquid_water_mixing_ratio`,
  are not CF names, taken as those of `cl`, `cli` and `clw`), and of the CMIP6
  `wbptemp` (`wet_bulb_potential_temperature`) for `thetapw`. The bases `u` and
  `v` (zonal and meridional wind at 200, 500 and 850 hPa, 36 datasets each)
  are aliases of `ua` and `va` (`aliases`, `level_variable_name`): `u200` is
  the variable of `ua200`.
- **Other variables not in the CMOR tables** (not requested by CORDEX, e.g.
  the coordinates `crs`, `heightv`, `soil_bounds`, `soil_layer`) keep the IRI
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
  reported separately by the check (`known_alias`). Also the standard name
  `air_temperature` of the `RegCM4` datasets of the geopotential heights is
  taken as `geopotential_height` (see above).
- **Units.** The units are compared in a canonical form (symbols with
  exponents): the same units written differently are ignored (`equivalent`,
  e.g. `W/m2` for `W m-2`, `kg/m2/s` for `kg m-2 s-1`, `Kg` for `kg`, and
  `kg kg-1` for `1`), units known to be wrong (`units_errors`) and the
  variables of a model (`model_variables`) are reported as `known_issue`, while
  other different units (`inconsistent`) are left for further analysis, with
  the models of their datasets.

## Open cases

- **Checks against the NetCDF files.** The edge cases above (the alternative
  units, the placeholder metadata, the bias-corrected variables) should be
  checked against the content of the NetCDF files; not done for now, as it
  would take too much effort and the ESGF nodes could not easily be accessed.
  For the heat fluxes of `CCAM-2008`, the magnitudes of the values tell the
  units: tens to hundreds for `W m-2`, around 1e-5 for a mass flux.

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
