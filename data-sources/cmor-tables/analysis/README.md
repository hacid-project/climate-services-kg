# Evolution of the variable definitions in the CMOR tables

Analysis of how the variable definitions change across the editions of the CMOR
tables ingested by the workflow (`config/config.yaml`): releases of
[cmip5-cmor-tables](https://github.com/PCMDI/cmip5-cmor-tables) (5.0),
[cmip6-cmor-tables](https://github.com/PCMDI/cmip6-cmor-tables) (6.0.11 to 6.9.33) and
[mip-cmor-tables](https://github.com/PCMDI/mip-cmor-tables) (v6.5.0.0 to v6.5.0.4).

The aim is to know how much the releases can be treated as incremental updates
(especially regarding deletions) and whether the same name is used for different
quantities.

## Reproducing

The files in this folder are produced by the snakemake workflow:

```bash
snakemake --cores 4 cmor_tables_analysis
```

- `workflow/scripts/cmor_tables_edition_info.py` (rule `cmor_tables_edition_info`)
  reads each checkout: commit, date, ancestor commits and, for mip-cmor-tables,
  the CMIP6 provenance of the entries (`MIP_variables.json`);
- `workflow/scripts/cmor_tables_analysis.py` (rule `cmor_tables_analysis`) compares
  the tables extracted by the workflow (`data/{source}/{edition}.json`) and writes
  the files below.

Everything is recomputed from the configured editions, so the figures in this
description refer to the editions configured when it was written (30 editions,
CF standard name table v86).

## Method

- **Entry**: a variable of a table, e.g. `Amon.tas` (the identity used by CMOR).
  Also compared: variable **names** (the key, across tables) and `out_name` (used
  for the IRIs of the variables in the KG). Grid coordinates (`grids` table) and the
  formula terms of 6.0.11 are excluded.
- **Order of releases**: each edition is compared with its **predecessor**, the
  latest configured edition of the same repository it descends from in git. The
  tags are not linear: 6.0.19a precedes 6.0.19, and 6.1.23 is a side branch of
  6.1.22 (6.2.24 follows 6.1.22, not 6.1.23).
- **Modified**: an entry with at least one changed attribute, ignoring changes of
  conventions only (`type` empty/`float` to `real`, units `1.0` to `1`, case of
  `modeling_realm` and `long_name`, standard names that are CF aliases of each
  other). **Semantic** modifications change `standard_name`, `units`,
  `dimensions`, `cell_methods`, `positive`, `type`, `frequency` or
  `modeling_realm`.
- **Deleted entries** are classified as: still in other tables (same key),
  renamed (an added entry with the same standard name, dimensions, cell methods
  and frequency), removed and re-added in a later release, or removed.
- **Standard names** are compared through the CF standard name table
  (`data-sources/cf-standard-names`, v86), resolving aliases. A change is a
  *fix* if the old name is not in the CF table, a *sign convention* change if the
  names differ only by `minus_`, a *different CF quantity* if both are valid CF
  names of different quantities.

## Files

| File | Content |
|------|---------|
| `release-steps.csv` | For each edition and its predecessor: entries, added, deleted (by fate), modified (raw, without convention-only changes, semantic), names added/deleted, modified attributes |
| `deletions.csv` | Each deleted entry, its fate and the entries replacing it (or the release re-adding it) |
| `standard-name-changes.csv` | Each change of `standard_name` of an entry, classified |
| `same-name-different-quantity.csv` | `out_name`s used with standard names of different quantities (across all editions), with kind, editions and tables of each meaning |
| `same-name-different-units.csv` | `out_name`s used with different units |
| `repository-transitions.csv` | Comparison of consecutive repositories (cmip5 → cmip6, cmip6 → mip), by name and, for mip, through the CMIP6 provenance of its entries |
| `summary.json` | All the counts (editions with dates and predecessors, history of each repository, transitions, homonyms) |

## Results

### Releases are (almost) incremental

| Repository | Entries (first → last) | Entries ever | Ever deleted (not in last) | Names deleted |
|---|---|---|---|---|
| cmip6 (6.0.11 → 6.9.33) | 2082 → 2062 | 2162 | 100 (4.6%) | 48 of 1361 (3.5%) |
| mip (v6.5.0.0 → v6.5.0.4) | 2049 → 2049 | 2049 | 0 | 0 |

In the CMIP6 releases there are 148 deletions of entries:

- 64 entries are dropped from a table while the same variable is still in other tables;
- 13 are renamed (same definition, different key);
- 24 are removed and re-added later (the surface ocean biogeochemistry
  variables `Omon.*os`, removed in 6.0.15 and back in 6.3.27);
- 47 are removed for good (e.g. the water isotopes `H2p`, `O18s`..., `ua200`/`va850`
  in the daily and 6-hourly tables).

Almost all deletions happen in 2017-2018 (6.0.x to 6.4.28); since 6.5.29 there is
only one removal (`Emon.O18wv`), one rename and one entry dropped from a table.
MIP releases add and delete nothing (v6.5.0.1 only changes valid ranges).

So the releases can be treated as incremental if moves and renames are recognised
and removed entries are kept (as deprecated) rather than deleted.

What does change a lot are the **definitions**: 1035 of the 2062 entries of 6.9.33
had a semantic change in some release (`standard_name`, `frequency` e.g. `3hr` →
`3hrPt`, `dimensions`, `cell_methods`, `positive`, `units`...), and most
`standard_name` changes replace names that are not in the CF table (475) with valid
ones.

### Between repositories

- **CMIP5 5.0 → CMIP6 6.9.33**: 492 of the 672 CMIP5 names are kept, 180 (27%)
  dropped, 821 new names.
- **CMIP6 6.9.33 → MIP v6.5.0.0**: 2039 of the 2062 entries map one-to-one through the
  provenance in `MIP_variables.json`, with no change of definition. The other 23 are
  duplicates (e.g. `Eday.hfls` besides `day.hfls`) merged into 10 MIP entries without
  provenance, except the site coordinates `CFsubhr.latitude`/`longitude`. MIP renames
  the pressure level variants: 82 `out_name`s change (`hus` → `hus19`, `hus7h`,
  `hus27`...).

### Same name, different quantity

No name has different quantities **within** a CMIP6 or MIP edition. Across all the
editions, 370 `out_name`s are used with more than one standard name:

- 314 only because a name not in the CF table is replaced with a valid one;
- 23 because of a sign convention change (`tendency_of_..._deposition` →
  `minus_tendency_of_...`);
- 33 with different CF quantities:
  - within CMIP5 5.0 (9): in `Omon`, `pr` is `rainfall_flux`, `hfls`/`hfss` are
    downward fluxes, `rlds` is net, `rsds` is in sea water; `zfull`/`zhalf` are a
    depth in the ocean tables and a height in `cf3hr`; `day.tos` is
    `surface_temperature`; `clisccp` differs between `cfDay` and `cfMon`;
  - between CMIP5 and CMIP6: `dms` (concentration in sea water → mole fraction in
    air), `graz` (grazing of dissolved iron → of particulate organic carbon), `cfc11`
    (per kg → per m³), `wetso4` (no longer expressed as sulfur);
  - corrections within CMIP6, which make some releases wrong: `zmlwaero`/`zmswaero`
    swapped in 6.2.24-6.5.29, `intvaw` as dry static energy transport in 6.2.24,
    `sistryubot` changing direction, redefinitions of `vt100`, `spco2nat`/`spco2abio`,
    `rsutcsaf`, `co3satarag`/`co3satcalc` and others.

Moreover, 36 names are used with different units, mostly the same quantity in
different units (e.g. `ch4` in `1e-9` and `mol mol-1`, `thetao`/`tos` in `K` and
`degC`, salinity in `psu` and `0.001`).

### Consequences for the KG

The current mapping gives each `out_name` one IRI and merges all the editions on it:
the CMIP5 homonyms, the redefinitions and the different units end up on the same
variable with conflicting standard names and units, while the MIP renames
(`hus19`...) create new variables for the same CMIP6 one. Identifying the variables
by entry (table and key, or the MIP branded names) and attaching the definitions to
the editions would avoid both issues.
