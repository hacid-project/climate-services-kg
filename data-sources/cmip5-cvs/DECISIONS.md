# CMIP5 controlled vocabularies: decisions on sources and issues

Decisions taken in mapping the CMIP5 experiments and institutions to the KG.

## Source data

- **Local snapshot as source.** The CSV files in `data/` are kept in the
  repository as source. Their origin was not recorded:
  - They are not the output of
    [PCMDI/CMIP5_CVs](https://github.com/PCMDI/CMIP5_CVs) (`src/writeJson.py`,
    last commit 7d57821, 2022-09-01). That script is a draft that cannot run
    (it uses names it does not define: `getFileHistory`, `versionId`,
    `versionHistory`, `source_id`, `sub_experiment_id`), and its content
    differs: institutions in the CMIP6 style (e.g. `CCCma`, with full
    addresses), no `decadal*`, `noVolc*` and `volcIn2010` experiments, other
    descriptions.
  - They are close to the CMIP5 configuration of the ESGF publisher
    ([ESGF/config](https://github.com/ESGF/config),
    `publisher-configs/ini/esg.cmip5.ini`, `experiment_options`), probably
    from an earlier version of it: the current one has the same experiments
    plus a few more (e.g. `decadal1959`, `historicalAA`, `sst2090`), with
    capitalised and partly reworded descriptions. It has no names of the
    institutions.
  - The institution ids are those of the ESGF CMIP5 datasets (e.g. `CCCMA`),
    to which the KG links the datasets (`.../organizations/<id>`, see
    `data-sources/cmip5`): regenerating them from CMIP5_CVs would break those
    links.
- **Models** (`data/models.csv`). Not mapped (the models are mapped from the
  datasets, see `data-sources/cmip5`).

## Open cases

- **Institutions of the datasets not in the vocabulary.** The CMIP5 datasets
  of the KG have 4 institutes that are not in `institutions.csv`: `ICHEC`,
  `LASG-CESS`, `NIMR-KMA` (the vocabulary has `NMR-KMA`, "National Institute
  of Meteorological Research/Korea Meteorological Administration", probably
  the same) and `UNSW`. Their organizations have no label.
- `NCEP` has no description.

## Validation

The Snakemake rules give byte-identical outputs to the JSON-LD previously kept
in the repository (`rdf/*.jsonld`, made by `map.sh`).
