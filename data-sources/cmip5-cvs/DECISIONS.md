# CMIP5 controlled vocabularies: decisions on sources and issues

Decisions taken in mapping the CMIP5 experiments and institutions to the KG.

## Institutions

- **Source: the ESGF publisher configuration**
  ([ESGF/config](https://github.com/ESGF/config), at the commit of
  `config/config.yaml`, `cmip5_cvs`, read through the git storage plugin).
  The institutions are obtained in jq (`mapping/esgf-institutions.jq`) by
  joining:
  - the CMIP5 lines of the models table
    (`publisher-configs/esgcet_models_table.txt`, "project | model | URL |
    description"), whose description is usually "<model name>, <institute
    name>": the name of the institute is the description without the part up
    to the first ", ", if any;
  - the institute map of CMIP5 (`publisher-configs/ini/esg.cmip5.ini`,
    `institute_map`, "model | institute"), giving the id of the institute of
    each model.

  The models are matched ignoring the case (the table has e.g. both `HadCM3`
  and `HADCM3`, the map `inmcm4` and the table `INMCM4`).
- **Ids.** The ids of the map are in upper case in the ids of the CMIP5
  datasets (`CCCma` is `CCCMA`), to which the KG links the datasets
  (`.../organizations/<id>`, see `data-sources/cmip5`): the IRIs use the ids
  in upper case, the acronyms the ids of the map. All the 19 institutes of the
  CMIP5 datasets of the KG are in the map.
- **Choice of the name.** The names that are just the id of a model
  (descriptions without ", ", e.g. `SP-CCSM4`, `MRI-AGCM3-2H`) are discarded;
  of the others, the most frequent among the lines of the models of the
  institute is taken.
- **Fixes** (`mapping/institution-fixes.json`, applied by
  `fix_institutions` in `mapping/esgf-institutions.jq`). Some names of ESGF
  are not names of the institutes (descriptions without ", "):

  | Id | Name of ESGF | Decision |
  | --- | --- | --- |
  | `ICHEC` | EC-EARTH consortium (the consortium of the model) | named "Irish Centre for High-End Computing" |
  | `LASG-CESS` | LASG, Institute of Atmospheric Physics, Chinese Academy of Sciences (that of `LASG-IAP`) | named "LASG, Institute of Atmospheric Physics, Chinese Academy of Sciences and CESS, Tsinghua University" |
  | `NCAR` | Community Climate System Model 4 (the model) | named "National Center for Atmospheric Research" |
  | `DOE-COLA-CMMAP-GMU` | none (its model `SP-CCSM4` is described by its id) | excluded |
  | `NSF-DOE-NCAR` | Community Earth System Model 1 (the models) | excluded |

  The names of `ICHEC` and `LASG-CESS` were inferred from the ids and the
  models of their datasets. The excluded institutions are not used by the
  CMIP5 datasets mapped.
- **Check against the CSV files** (`analysis/institutions-check.json`, rule
  `cmip5_cvs_institutions_check`). The CSV files previously used, kept for
  now, are compared with the institutions of ESGF (after the fixes, reported
  with the names of ESGF and their reasons): `data/institutions.csv` (the
  snapshot previously mapped, of unknown origin, very close to the models
  table) and `data/institutions-added.csv` (the institutes of the datasets
  missing from it, with names inferred by hand). Current result: 18 same
  names, 5 different (minor variants, e.g. "The First Institute of
  Oceanography" or "Max Planck Institute for Meteorology (MPI-M)", and
  `CSIRO-BOM`, "Centre for Australian Weather and Climate Research (CAWCR)"
  in ESGF and "CSIRO/Bureau of Meteorology" in the CSV), 5 only in the CSV
  files (`EC-EARTH`, `GCESS`, `NCEP`, `NMR-KMA`, `RSMAS`, not used by the
  datasets), 3 only in ESGF (`BNU`, `CSIRO`, `NICAM`). Decisions: the names
  of ESGF are kept where they differ, also for `CSIRO-BOM` (the Centre for
  Australian Weather and Climate Research is the partnership of CSIRO and the
  Bureau of Meteorology), and the ids only in the CSV files are dropped (they
  are not in the KG, as the institutions come from ESGF). Also reported: the
  names not parsed but correct (`INM`, `NASA-GISS`, `NASA-GMAO`), and the other
  name of `MOHC` given by the lines of `HadGEM2-A` ("National Institute of
  Meteorological Research/Korea Meteorological Administration", 2 lines
  against 10).

## Experiments

- **Local snapshot as source** (`data/experiments.csv`). Its origin was not
  recorded:
  - it is not the output of
    [PCMDI/CMIP5_CVs](https://github.com/PCMDI/CMIP5_CVs) (`src/writeJson.py`,
    last commit 7d57821, 2022-09-01): that script is a draft that cannot run
    (it uses names it does not define: `getFileHistory`, `versionId`,
    `versionHistory`, `source_id`, `sub_experiment_id`) and has only 34 of the
    93 experiments (no `decadal*`, `noVolc*`, `volcIn2010`, ...), with other
    descriptions. Neither are the institutions of the previous CSV, even
    ignoring the case of the ids: 10 of its 24 ids are not in the script,
    whose institutions are in the CMIP6 style (e.g. `CCCma`, with full
    addresses), and none of the descriptions are the same;
  - it is close to the experiments of the ESGF publisher configuration
    (`esg.cmip5.ini`, `experiment_options`), probably of an earlier version:
    the current one has the same experiments plus a few more (e.g.
    `decadal1959`, `historicalAA`, `sst2090`), with capitalised and partly
    reworded descriptions.
- **Models** (`data/models.csv`). Not mapped (the models are mapped from the
  datasets, see `data-sources/cmip5`).

## Validation

The experiments are byte-identical to the JSON-LD previously kept in the
repository (`rdf/experiments.jsonld`, made by `map.sh`). The institutions now
come from ESGF (see the check above).
