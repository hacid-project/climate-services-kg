# Climdex/Climpact indices: decisions on sources and issues

Decisions taken in mapping the climate indices of Climdex/Climpact to the KG,
with the place where each one is applied.

## Source data

No stable structured version of the indices was found, so local copies are
kept in the repository as source, with the online sources they come from:

- **Indices** (`data/table.md`). The table of the indices in Appendix A of the
  Climpact user guide
  ([ARCCSS-extremes/climpact](https://github.com/ARCCSS-extremes/climpact),
  `www/user_guide/Climpact_user_guide.md`), the most interoperable version found
  of the Climdex page of the indices (https://www.climdex.org/learn/indices/).
  The copy is the table of the guide as released in climpact v3.2 (2024-06-21)
  and v3.3 (2025-01-31, the same table), with one more row, `ETR` (Extreme
  Temperature Range), which is not in the guide. Since commit 8c08887
  (2026-03-18) the guide has a different table (e.g. the heatwave indices of
  the different definitions as separate rows, `Tx90-HWN`, `Tn90-HWN`,
  `EHF-HWN`, ..., instead of `HWN(EHF/Tx90/Tn90)`): not adopted, as it would
  change the indices of the KG.
- **Classification by sector** (`data/by-sector.json`). The table includes the
  sectors of the indices, but incompletely: the classification is taken from
  the Climdex page of the indices by sector
  (https://www.climdex.org/learn/indices/sector/), curated manually.
- **Units and time grids** (`added-units.ttl`, `added-grids.ttl`). Written by
  hand: the unit `°C2` (of the indices defined on the Excess Heat Factor) and
  the time grids of 3 and 6 months, used by the mapping and defined nowhere
  else in the KG.

## Validation

The Snakemake rules give byte-identical outputs to the JSON-LD previously kept
in the repository (`rdf/*.jsonld`, made by `map.sh`).
