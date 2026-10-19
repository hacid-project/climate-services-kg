# Met Office Hadley Centre controlled vocabularies: decisions

Decisions taken in mapping the controlled vocabularies (indices, hazards,
methods, operations) to the KG.

## Source data

- **Curated files as source.** The JSON files in `data/` are the source: they
  were derived from spreadsheets (exported to CSV and converted to JSON) by
  cleansing scripts, and then edited by hand (e.g. the operation to select
  climate models, commits cd7f9c7 and 0da6e7b, and the global warming levels,
  53e3ea7). Regenerating them from the spreadsheets would lose those edits, so
  the spreadsheet exports, the conversion and cleansing scripts and their
  statistics were removed (they remain in the git history, up to commit
  8f1041e).
- **Schemes of the values** (`data/cv-map.json`). Mapped to the schemes of the
  KG (`mapping/cvs.jq`), and read by the mapping of the operations
  (`mapping/operations.jq`, as `$cv_map`) for the values of their parameters.

## Validation

The Snakemake rules give byte-identical outputs to the JSON-LD previously kept
in the repository (`rdf/*.jsonld`, made by `map.sh`).
