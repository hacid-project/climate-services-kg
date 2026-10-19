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

### R-003: Rebuild only what is affected by a change
- **Category:** INC · **Priority:** M · **Status:** satisfied (partially)
- **Date:** 2026-10-19 · **Evidence:** README ("Changing a mapping reruns only the affected steps")
- **Situation:** mappings change often during development. Full rebuilds are slow.
- **Requirement:** incremental recomputation at the granularity of the dataflow steps, including when a jq module *imported* by a mapping changes.
- **Current handling:** Snakemake file timestamps and rules. **[check]** whether changes in imported jq modules are detected.

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
- **Current handling:** partly migrated to Snakemake. The rest uses shell scripts.

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
- **Current handling:** shell scripts outside the workflow.
