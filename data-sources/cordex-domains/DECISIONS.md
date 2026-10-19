# CORDEX domains: decisions on issues and inconsistencies

Decisions taken in mapping the CORDEX-CMIP5 domains and grids (the domain
tables of WCRP-CORDEX) to the KG, with the place where each one is applied.

## Source data

- **Repository and version.** The tables are read from the git repository
  [WCRP-CORDEX/domain-tables](https://github.com/WCRP-CORDEX/domain-tables),
  which has no tags: the version is a commit (`config/config.yaml`,
  `cordex_domains`), 26696d7 (2025-10-15), the last one with the CORDEX-CMIP5
  grids in two tables, `CORDEX-CMIP5_rotated_grids.csv` and
  `CORDEX-CMIP5_regular_grids.csv`.
- **Previous copies.** The tables previously kept in the repository
  (`raw-data/`) are those of the commits from cf7e6ca (2024-02-26) to 1a22944
  (2024-11-18). The later commits up to 26696d7 reorder the columns of the
  rotated grids (`domain_id` first) and remove "high res." from the names of
  the domains of `MNA-22i` and `EUR-11i` ("Middle East and North Africa  high
  res.", "Europe high res."), as had been done by hand in the merged table
  previously kept in the repository (`data/CORDEX-CMIP5.csv`). The other values
  are the same. The other tables previously kept (the CORDEX-CMIP6 domain
  boundaries and `CORDEX-bounding_boxes.csv`, not found in the repository) were
  not used.
- **Later layout.** Since commit 9622b1b (2026-06-15) the repository has the
  CORDEX-CMIP5 grids in a single table, `CORDEX-CMIP5_grids.csv`, with other
  column names and without the upper right coordinates (to be computed from the
  lower left coordinates, the number of points and the grid spacing). Its
  values are the same as those of 26696d7, but for two regular grids whose
  upper right coordinates in 26696d7 do not agree with their number of points:
  `CAS-44i` (upper latitude 69.75, but 133 latitudes from 17.75 with spacing
  0.5 reach 83.75) and `MED-44i` (upper longitude 51.75, but 144 longitudes
  from -20.75 reach 50.75). Not adopted for now: it would need computing the
  coordinates (with their decimal representation, part of the IRIs) and would
  change the bounding regions of those two grids. Left for further analysis.
- **Merge** (`workflow/rules/cordex_domains.smk`). The two tables are converted
  to JSON by `csvjson` (without type inference, the values are kept as strings)
  and merged in jq by column name, adding the type of the grid (`rotated`,
  `regular`) and the id of the domain (`area_id`, the first 3 characters of
  `domain_id`). The former `merge.sh` (awk) used the column positions, which
  the reordered columns would have broken.

## Mapping (`mapping/domains.jq`)

- **Port from RML.** The jq mapping reproduces the former RML mapping
  (`rml/cordex-domains.ttl`, with the function `formatCordexDomain` of
  `ws-data-rml.py`), checked against its committed output (`rdf/data.ttl`,
  1,186 triples), but for the regions below.
- **Bounding regions of the rotated grids.** The RML mapping also made, for each
  rotated grid, a region with its rotated coordinates as if they were WGS84
  coordinates (`.../WGS84/regions/rectangle/...`, 37 regions, 185 triples),
  referred to by nothing: they are not mapped. The bounding region of a rotated
  grid is a region of its rotated dimensional space, that of a regular grid a
  region of WGS84.
- **Domains.** A domain is identified by the first 3 characters of the ids of
  its grids (e.g. `EUR`), and described by the name of the domain in the
  tables (e.g. "Europe").
