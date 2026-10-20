# Requirements log: declarative dataflow for KG construction

Pipeline: `hacid-project/climate-services-kg` (CCKG population). Started: 2026-10-19.

## Categories (fixed)

| Code | Category | Covers |
|---|---|---|
| `MOD` | Modularity and reuse | Components, interfaces, shared lookup tables, packaging, reuse across sources |
| `VER` | Versioned inputs and provenance | Pinning sources (git tags, DOIs), lineage of outputs, PROV metadata |
| `INC` | Incremental and partial recomputation | Rebuild only what changed, targets for subsets |
| `QUA` | Data quality and diagnostics | Analyses, rejected or unmapped records, checks, reports as first-class outputs |
| `MAP` | Mapping expressivity | What the mapping language (jq, RML, …) can or cannot express easily |
| `INT` | Integration and interoperability | Mixing languages and tools, calling external services |
| `FAIR` | FAIR-by-design | Metadata, identifiers, licences and documentation generated from the pipeline |
| `OPS` | Execution and deployment | Loading into the triple store, environments, credentials, scaling |
| `SEP` | Separation of design and optimization | Logical dataflow vs resource-aware execution (caching, parallelism, storage) |
| `DOC` | Documentation and visualization | Diagrams, READMEs, derived views of the pipeline |

Priority: `H` (blocks or costs much), `M`, `L`. Status: `open` · `workaround` · `satisfied` (by the current stack) · `dropped`.

## Entry format

```
### R-NNN: <short name>
- **Category:** <code(s)> · **Priority:** H/M/L · **Status:** open/workaround/satisfied/dropped
- **Date:** YYYY-MM-DD · **Evidence:** <commit / PR / issue / file>
- **Situation:** what happened in the pipeline (concrete)
- **Requirement:** what a dataflow system should provide (general, tool-independent)
- **Current handling:** how Snakemake / jq / RML / shell deal with it now
- **Notes:** related entries, ideas, links to literature
```

---

## Seed entries (inferred on 2026-10-19 from the README, Snakefile and folder layout. Verify, edit or drop)

### R-001: Pin external inputs to immutable versions
- **Category:** VER · **Priority:** H · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `workflow/Snakefile` (git and Zenodo storage), `workflow/patches/git_storage_plugin.py`
- **Situation:** inputs come from git repositories at specific tags (CMOR tables of each era) and from Zenodo records (ESGF and CEDA metadata dumps). The git storage plugin had to be patched to accept a ref as a URL fragment.
- **Requirement:** sources should be declared with an immutable version (tag, commit, DOI) as part of the dataflow, and the version should be propagated to the outputs' provenance.
- **Current handling:** Snakemake storage plugins (one patched). Versions live in `config/`.
- **Notes:** links to FAIR (R-007).

### R-002: Shared lookup tables across source mappings
- **Category:** MOD · **Priority:** H · **Status:** open
- **Date:** 2026-10-19 · **Evidence:** `data-sources/cmor-tables/mapping/mip-mapping.json` used by the CMIP5, CORDEX-CMIP5 and UKCP18 mappings
- **Situation:** several source mappings resolve variables through the same derived table, produced by another part of the pipeline.
- **Requirement:** a module should be able to export a derived artefact (table or function) with a declared interface, and other modules should import it without knowing where it lives.
- **Current handling:** file paths shared by convention, plus Snakemake dependencies.
- **Notes:** more cases: the jq module `data-sources/cmip5/mapping/esgf.jq` (temporal grids, variable lookup) is shared by the CMIP5 and CORDEX-CMIP5 mappings; the list of the IRIs of the KG variables, once computed inline in each consumer, became a rule (`cmor_tables_variable_iris`, commit 1d2dd4d) used by three consumers; the CORDEX local variables reuse the CMOR-tables mapping function `variables_jsonld` (commit 1d2dd4d).

### R-003: Rebuild only what is affected by a change
- **Category:** INC · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** README ("Changing a mapping reruns only the affected steps"); the `modules=[...]` inputs of the jq rules in `workflow/rules/*.smk`; commit 3a23c30 (adding `time.jq`, `ukcp18-time.jq` to the inputs of `ukcp18_unmapped_variables`)
- **Situation:** mappings change often during development. Full rebuilds are slow.
- **Requirement:** incremental recomputation at the granularity of the dataflow steps, including when a jq module *imported* by a mapping changes.
- **Current handling:** Snakemake file timestamps and rules. Checked: a change in an imported jq module is detected only if the module is listed among the inputs of the rule (e.g. editing `cmip5/mapping/esgf.jq` reruns the CMIP5 and CORDEX mappings, which list it). The lists are maintained by hand, and a missing entry silently skips the rebuild (it happened when the UKCP18 variables module started importing the time modules).
- **Notes:** the imports could be derived from the `include`/`import` directives of the programs (see R-015).

### R-004: Analyses and diagnostics as first-class outputs
- **Category:** QUA · **Priority:** H · **Status:** satisfied (partially)
- **Date:** 2026-10-19 · **Evidence:** `sources_analysis` target; `analysis/` folders; `ukcp18/analysis/unmapped-variables.json.gz`; `cordex-cmip5/analysis/variables-check.*`
- **Situation:** every source needs checks (unmapped variables, mismatches against standards). They are not part of the KG but drive mapping decisions.
- **Requirement:** a dataflow should declare side outputs for diagnostics next to the main outputs, with a standard shape so they can be aggregated into a quality report.
- **Current handling:** separate Snakemake targets with ad hoc formats.

### R-005: Channel for rejected or anomalous records
- **Category:** QUA · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `logs/ukcp18/map_datasets.log` (datasets whose id does not match their metadata)
- **Situation:** some records cannot be mapped consistently. They are listed in a log.
- **Requirement:** an explicit "rejected records" output per step, structured (JSON) and countable, not free-form logs.
- **Current handling:** log files.

### R-006: Mixing mapping languages per source
- **Category:** INT, MAP · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `data-sources/*/rml/` (activities, experiments, sources, institutions, cf-standard-names) vs `data-sources/*/mapping/*.jq`; `ws-data-rml.py`; legacy `map-data.sh`
- **Situation:** older sources use RML, newer ones jq. Some steps are still shell scripts outside Snakemake.
- **Requirement:** a dataflow should host steps in different mapping languages behind uniform interfaces, so a source can migrate from one to the other without changing its consumers.
- **Current handling:** all the sources migrated to jq steps in Snakemake (2026-10-20); the migration kept the outputs equivalent, checked against the previous ones (R-011).
- **Notes:** the CF standard names were ported to jq too (R-016), then the CORDEX domains (R-018): no source is mapped with RML any more: `ws-data-rml.py` (with its pyrml dependency, the root `requirements.txt`) and `map-data.sh` were removed. With the global warming levels and the ontologies (taken from their git repository), every graph of the KG is now produced by the Snakemake workflow, except the files written by hand.

### R-007: Generate FAIR metadata from the pipeline
- **Category:** FAIR, DOC · **Priority:** M · **Status:** open
- **Date:** 2026-10-19 · **Evidence:** README describes sources, versions and outputs by hand
- **Situation:** the description of sources, versions, licences and outputs is written by hand in the README.
- **Requirement:** dataset-level metadata (DCAT, PROV) for each output should be generated from the dataflow definition and the pinned inputs.
- **Current handling:** manual.

### R-008: Pipeline diagram derived from the definition
- **Category:** DOC · **Priority:** L · **Status:** open
- **Date:** 2026-10-19 · **Evidence:** `data-production.graphml` (hand-maintained diagram, which predates the Snakemake workflow)
- **Situation:** the diagram has to be kept in sync with the pipeline by hand.
- **Requirement:** diagrams and documentation views should be derived from the dataflow definition.
- **Current handling:** manual (Snakemake can produce a DAG, but not at the level of the mapping logic).

### R-009: Logical dataflow independent of storage and execution choices
- **Category:** SEP · **Priority:** M · **Status:** open
- **Date:** 2026-10-19 · **Evidence:** storage plugins and `keep_local` in the Snakefile; compressed outputs (`.json.gz`); `--cores N`
- **Situation:** where inputs are cached, how outputs are compressed, and how parallelism works are mixed into the same files as the mapping logic.
- **Requirement:** the logical dataflow (what is computed from what) should be specified separately from physical choices (caching, compression, parallelism, storage), which an engine or a separate configuration decides.
- **Current handling:** partial (Snakemake config vs rules), but mixed in practice.

### R-010: Loading and publishing as part of the dataflow
- **Category:** OPS · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `load.sh`, `just-load.sh`, `upload_kg.sh`, `setup_kg.sh`, `reset_kg.sh`, `consolidate.sh`, `fuseki-conf.ttl`, `graph_names.csv`, `publication/drop_on_virtuoso.sh`
- **Situation:** loading into Fuseki (and publication to Virtuoso), consolidation and named-graph management are separate shell scripts.
- **Requirement:** sinks (triple store, named graphs, publication dumps) should be declared steps of the dataflow, with the same versioning and incrementality as the mappings.
- **Current handling:** loading, consolidation and export are steps of the workflow (rule `consolidate`, 2026-10-20), with the Jena command-line tools on a TDB2 dataset inside the project, instead of Fuseki; the steps record their completion in marker files, as the dataset is modified in place. Serving (Fuseki) and publication (Virtuoso) are still outside.
- **Notes:** a TDB2 dataset updated in place does not fit the file-based model of Snakemake (outputs are not modified by later steps): its state is tracked by marker files. The JSON-LD parser of Jena reads whole documents in memory, so the largest output (1.8 GB of JSON-LD) needs a large heap.

---

## Entries from the CMIP5, CORDEX-CMIP5 and UKCP18 work (2026-10-19)

### R-011: Reference runs to validate the migration of a mapping
- **Category:** QUA, VER · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** PR #31 (CORDEX-CMIP5 port, commit 5b9a8fc); `data-sources/cordex-cmip5/DECISIONS.md` ("Validation of the port from RML")
- **Situation:** porting the CMIP5 and CORDEX-CMIP5 mappings from RML to jq was validated by comparing the triples with the outputs of the old mappings. For CMIP5 a committed output existed. For CORDEX-CMIP5 the old mapping had to be run again: the pyrml commit pinned in `requirements.txt` no longer exists, the released pyrml fails on the mapping (patched in a scratch copy), and empty input pages make it crash.
- **Requirement:** when a step is replaced by another implementation, the dataflow should keep (or be able to regenerate) the reference outputs of the old one and check the equivalence of the new one as a declared test, with the old environment pinned in a reproducible way.
- **Current handling:** manual reference runs and triple-set comparisons (rdflib) outside the workflow.
- **Notes:** related to R-001 (pinning also the tools, not only the data) and R-006.

### R-012: Declarative record of curation decisions on source data
- **Category:** QUA, DOC · **Priority:** H · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `data-sources/cordex-cmip5/mapping/data-issues.json`; `data-sources/*/DECISIONS.md`; commits 4378cae, 91924c7, 230a9b9, 767fb7f
- **Situation:** the source metadata has errors and non-standard uses (wrong units, placeholder or non-CF standard names, homonyms, model-specific units). Each case needed a decision (exclude the records, take a name as an alias, correct the units, define a model-specific variable), with its reason and sometimes as a hypothesis to verify later.
- **Requirement:** curation decisions should be data, separate from the mapping logic: matched on record attributes, each with its reason and status (e.g. hypothesis to verify), applied consistently by the mapping and by the quality checks, and reported (how many records each decision affects).
- **Current handling:** a JSON file of rules per source (exclusions, aliases, unit errors, model variables) read by the jq mapping and by the check, plus a hand-written `DECISIONS.md` per source.
- **Notes:** the rules are ad hoc per source; a general vocabulary (and their provenance in the KG) would allow reuse across sources. Related to R-004, R-005.

### R-013: Inputs in heterogeneous formats
- **Category:** INT · **Priority:** L · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `workflow/scripts/cordex_standard_output.py` (commit 02f161c); `workflow/rules/cordex_cmip5.smk` (tar archive from Zenodo)
- **Situation:** the CORDEX variables requested by the archive are a legacy Excel file (`.xls`), and the CORDEX-CMIP5 metadata is a tar archive (with macOS metadata files to skip). Before the jq mappings, the Excel had to be converted by a Python step with an extra dependency (`xlrd`), into the JSON format of the CMOR tables.
- **Requirement:** readers for common formats (spreadsheets, archives, CSV, NetCDF headers) should be available as standard steps, producing a uniform intermediate representation for the mappings.
- **Current handling:** ad hoc Python and shell steps in the rules.
- **Notes:** the macOS metadata files came from creating the archive on macOS (`tar` adds `._*` files unless `COPYFILE_DISABLE=1`, and extended-attribute headers unless `--no-xattrs`); the record was republished clean (10.5281/zenodo.23477951) after two attempts. Checking the archives of the inputs before publishing (expected file list) would have caught it. For XML, a standard converter was preferred to ad hoc code: the CF standard name table is converted by `xq` (Python package `yq`, conventions of xmltodict, see R-016). Some sources are configuration files meant for a program (the ESGF publisher: a table with `|` separators and an ini file with indented maps, joined to get the CMIP5 institutions), parsed in jq as raw text. The list of the CORDEX RCMs is a text table with columns of fixed width, where long values run into the next column without separators.

### R-014: Contracts between steps on the shape of intermediate outputs
- **Category:** MOD, QUA · **Priority:** M · **Status:** open
- **Date:** 2026-10-19 · **Evidence:** commit 22636a5 (variables typed `data:DeterministicVariable`) and the fix in commit 02f161c (`workflow/rules/ukcp18.smk`)
- **Situation:** two UKCP18 rules selected the variables of the CMOR-tables output by `"@type" == "data:Variable"`. When the mapping started typing them `data:DeterministicVariable`, the rules would have silently found no variables (no error, empty outputs).
- **Requirement:** the outputs consumed by other steps should have a declared schema or contract (e.g. the classes and properties they provide, or reasoning over the ontology), checked when either side changes, so that a change in a producer fails visibly in the consumers.
- **Current handling:** none: found by reading the code; the selection now accepts both classes.
- **Notes:** a single rule now produces the list of the KG variables (R-002), which reduces the places to fix.

### R-015: Dependencies of mapping modules
- **Category:** MAP, INC · **Priority:** L · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `data-sources/cordex-cmip5/analysis/variables-check.jq` (`include "esgf"` besides `include "cordex-variables"`); the library paths (`-L`) of the jq rules
- **Situation:** jq `include` does not pass on the definitions of the modules included in turn, so each program must include every module it uses directly, and each rule must give every library path and list every module file (R-003). Modules spread over the folders of several sources (`cmor-tables/mapping`, `cmip5/mapping`, `cordex-cmip5/mapping`).
- **Requirement:** the dependencies between mapping modules should be declared once (as in a package system), with the dataflow deriving the library paths and the inputs to watch from them.
- **Current handling:** by hand in each program and rule.

## Entries from the CF standard names work (2026-10-19)

### R-016: Derived data edited by hand and committed outputs out of date
- **Category:** VER, DOC · **Priority:** H · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** commit 0b585c8 ("Fix manually issue with CF variables"); commits bf597ef, 22636a5 (RML mapping changed, `rdf/data.ttl` not regenerated); `data-sources/cf-standard-names/DECISIONS.md`
- **Situation:** the CF table was converted from XML to JSON with a tool that was not recorded. Two entries were then removed by hand from the JSON (and from the CSV and Turtle derived from it), with no reason given; the reason (the names are also aliases of other entries) had to be found again in the source. Later changes to the RML mapping (the class of the variables, the language of the unit labels) were not applied to the committed output.
- **Requirement:** every transformation from the published source to the outputs should be a step of the dataflow, including format conversions and fixes, with the fixes recorded as curation decisions (R-012). Committed derived data should be either avoided or checked for being up to date with its inputs and steps.
- **Current handling:** the conversion is done by a standard tool (`xq`, with the conventions of xmltodict), so the intermediate format is given by a known convention rather than by ad hoc code; the fix is a rule of the jq mapping (entries that are also aliases are left out), documented in `DECISIONS.md`. The derived data is no longer committed.
- **Notes:** related to R-011 (the stale output was still usable as the reference, after accounting for the later changes).

### R-017: Alternative locations of an input
- **Category:** VER, OPS · **Priority:** L · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `config/config.yaml` (`cf_standard_names.url`); `workflow/rules/cf_standard_names.smk`
- **Situation:** the CF table is published at cfconventions.org, which was not reachable from the environment where the workflow was developed (blocked by its network policy). The same file is in the GitHub repository from which the site is published.
- **Requirement:** an input should be identified independently of where it is fetched from (e.g. by version and checksum), with alternative locations (mirrors, archived copies) tried in turn and checked to give the same content.
- **Current handling:** the base URL is configurable; the copy on GitHub was checked by hand to be identical to the committed XML.
- **Notes:** related to R-001 and R-009.

## Entries from the CORDEX domains work (2026-10-19)

### R-018: Evolution of the layout of an input
- **Category:** VER, QUA · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `data-sources/cordex-domains/DECISIONS.md`; `workflow/rules/cordex_domains.smk`; the former `data-sources/cordex-domains/merge.sh`
- **Situation:** the CORDEX domain tables are maintained in a git repository without tags, whose layout changed over time: columns reordered (2024-11), then the tables restructured and renamed, with other columns and derived values dropped (2026-06). The former merge script used column positions, so the reorder would have silently given wrong ids. The copy previously kept in this repository came from an older commit, and the merged table had been fixed by hand as upstream did later.
- **Requirement:** the inputs should be read by their schema (column names, types), checked against a declared one, so that a change of layout fails visibly; pinning by commit should be supported where there are no releases, with a way to compare versions of an input (values changed, columns added or dropped) before moving to a newer one.
- **Current handling:** pinned to a commit in `config/config.yaml`; the tables are converted by a standard tool (`csvjson`) and merged by column name; the versions were compared by hand.
- **Notes:** related to R-001 (pinning), R-014 (contracts between steps) and R-016 (data edited by hand).

## Entries from the MOHC controlled vocabularies work (2026-10-19)

### R-019: Data curated within the project as a source
- **Category:** VER, QUA, DOC · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `data-sources/mohc-cvs/DECISIONS.md`; the removed `cleanse.sh`, `CSVtoJSON.py` and `data-raw-*` (up to commit 8f1041e); commits cd7f9c7, 0da6e7b, 53e3ea7
- **Situation:** the MOHC controlled vocabularies are collected and curated manually within the project. They were first kept in shared spreadsheets, converted to JSON and cleansed by scripts. It was then decided that the cleansed JSON files would be the source of truth, and later updates were made there, so the spreadsheets and the scripts became obsolete. The change of the authoring medium was a one-off migration, not a step of the dataflow.
- **Requirement:** a dataflow should distinguish external sources from data authored within the project, and support the latter as first-class inputs: edited in a declared format (with a schema checked on each change, as nothing else validates hand edits), versioned with the history of the curation (who changed what and why), and with a recorded migration when the authoring medium changes (e.g. from spreadsheets to JSON).
- **Current handling:** the JSON files are kept in the repository as source and edited directly; the curation history is only in git; no schema is checked.
- **Notes:** related to R-012 (curation decisions on external data) and R-016.

### R-020: Data files imported by a mapping
- **Category:** MAP, MOD · **Priority:** L · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `data-sources/mohc-cvs/mapping/operations.jq` (formerly `import "./data/cv-map" as $cv_map_inputs`)
- **Situation:** a jq mapping imported a data file with a path relative to the working directory, which worked only when run from the folder of the source, and hid the dependency from the dataflow.
- **Requirement:** the data a mapping reads should be declared as inputs of its step, not resolved implicitly by the mapping.
- **Current handling:** passed with `--slurpfile` and listed among the inputs of the rule.
- **Notes:** related to R-015.

## Entries from the Climdex work (2026-10-19)

### R-021: Snapshots of sources without a stable structured version
- **Category:** VER, FAIR, DOC · **Priority:** M · **Status:** workaround
- **Date:** 2026-10-19 · **Evidence:** `data-sources/climdex/DECISIONS.md`; `data-sources/climdex/data/table.md`, `by-sector.json`
- **Situation:** the Climdex indices are published only as web pages. The most interoperable version found is a Markdown table in the Climpact user guide (in a git repository). The local copy matches the table of two releases (v3.2, v3.3), but with one row added by hand, and the guide has changed since. The classification by sector is incomplete in the table, so it was curated by hand from another web page. None of this was recorded with the files.
- **Requirement:** a local snapshot of a source should carry its provenance as metadata: where it comes from (URL, repository, release or commit), when it was taken, and how it differs from the original (rows added, curated parts), so it can be compared with newer versions of the original.
- **Current handling:** the snapshots are kept in the repository as source, with their provenance written in `DECISIONS.md` (reconstructed by comparing the copy with the history of the guide).
- **Notes:** related to R-001, R-018 and R-019. The same happened with the CMIP5 controlled vocabularies (`data-sources/cmip5-cvs/DECISIONS.md`): the source remembered for them (PCMDI/CMIP5_CVs) turned out not to be theirs, and their actual origin (probably an earlier ESGF publisher configuration) could only be guessed. Both the institutions and the experiments are now taken from the ESGF publisher configuration, after comparing them with the snapshot (for the experiments, a modified copy of an ESGF map, with first letters lowercased).
