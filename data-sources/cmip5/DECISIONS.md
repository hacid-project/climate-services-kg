# CMIP5: decisions on issues and inconsistencies

Decisions taken in mapping the CMIP5 datasets (the ESGF search results,
`data/cmip5.json`) to the KG, with the place where each one is applied.

## Source data

- The search results are published on Zenodo
  ([10.5281/zenodo.23363413](https://doi.org/10.5281/zenodo.23363413)),
  identical to the file previously kept in the repository.

## Datasets (`mapping/datasets.jq`)

- **Port from RML.** The jq mapping reproduces the former RML mapping
  (`rml/cmip5.ttl`, with the functions of `ws-data-rml.py`), checked against
  its committed output (279,288 triples).
- **Datasets without variable.** Some records have no `variable`: they are
  mapped without variables.
- **Temporal grids.** The time interval of a dataset is rounded to its time
  frequency (the frequencies shorter than a day to days, `monClim` to months),
  as in the RML mapping (`round_datetime` in `esgf.jq`).

## Ids and metadata (`mapping/cmip5-datasets.jq`)

The nodes of the datasets, simulations, ensembles, experiments and models are
given by functions of `mapping/cmip5-datasets.jq` (`cmip5_dataset_jsonld`,
`cmip5_simulation_jsonld`, `cmip5_model_jsonld`, with the IRIs of
`cmip5_simulation_iris`), so that the mappings of the sources referring to
CMIP5 simulations (CORDEX-CMIP5, UKCP18) can give the nodes of the
simulations missing from the search results, with the same IRIs and triples.
Their input keys are documented with each function.

- **Values from the metadata, not from the ids.** The functions take the
  product, model, experiment and ensemble member from the facets of the
  records, not from the components of the dataset ids (`master_id`), which is
  only the id of the dataset (its IRI and label). Compared on all the 6,445
  records, the components of the ids agree with the facets but for:
  - **Model names.** The facet `model` is the name of the model (e.g.
    `CSIRO-Mk3.6.0`, the IRI of the model), the ids have the CMIP5 model id of
    the DRS (e.g. `CSIRO-Mk3-6-0`, in the IRIs of the simulations). The id is
    derived from the name (`cmip5_model_id`): each `.` replaced by `-`, except
    for `GFDL-CM2.1` (`GFDL-CM2p1`) and `INM-CM4` (`inmcm4`), the only
    exceptions in the search results, and for `BCC-CSM1.1` (`bcc-csm1-1`) and
    `BCC-CSM1.1(m)` (`bcc-csm1-1-m`), not in the search results but driving
    CORDEX-CMIP5 and UKCP18 simulations. Same IRIs as before for all the
    records. The other way round, the name of a model is given by its id
    (`cmip5_model_name`, for the sources that have only the id), so the table
    of the exceptions (`_cmip5_model_ids`) lists all the models whose name is
    not their id: those of the search results (also `ACCESS1.0`, `ACCESS1.3`,
    `CSIRO-Mk3.6.0`) and `CESM1(BGC)` (`CESM1-BGC`), `BCC-CSM1.1` and
    `BCC-CSM1.1(m)`, not in the search results (their names from the CMIP5
    conventions, not checked against ESGF). For the other models (e.g.
    `BNU-ESM`, `CCSM4`) the name is the id.
  - **Institute.** The 492 CanESM2 records have the institute `CCCma` in the
    ids and `CCCMA` in the facet `institute`. The institute is not in the IRIs
    of the simulations; the organization is the one of the facet
    (`.../organizations/CCCMA`), as before.
  - **Ids without CMOR table.** 378 of the CanESM2 ids have 8 components, with
    no CMOR table (e.g. `cmip5.output.CCCma.CanESM2.historical.6hr.atmos.r1i1p1`,
    of the table `6hrLev`). They are kept as the ids of their datasets (no two
    records of different tables have the same id); the ensemble member was
    already taken as the last component.
- **Same triples.** The refactoring gives the same triples as before (282,210).

## Variables (`cmip5_variable_spec`, `cmip5_variable_iri` in `mapping/esgf.jq`)

- **Resolution to the MIP variables.** The variables are resolved to the MIP
  variables (`data-sources/cmor-tables/mapping/mip-mapping.md`) from their
  definitions in the CMIP5 CMOR tables (`config.yaml`, `cmip5.cmor_tables`),
  not just their names: e.g. a CMIP5 `tos` (in K) is the previous variable
  `.../variables/mip/cmip6/6.0.19/tos`.
- **Lookup of the definitions.** The ESGF results name a variable either by
  the key or by the `out_name` of its table entry: both are looked up. The
  entries of the table of the dataset are used or, if there are none (e.g. a
  variable of the `day` table in `cfDay`, or a table not in the CMOR tables,
  as `AmonExtras`), the entries of any table. A climatology (`monClim`) is
  defined on `time2`, the other datasets not. Of the remaining entries, only
  the table, dimensions, standard name and units on which all agree are used.
- **Several definitions.** When each of the definitions resolves to the same
  IRI, that IRI is used (no CMIP5 dataset changed with this rule, introduced
  for CORDEX-CMIP5).

## Variables not in the CMOR tables (`mapping/variables.json`)

Seven variable names of the datasets are in no edition of the CMOR tables.
Each is skipped, renamed or defined locally for its model, as given by
`mapping/variables.json` (`cmip5_dataset_variable_iri` in `mapping/esgf.jq`),
from the ESGF metadata of the datasets (long name, standard name, units):

| Variable | Model, table | Metadata | Mapping |
| --- | --- | --- | --- |
| `gridspec` | GFDL-CM2.1, CM3, ESM2G, ESM2M, `fx` | no long name, standard name `gridspec` | skipped (`skip`): grid description files, not a variable; the datasets hold no variable for it |
| `rluscs` | INM-CM4, `3hr` | "Surface Upwelling Clear-Sky Shortwave Radiation" | renamed (`renames`) to `rsuscs`: its metadata are those of `rsuscs`, the `3hr` table has no `rluscs`, and INM-CM4 publishes all the other variables of the table but `rsuscs` |
| `orograw` | CanESM2, `fx` | "Surface Altitude Unmodified", `surface_altitude`, `m` | local: the raw orography, as opposed to the surface altitude of the model (`orog`) |
| `lm` | FGOALS-s2, `fx` | "land sea mask", `land_sea_mask`, `1` | local, specialization of the CF `land_binary_mask` (an educated guess: the binary counterpart of `sftlf`; the values were not verified) |
| `rtoa` | GFDL-CM2.1, `AmonExtras` | "TOA Net Downward Radiation", `toa_net_downward_radiative_flux`, `W m-2` | local: at the top of the atmosphere, unlike `rtmt` (at the top of the model) |
| `pbp` | GFDL-ESM2M, `OyrExtras` | "Biogenic Phosphorus Production", `biogenic_phosphorus_production`, `mol m-3 s-1` | local, without CF variable: the phosphorus counterpart of `pbfe` and `pbsi` (`Oyr`); the closest CF name is vertically integrated |
| `swit` | CNRM-CM5, `3hr` | "Total Soil Wetness Index", `total_soil_wetness_index`, `1` | local, without CF variable: the soil wetness index of the ISBA land surface model |

The local variables (`local`, in the format of the CMOR tables) are mapped as
the variables of the CMOR tables (`mapping/variables.jq`, `rdf/variables.jsonld`)
as `.../variables/cmip5/<model>/<name>`, members of the collection of the
variables of the model (`.../variables/cmip5/<model>`, associated with the
model), with the label "<long name> (<name>, <model>)". The `fx` variables
depend on the geodetic dimension only. Each entry has a `note` with the
reasons.
