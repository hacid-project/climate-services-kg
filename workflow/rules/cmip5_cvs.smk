# Mapping of the controlled vocabularies of CMIP5 to JSON-LD with jq, from the
# configuration of the ESGF publisher (https://github.com/ESGF/config, read as
# raw text, mapping/esgf-config.jq):
# - the experiments, from its map of the experiments to their descriptions;
# - the institutions, joining the names of the institutes of the models in the
#   models table with the ids of the institutes of the models in the CMIP5
#   institute map, with some fixes (mapping/institution-fixes.json).

ESGF_CONFIG = storage.git(
    "{cmip5_cvs[esgf_config_repo]}#{cmip5_cvs[esgf_config_version]}".format(**config)
)


rule cmip5_cvs:
    input:
        "data-sources/cmip5-cvs/rdf/experiments.jsonld",
        "data-sources/cmip5-cvs/rdf/institutions.jsonld",


# Experiments: [{id, description}]
rule cmip5_cvs_experiments_esgf:
    input:
        checkout=ESGF_CONFIG,
        module="data-sources/cmip5-cvs/mapping/esgf-config.jq",
    output:
        "data-sources/cmip5-cvs/data/experiments-esgf.json",
    log:
        "logs/cmip5_cvs/experiments_esgf.log",
    shell:
        "jq -n -L data-sources/cmip5-cvs/mapping"
        " --rawfile ini {input.checkout:q}/publisher-configs/ini/esg.cmip5.ini"
        " 'include \"esgf-config\"; esgf_experiments($ini)' > {output:q} 2> {log:q}"


# Institutions: [{id, acronym, description, models, candidates}], with the
# fixes of mapping/institution-fixes.json (names replaced, institutions
# excluded)
rule cmip5_cvs_institutions_esgf:
    input:
        checkout=ESGF_CONFIG,
        module="data-sources/cmip5-cvs/mapping/esgf-config.jq",
        fixes="data-sources/cmip5-cvs/mapping/institution-fixes.json",
    output:
        "data-sources/cmip5-cvs/data/institutions-esgf.json",
    log:
        "logs/cmip5_cvs/institutions_esgf.log",
    shell:
        "jq -n -L data-sources/cmip5-cvs/mapping"
        " --rawfile models_table {input.checkout:q}/publisher-configs/esgcet_models_table.txt"
        " --rawfile ini {input.checkout:q}/publisher-configs/ini/esg.cmip5.ini"
        " --slurpfile fixes {input.fixes:q}"
        " 'include \"esgf-config\"; esgf_institutions($models_table; $ini) | fix_institutions($fixes[0])'"
        " > {output:q} 2> {log:q}"


rule cmip5_cvs_map:
    input:
        data="data-sources/cmip5-cvs/data/{name}-esgf.json",
        mapping="data-sources/cmip5-cvs/mapping/{name}.jq",
    output:
        "data-sources/cmip5-cvs/rdf/{name}.jsonld",
    wildcard_constraints:
        name="experiments|institutions",
    log:
        "logs/cmip5_cvs/map_{name}.log",
    shell:
        "jq -f {input.mapping:q} {input.data:q} > {output:q} 2> {log:q}"
