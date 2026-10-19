# Met Office Hadley Centre controlled vocabularies: decisions

Decisions taken in mapping the controlled vocabularies (indices, hazards,
methods, operations) to the KG.

## Source data

- **Curated files as source.** The vocabularies are data collected and curated
  manually within the project. They were first kept in shared spreadsheets,
  exported to CSV, converted to JSON and cleansed by scripts; then it was
  decided that the cleansed JSON files in `data/` would be the source of truth,
  and later updates were made there (e.g. the operation to select climate
  models, commits cd7f9c7 and 0da6e7b, and the global warming levels,
  53e3ea7). The spreadsheet exports, the conversion and cleansing scripts and
  their statistics were therefore removed (they remain in the git history, up
  to commit 8f1041e).
- **Schemes of the values** (`data/cv-map.json`). Mapped to the schemes of the
  KG (`mapping/cvs.jq`), and read by the mapping of the operations
  (`mapping/operations.jq`, as `$cv_map`) for the values of their parameters.

## Validation

The Snakemake rules give byte-identical outputs to the JSON-LD previously kept
in the repository (`rdf/*.jsonld`, made by `map.sh`).
