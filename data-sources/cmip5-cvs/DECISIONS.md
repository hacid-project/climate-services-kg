# CMIP5 controlled vocabularies: decisions on sources and issues

Decisions taken in mapping the CMIP5 experiments and institutions to the KG.

## Institutions

- **Source: the ESGF publisher configuration**
  ([ESGF/config](https://github.com/ESGF/config), at the commit of
  `config/config.yaml`, `cmip5_cvs`, read through the git storage plugin).
  The institutions are obtained in jq (`mapping/esgf-config.jq`) by
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
  `fix_institutions` in `mapping/esgf-config.jq`). Some names of ESGF
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
- **Comparison with the CSV files previously used.** The institutions were
  previously mapped from `data/institutions.csv` (a snapshot of unknown
  origin, very close to the models table) and `data/institutions-added.csv`
  (the institutes of the datasets missing from it, with names inferred by
  hand). They were compared with the institutions of ESGF (after the fixes):
  18 same names, 5 different (minor variants, e.g. "The First Institute of
  Oceanography" or "Max Planck Institute for Meteorology (MPI-M)", and
  `CSIRO-BOM`, "Centre for Australian Weather and Climate Research (CAWCR)"
  in ESGF and "CSIRO/Bureau of Meteorology" in the CSV), 5 only in the CSV
  files (`EC-EARTH`, `GCESS`, `NCEP`, `NMR-KMA`, `RSMAS`, not used by the
  datasets), 3 only in ESGF (`BNU`, `CSIRO`, `NICAM`). The names of ESGF are
  kept where they differ, also for `CSIRO-BOM` (the Centre for Australian
  Weather and Climate Research is the partnership of CSIRO and the Bureau of
  Meteorology), and the ids only in the CSV files are dropped. The CSV files
  and the check were then removed (they remain in the git history, up to
  commit 1ee9183).
- **Other issues of the names of ESGF**, accepted: the names of `INM`,
  `NASA-GISS`, `NASA-GMAO` are whole descriptions, without "<model>, ", but
  correct; `MOHC` is also named "National Institute of Meteorological
  Research/Korea Meteorological Administration" by the lines of `HadGEM2-A`
  (2 lines against 10, the name of the majority is taken).

## Experiments

- **Source: the ESGF publisher configuration**, the same as for the
  institutions: `experiment_description_map` in
  `publisher-configs/ini/esg.cmip5.ini`, parsed in jq (`esgf_experiments` in
  `mapping/esgf-config.jq`).
- **Comparison with the CSV file previously used** (`data/experiments.csv`, a
  snapshot of unknown origin, removed; it remains in the git history up to
  commit 198ed03). The map is the same in all the 22 versions of the file
  (since 2016-05-10), so the snapshot is not a verbatim copy of any of them:
  - all the 93 experiments of the CSV are in the map, which has 9 more:
    `decadal1959`, `historicalAA`, `historicalAnt`, `noVolc1965`,
    `noVolc1970`, `noVolc1995`, `noVolc2000`, `noVolc2005`, `sst2090`;
  - 20 descriptions differ only in the capital first letter (e.g.
    "pre-industrial control" in the CSV, "Pre-industrial control" in the map),
    and `historicalExt` is reworded ("historical simulation extended through
    year 2012" in the CSV, "Extension of the historical simulation through
    year 2012" in the map).

  The descriptions of the map are taken.
- **Not PCMDI/CMIP5_CVs.** The snapshot was not the output of
  [PCMDI/CMIP5_CVs](https://github.com/PCMDI/CMIP5_CVs) (`src/writeJson.py`,
  last commit 7d57821, 2022-09-01) either: that script is a draft that cannot
  run (it uses names it does not define: `getFileHistory`, `versionId`,
  `versionHistory`, `source_id`, `sub_experiment_id`) and has only 34 of the
  experiments, with other descriptions. Neither were the institutions of the
  previous CSV, even ignoring the case of the ids: 10 of its 24 ids are not in
  the script, whose institutions are in the CMIP6 style (e.g. `CCCma`, with
  full addresses), and none of the descriptions are the same.
- **Models.** The snapshot also had a table of the models
  (`data/models.csv`), never mapped (the models are mapped from the datasets,
  see `data-sources/cmip5`): removed (it remains in the git history, up to
  commit 26a9334).

## Validation

Both vocabularies now come from ESGF: the differences from the outputs of the
CSV files previously used are those reported above.
