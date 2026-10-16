# Mapping of the UKCP18 datasets (CEDA metadata, published on Zenodo) to
# JSON-LD with jq.
#
# The jq programs are run from data-sources/ukcp18, as their modules and data
# are imported relative to it (./mapping/..., ./data/...). The variables of the
# datasets are resolved to the MIP variables
# (data-sources/cmor-tables/mapping/mip-mapping.md).


rule ukcp18:
    input:
        "data-sources/ukcp18/rdf/spatial-grids.jsonld",
        "data-sources/ukcp18/rdf/ceda_ukcp18_metadata_merged.jsonld",


# Metadata of the UKCP18 datasets (https://doi.org/10.5281/zenodo.23362544)
rule ukcp18_metadata:
    input:
        storage.zenodo("zenodo://record/23362544/ceda_ukcp18_metadata_merged.json.gz"),
    output:
        "data-sources/ukcp18/data/ceda_ukcp18_metadata_merged.json",
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
# tell the UKCP18 variables with other units
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
        metadata="data-sources/ukcp18/data/ceda_ukcp18_metadata_merged.json",
        mapping="data-sources/ukcp18/mapping/extract-model-variants.jq",
    output:
        "data-sources/ukcp18/data/model-variants.json",
    log:
        "logs/ukcp18/model_variants.log",
    shell:
        "root=$PWD; cd data-sources/ukcp18 &&"
        " jq -L mapping -f mapping/extract-model-variants.jq $root/{input.metadata:q} > $root/{output:q} 2> $root/{log:q}"


# Datasets, with their simulations, models and grids (the log lists the
# datasets whose id does not match their metadata)
rule ukcp18_map_datasets:
    input:
        metadata="data-sources/ukcp18/data/ceda_ukcp18_metadata_merged.json",
        mapping="data-sources/ukcp18/mapping/datasets.jq",
        modules=[
            "data-sources/ukcp18/mapping/utils.jq",
            "data-sources/ukcp18/mapping/time.jq",
            "data-sources/ukcp18/mapping/ukcp18-time.jq",
            "data-sources/ukcp18/mapping/simulations.jq",
            "data-sources/ukcp18/mapping/jsonld.jq",
            "data-sources/ukcp18/mapping/ukcp18-variables.jq",
            "data-sources/ukcp18/data/mip-variable-units.json",
            "data-sources/ukcp18/mapping/ukcp18-ids.jq",
            "data-sources/cmor-tables/mapping/mip-variables.jq",
            "data-sources/cmor-tables/mapping/mip-mapping.json",
        ],
        data=[
            "data-sources/ukcp18/data/spatial-grid-map.json",
            "data-sources/ukcp18/data/model-variants.json",
            "data-sources/ukcp18/data/cmip5-model-synonyms.json",
        ],
    output:
        "data-sources/ukcp18/rdf/ceda_ukcp18_metadata_merged.jsonld",
    log:
        "logs/ukcp18/map_datasets.log",
    shell:
        "root=$PWD; cd data-sources/ukcp18 &&"
        " jq -L mapping -L ../cmor-tables/mapping -f mapping/datasets.jq $root/{input.metadata:q}"
        " > $root/{output:q} 2> $root/{log:q}"


# --- Analysis


# Datasets whose variable is not a variable of the KG, to review their mapping
rule ukcp18_unmapped_variables:
    input:
        metadata="data-sources/ukcp18/data/ceda_ukcp18_metadata_merged.json",
        filter="data-sources/ukcp18/analysis/unmapped-variables.jq",
        modules=[
            "data-sources/ukcp18/mapping/time.jq",
            "data-sources/ukcp18/mapping/ukcp18-time.jq",
            "data-sources/ukcp18/mapping/ukcp18-variables.jq",
            "data-sources/ukcp18/data/mip-variable-units.json",
            "data-sources/ukcp18/mapping/ukcp18-ids.jq",
            "data-sources/cmor-tables/mapping/mip-variables.jq",
            "data-sources/cmor-tables/mapping/mip-mapping.json",
        ],
        kg_variables=rules.cmor_tables.input,
    output:
        "data-sources/ukcp18/analysis/unmapped-variables.json.gz",
    log:
        "logs/ukcp18/unmapped_variables.log",
    shell:
        "root=$PWD;"
        " jq -n '[inputs | .[\"@graph\"][] | select((.[\"@type\"] | IN(\"data:Variable\", \"data:DeterministicVariable\"))) | .[\"@id\"]] | unique'"
        " {input.kg_variables:q} > $root/{output:q}.variables.json 2> $root/{log:q} &&"
        " cd data-sources/ukcp18 &&"
        " jq -L mapping -L ../cmor-tables/mapping --slurpfile kg_variables $root/{output:q}.variables.json"
        " -f analysis/unmapped-variables.jq $root/{input.metadata:q} 2>> $root/{log:q} |"
        " gzip -n > $root/{output:q} &&"
        " rm $root/{output:q}.variables.json"
