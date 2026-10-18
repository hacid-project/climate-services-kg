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
