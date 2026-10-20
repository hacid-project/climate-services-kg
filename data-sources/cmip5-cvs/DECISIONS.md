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
    differs, not just in the case of the ids: 10 of the 24 institutions of
    the CSV (`CSIRO-BOM`, `CSIRO-QCCCE`, `EC-EARTH`, `FIO`, `GCESS`,
    `LASG-IAP`, `NASA-GMAO`, `NCEP`, `NMR-KMA`, `RSMAS`) are not in it even
    ignoring the case, the script has CMIP6-style institutions (e.g. `CCCma`,
    with full addresses), only 34 of the 93 experiments (no `decadal*`,
    `noVolc*`, `volcIn2010`, ...), and none of the descriptions of the CSV.
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

- **Institutions added** (`data/institutions-added.csv`). The institutes of
  the CMIP5 datasets of the KG that are not in `institutions.csv` are added in
  a separate file, so that the snapshot stays as it is (the two are
  concatenated by `csvstack`). Their names were inferred from the models of
  their datasets and the CMIP5 documentation, not taken from a vocabulary:

  | Id | Name | Model of the datasets |
  | --- | --- | --- |
  | `ICHEC` | Irish Centre for High-End Computing | EC-EARTH |
  | `LASG-CESS` | LASG, Institute of Atmospheric Physics, Chinese Academy of Sciences and CESS, Tsinghua University | FGOALS-g2 |
  | `NIMR-KMA` | National Institute of Meteorological Research/Korea Meteorological Administration | HadGEM2-AO |
  | `UNSW` | University of New South Wales | CSIRO-Mk3L-1-2 |

## Open cases

- `NMR-KMA` in `institutions.csv` has the name of `NIMR-KMA`, the id used by
  the datasets: probably an older or mistaken id of the same institute.
- `NCEP` has no description.

## Validation

The Snakemake rules give byte-identical outputs to the JSON-LD previously kept
in the repository (`rdf/*.jsonld`, made by `map.sh`), but for the 4 added
institutions.
