# Mapping of the UKCP18 datasets (CEDA metadata, published on Zenodo) to
# JSON-LD with jq.
#
# The metadata is in JSON Lines (a dataset per line), read and mapped one
# dataset at a time: the nodes of the datasets, written one per line, are
# framed as JSON-LD documents in blocks (config.yaml, ukcp18.block_size), so
# that neither the mapping nor the loading needs the whole data in memory.
#
# The jq programs are run from data-sources/ukcp18, as their modules and data
# are imported relative to it (./mapping/..., ./data/...). The variables of the
# datasets are resolved to the MIP variables
# (data-sources/cmor-tables/mapping/mip-mapping.md).


rule ukcp18:
    input:
        "data-sources/ukcp18/rdf/spatial-grids.jsonld",
        "data-sources/ukcp18/rdf/variables.jsonld",
        "data-sources/ukcp18/rdf/models.jsonld",
        "data-sources/ukcp18/rdf/datasets",


# Modules of the variables of the datasets: the local variables are specified
# in mapping/ukcp-variables.json, the others are the MIP variables
UKCP18_VARIABLES_MODULES = [
    "data-sources/ukcp18/mapping/missing-units.json",
    "data-sources/ukcp18/mapping/ukcp18-variables.jq",
    "data-sources/ukcp18/mapping/ukcp-variables.json",
    "data-sources/ukcp18/mapping/time.jq",
    "data-sources/ukcp18/mapping/ukcp18-time.jq",
    "data-sources/ukcp18/mapping/utils.jq",
    "data-sources/cmor-tables/mapping/mip-variables.jq",
    "data-sources/cmor-tables/mapping/mip-mapping.json",
]


# Metadata of the UKCP18 datasets (https://doi.org/10.5281/zenodo.23515656), in
# JSON Lines: a dataset per line
rule ukcp18_metadata:
    input:
        storage.zenodo("zenodo://record/23515656/ukcp18_metadata.jsonl.gz"),
    output:
        "data-sources/ukcp18/data/ceda_ukcp18_metadata.jsonl",
    shell:
        "gunzip -c {input:q} > {output:q}"


# Spatial grids of the UKCP18 resolutions, and the map from domain and
# resolution to grid used to map the datasets
rule ukcp18_spatial_grids:
    input:
        mapping="data-sources/ukcp18/mapping/spatial-grids.jq",
        modules=[
            "data-sources/ukcp18/mapping/utils.jq",
            "data-sources/ukcp18/mapping/jsonld.jq",
        ],
    output:
        rdf="data-sources/ukcp18/rdf/spatial-grids.jsonld",
        grid_map="data-sources/ukcp18/data/spatial-grid-map.json",
    log:
        "logs/ukcp18/spatial_grids.log",
    shell:
        "root=$PWD; cd data-sources/ukcp18 &&"
        " jq -L mapping -f mapping/spatial-grids.jq --null-input > $root/{output.rdf:q} 2> $root/{log:q} &&"
        " jq .grid_map $root/{output.rdf:q} > $root/{output.grid_map:q} 2>> $root/{log:q}"


# Units of the variables of the KG (MIP and previous variables), by IRI, to
# check the datasets with other units (rule ukcp18_variables_check)
rule ukcp18_mip_variable_units:
    input:
        rules.cmor_tables.input,
    output:
        "data-sources/ukcp18/data/mip-variable-units.json",
    log:
        "logs/ukcp18/mip_variable_units.log",
    shell:
        "jq -n '[inputs | .[\"@graph\"][]] |"
        " (map(select(.[\"@type\"] | index(\"top:UnitOfMeasure\")?) | {{key: .[\"@id\"], value: .[\"rdfs:label\"]}}) | from_entries) as $units |"
        " map(select((.[\"@type\"] | IN(\"data:Variable\", \"data:DeterministicVariable\")) and .hasUnitOfMeasure) | {{key: .[\"@id\"], value: $units[.hasUnitOfMeasure]}}) |"
        " from_entries' {input:q} > {output:q} 2> {log:q}"


# Variants of the models of the land-gcm datasets
rule ukcp18_model_variants:
    input:
        metadata="data-sources/ukcp18/data/ceda_ukcp18_metadata.jsonl",
        mapping="data-sources/ukcp18/mapping/extract-model-variants.jq",
    output:
        "data-sources/ukcp18/data/model-variants.json",
    log:
        "logs/ukcp18/model_variants.log",
    shell:
        "root=$PWD; cd data-sources/ukcp18 &&"
        " jq -n -L mapping -f mapping/extract-model-variants.jq $root/{input.metadata:q} > $root/{output:q} 2> $root/{log:q}"


# Local variables (mapping/ukcp-variables.json), with their units and baseline
# periods
rule ukcp18_map_variables:
    input:
        mapping="data-sources/ukcp18/mapping/variables.jq",
        modules=UKCP18_VARIABLES_MODULES
        + [
            "data-sources/ukcp18/mapping/context.jq",
            "data-sources/ukcp18/mapping/jsonld.jq",
        ],
    output:
        "data-sources/ukcp18/rdf/variables.jsonld",
    log:
        "logs/ukcp18/map_variables.log",
    shell:
        "root=$PWD; cd data-sources/ukcp18 &&"
        " jq -n -L mapping -L ../cmor-tables/mapping -f mapping/variables.jq"
        " > $root/{output:q} 2> $root/{log:q}"


# The models of the Met Office Hadley Centre used by the datasets
rule ukcp18_map_models:
    input:
        mapping="data-sources/ukcp18/mapping/models.jq",
        modules=[
            "data-sources/ukcp18/mapping/context.jq",
            "data-sources/ukcp18/mapping/jsonld.jq",
        ],
    output:
        "data-sources/ukcp18/rdf/models.jsonld",
    log:
        "logs/ukcp18/map_models.log",
    shell:
        "root=$PWD; cd data-sources/ukcp18 &&"
        " jq -n -L mapping -f mapping/models.jq > $root/{output:q} 2> $root/{log:q}"


# Datasets, with their simulations and grids (the log lists the datasets whose
# id does not match their metadata): each dataset is mapped on its own
# (mapping/datasets.jq, a node per line), and the nodes are framed as JSON-LD
# documents (mapping/frame.jq) in blocks of ukcp18.block_size nodes,
# rdf/datasets/datasets-NNNN.jsonld
rule ukcp18_map_datasets:
    input:
        metadata="data-sources/ukcp18/data/ceda_ukcp18_metadata.jsonl",
        mapping="data-sources/ukcp18/mapping/datasets.jq",
        frame="data-sources/ukcp18/mapping/frame.jq",
        mip_index="data-sources/cmor-tables/data/mip-mapping-index.json",
        modules=UKCP18_VARIABLES_MODULES
        + [
            "data-sources/ukcp18/mapping/simulations.jq",
            "data-sources/ukcp18/mapping/jsonld.jq",
            "data-sources/ukcp18/mapping/context.jq",
            "data-sources/ukcp18/mapping/ukcp18-ids.jq",
        ],
        data=[
            "data-sources/ukcp18/data/spatial-grid-map.json",
            "data-sources/ukcp18/data/model-variants.json",
            "data-sources/ukcp18/data/cmip5-model-synonyms.json",
        ],
    output:
        directory("data-sources/ukcp18/rdf/datasets"),
    params:
        block_size=config["ukcp18"]["block_size"],
    log:
        "logs/ukcp18/map_datasets.log",
    shell:
        "root=$PWD; mkdir -p {output:q}; cd data-sources/ukcp18 &&"
        " jq -n -c -L mapping -L ../cmor-tables/mapping --slurpfile mip_index $root/{input.mip_index:q}"
        " -f mapping/datasets.jq $root/{input.metadata:q} 2> $root/{log:q} |"
        " split -l {params.block_size} -d -a 4 --additional-suffix=.jsonld"
        " --filter='jq -s -c -L mapping -f mapping/frame.jq > $FILE' - $root/{output:q}/datasets-"


# --- Analysis


# Datasets whose variable is not a variable of the KG, to review their mapping
rule ukcp18_unmapped_variables:
    input:
        metadata="data-sources/ukcp18/data/ceda_ukcp18_metadata.jsonl",
        filter="data-sources/ukcp18/analysis/unmapped-variables.jq",
        modules=UKCP18_VARIABLES_MODULES + ["data-sources/ukcp18/mapping/ukcp18-ids.jq"],
        kg_variables=rules.cmor_tables_variable_iris.output,
        mip_index="data-sources/cmor-tables/data/mip-mapping-index.json",
    output:
        "data-sources/ukcp18/analysis/unmapped-variables.json.gz",
    log:
        "logs/ukcp18/unmapped_variables.log",
    shell:
        "root=$PWD;"
        " cd data-sources/ukcp18 &&"
        " jq -n -L mapping -L ../cmor-tables/mapping --slurpfile kg_variables $root/{input.kg_variables:q}"
        " --slurpfile mip_index $root/{input.mip_index:q}"
        " -f analysis/unmapped-variables.jq $root/{input.metadata:q} 2> $root/{log:q} |"
        " gzip -n > $root/{output:q}"


# Check of the local variables (mapping/ukcp-variables.json) against the
# datasets: the datasets of each local variable, the local variables of no
# dataset, and the datasets without a local variable with units other than those
# of their MIP variable
rule ukcp18_variables_check:
    input:
        metadata="data-sources/ukcp18/data/ceda_ukcp18_metadata.jsonl",
        filter="data-sources/ukcp18/analysis/variables-check.jq",
        modules=UKCP18_VARIABLES_MODULES + ["data-sources/ukcp18/mapping/ukcp18-ids.jq"],
        mip_units="data-sources/ukcp18/data/mip-variable-units.json",
        mip_index="data-sources/cmor-tables/data/mip-mapping-index.json",
    output:
        "data-sources/ukcp18/analysis/variables-check.json",
    log:
        "logs/ukcp18/variables_check.log",
    shell:
        "root=$PWD;"
        " cd data-sources/ukcp18 &&"
        " jq -n -L mapping -L ../cmor-tables/mapping --slurpfile mip_units $root/{input.mip_units:q}"
        " --slurpfile mip_index $root/{input.mip_index:q}"
        " -f analysis/variables-check.jq $root/{input.metadata:q} > $root/{output:q} 2> $root/{log:q}"
