# CORDEX RCMs: decisions on sources and issues

Decisions taken in mapping the CORDEX regional climate models (RCMs), with
their institutes, to the KG.

## Source data

- **Source: the list of the CORDEX RCMs of IS-ENES Data**
  (`CORDEX_RCMs_info.txt` of
  [IS-ENES-Data/IS-ENES-Data.github.io](https://github.com/IS-ENES-Data/IS-ENES-Data.github.io),
  also at https://is-enes-data.github.io/CORDEX_RCMs_info.txt), generated from
  the CORDEX RCM registration sheet. It is read through the git storage
  plugin, at the commit of `config/config.yaml` (`cordex_cmip5_cvs`, d9c78ec,
  2023-08-18; the file was last changed in b1d1a5d, 2022-06-28), and parsed
  in jq (`mapping/rcms-info.jq`).
- **Parsing.** The list has columns of fixed width (model id, institute id,
  terms of use, institution name). Three model ids are longer than their
  column and run into the institute id without spaces (e.g.
  `CLMcom-ETH-COSMO-crCLIM-v1-1CLMcom-ETH`): they are split taking the
  institute id as the end of the string that is also the start of the model
  id. The spaces in the names are normalised (e.g. "ZAMG, Vienna, Austria,
  in collaboration with the CLM-Community" has two spaces in the list).
- **Previous copies.** The CSV files previously kept in the repository were a
  conversion of the version of 2022-06-28: `CORDEX_RCMs.csv` exactly (with the
  same splitting and normalisation), `data/CORDEX_RCMs.csv` (the one mapped)
  with the 4 fixes below. `data/CORDEX_RCMs_ToU.csv` (the terms of use, without
  the names) was not used. They were removed (they remain in the git history,
  up to commit 7c2650f).

## Fixes (`mapping/rcm-fixes.json`)

The fixes made by hand in `data/CORDEX_RCMs.csv`, now applied by `fix_rcms`
(`mapping/rcms-info.jq`), with the original values kept in the intermediate
`data/rcms.json`. They give a single name to each institute id, and a single
institute to each id:

| Model | Fix | Reason |
| --- | --- | --- |
| `CMCC-REMHI` | name "Centro Euro-Mediterraneo per I Cambiamenti Climatici" (was "Centro Euromediterraneo sui Cambiamenti Climatici") | the name of CMCC in the CMIP5 institutions |
| `GERICS-REMO2015` | name "Helmholtz-Zentrum Geesthacht, Climate Service Center Germany" (was "Climate Service Center Germany") | that of `GERICS-REMO2009` |
| `IITM-RegCM4-4` | name "Indian Institute of Tropical Meteorology" (was "Centre for Climate Change Research. Indian Institute for Tropical Meteorology") | that of `IITM-RegCM4-1` |
| `UM-RegCM4-3` | institute id `UMICH` (was `UM`) | `UM` is also the Universidad de Murcia (`UM-WRF331`) |

Neither `UM` model is in the CORDEX-CMIP5 datasets of the KG.

## Validation

The output is byte-identical to the JSON-LD previously kept in the repository
(`rdf/models.jsonld`, made by `map.sh` from `data/CORDEX_RCMs.csv`).
