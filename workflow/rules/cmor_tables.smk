# Ingestion of variable definitions from multiple editions of the CMOR tables.
#
# The editions are identified as {era}/{version}: the eras, with the git
# repository of their CMOR tables, are configured in config/cmor-tables-eras.json
# and {version} is a git ref of the repository.
#
# Each edition is checked out through the git storage plugin and its tables are
# collected in data/{era}/{version}.json (legacy CMOR 2 tables converted to
# JSON).
#
# The KG (rule cmor_tables) has the MIP variables, i.e. the variables of the
# current edition, mapped with jq to rdf/current/{era}/{version}.jsonld, and
# the previous variables kept separate from them (mapping/mip-mapping.md), i.e.
# only the variables of the keep/sign_change/unit_change entries of an edition,
# mapped to rdf/previous/{era}/{version}.jsonld. Only those editions are
# retrieved.
#
# The evolution of the variable definitions across all the editions listed in
# config/config.yaml is analysed in analysis/ (rule cmor_tables_analysis, see
# analysis/README.md).


wildcard_constraints:
    era="[^/]+",
    version="[^/]+",


# Rules reading the repository of an era, for each era (the repository of a
# git storage object cannot depend on a wildcard)
for cmor_era in config["eras"]:

    # Tables of an edition: CMOR 3 JSON tables, or legacy CMOR 2 tables (e.g.
    # CMIP5) converted to JSON if there are no JSON tables
    rule:
        name:
            f"cmor_tables_{cmor_era['era']}_tables"
        input:
            checkout=storage.git(f"{cmor_era['repo']}#{{version}}"),
            parser="data-sources/cmor-tables/mapping/cmor2-tables.jq",
        output:
            f"data-sources/cmor-tables/data/{cmor_era['era']}/{{version}}.json",
        log:
            f"logs/cmor_tables/tables/{cmor_era['era']}/{{version}}.log",
        shell:
            "if ls {input.checkout:q}/Tables/*.json > /dev/null 2>&1; then"
            " jq -s . {input.checkout:q}/Tables/*.json;"
            " else"
            " jq -R -n -f {input.parser:q} $(grep -l '^table_id:' {input.checkout:q}/Tables/*);"
            " fi > {output:q} 2> {log:q}"

    # Commit, date, ancestors (to order the editions) and, for repositories with
    # a MIP_variables.json (mip-cmor-tables), the CMIP6 provenance of the
    # entries (for the analysis)
    rule:
        name:
            f"cmor_tables_{cmor_era['era']}_edition_info"
        input:
            checkout=storage.git(f"{cmor_era['repo']}#{{version}}"),
        output:
            f"data-sources/cmor-tables/data/{cmor_era['era']}/{{version}}/info.json",
        params:
            era=cmor_era["era"],
        log:
            f"logs/cmor_tables/edition_info/{cmor_era['era']}/{{version}}.log",
        script:
            "../scripts/cmor_tables_edition_info.py"


# --- Mapping to the KG: MIP variables and previous variables


# Editions needed (computed with jq from the eras and the mapping):
# {"current": "<era>/<version>", "previous": ["<era>/<version>", ...]}
MIP_EDITIONS = json.loads(
    shell(
        "jq -c -L data-sources/cmor-tables/mapping"
        " -f data-sources/cmor-tables/mapping/mip-editions.jq config/cmor-tables-eras.json",
        read=True,
    )
)


rule cmor_tables:
    input:
        expand(
            "data-sources/cmor-tables/rdf/current/{edition}.jsonld",
            edition=MIP_EDITIONS["current"],
        ),
        expand(
            "data-sources/cmor-tables/rdf/previous/{edition}.jsonld",
            edition=MIP_EDITIONS["previous"],
        ),


# IRIs of the variables of the KG (MIP and previous variables), to tell the
# variables of the datasets that are not variables of the KG
rule cmor_tables_variable_iris:
    input:
        rules.cmor_tables.input,
    output:
        "data-sources/cmor-tables/data/variable-iris.json",
    log:
        "logs/cmor_tables/variable_iris.log",
    shell:
        "jq -n '[inputs | .[\"@graph\"][] |"
        " select(.[\"@type\"] | IN(\"data:Variable\", \"data:DeterministicVariable\")) | .[\"@id\"]] | unique'"
        " {input:q} > {output:q} 2> {log:q}"


# MIP variables: all the variables of the current edition
rule cmor_tables_map_variables:
    input:
        tables="data-sources/cmor-tables/data/{era}/{version}.json",
        mapping="data-sources/cmor-tables/mapping/variables.jq",
        modules="data-sources/cmor-tables/mapping/variables-jsonld.jq",
    output:
        "data-sources/cmor-tables/rdf/current/{era}/{version}.jsonld",
    log:
        "logs/cmor_tables/map_variables/{era}/{version}.log",
    shell:
        "jq -L data-sources/cmor-tables/mapping -f {input.mapping:q} {input.tables:q} > {output:q} 2> {log:q}"


# Previous variables of an edition (keep/sign_change/unit_change entries of the mapping)
rule cmor_tables_map_previous_variables:
    input:
        tables="data-sources/cmor-tables/data/{era}/{version}.json",
        mapping="data-sources/cmor-tables/mapping/mip-previous-variables.jq",
        modules=[
            "data-sources/cmor-tables/mapping/variables-jsonld.jq",
            "data-sources/cmor-tables/mapping/mip-variables.jq",
            "data-sources/cmor-tables/mapping/mip-mapping.json",
        ],
        eras="config/cmor-tables-eras.json",
    output:
        "data-sources/cmor-tables/rdf/previous/{era}/{version}.jsonld",
    log:
        "logs/cmor_tables/map_previous_variables/{era}/{version}.log",
    shell:
        "jq -L data-sources/cmor-tables/mapping"
        " --arg era {wildcards.era:q} --arg version {wildcards.version:q}"
        " --slurpfile eras {input.eras:q}"
        " -f {input.mapping:q} {input.tables:q} > {output:q} 2> {log:q}"


# --- Analysis of the evolution of the variable definitions


rule cmor_tables_analysis:
    input:
        tables=expand(
            "data-sources/cmor-tables/data/{edition}.json",
            edition=config["cmor_tables"]["editions"],
        ),
        info=expand(
            "data-sources/cmor-tables/data/{edition}/info.json",
            edition=config["cmor_tables"]["editions"],
        ),
        cf_table="data-sources/cf-standard-names/data/skip/cf-standard-name-table.xml",
    output:
        steps="data-sources/cmor-tables/analysis/release-steps.csv",
        deletions="data-sources/cmor-tables/analysis/deletions.csv",
        standard_name_changes="data-sources/cmor-tables/analysis/standard-name-changes.csv",
        same_name_different_quantity="data-sources/cmor-tables/analysis/same-name-different-quantity.csv",
        same_name_different_units="data-sources/cmor-tables/analysis/same-name-different-units.csv",
        repository_transitions="data-sources/cmor-tables/analysis/repository-transitions.csv",
        summary="data-sources/cmor-tables/analysis/summary.json",
    params:
        editions=config["cmor_tables"]["editions"],
    log:
        "logs/cmor_tables/analysis.log",
    script:
        "../scripts/cmor_tables_analysis.py"
