# Mapping of the controlled vocabularies of CMIP5 to JSON-LD with jq:
# - the experiments (data/experiments.csv, kept in the repository as source);
# - the institutions, from the configuration of the ESGF publisher
#   (https://github.com/ESGF/config), joining the names of the institutes of
#   the models in the models table with the ids of the institutes of the
#   models in the CMIP5 institute map (mapping/esgf-institutions.jq), with
#   some fixes (mapping/institution-fixes.json).


rule cmip5_cvs:
    input:
        "data-sources/cmip5-cvs/rdf/experiments.jsonld",
        "data-sources/cmip5-cvs/rdf/institutions.jsonld",


# Conversion to JSON by csvjson (of the Python package csvkit), without type
# inference, and mapping
rule cmip5_cvs_map_experiments:
    input:
        data="data-sources/cmip5-cvs/data/experiments.csv",
        mapping="data-sources/cmip5-cvs/mapping/experiments.jq",
    output:
        "data-sources/cmip5-cvs/rdf/experiments.jsonld",
    log:
        "logs/cmip5_cvs/map_experiments.log",
    shell:
        "(csvjson --no-inference {input.data:q} | jq -f {input.mapping:q}) > {output:q} 2> {log:q}"


# Institutions of the ESGF publisher configuration: [{id, acronym,
# description, models, candidates}], with the fixes of
# mapping/institution-fixes.json (names replaced, institutions excluded)
rule cmip5_cvs_institutions_esgf:
    input:
        checkout=storage.git(
            "{cmip5_cvs[esgf_config_repo]}#{cmip5_cvs[esgf_config_version]}".format(**config)
        ),
        module="data-sources/cmip5-cvs/mapping/esgf-institutions.jq",
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
        " 'include \"esgf-institutions\"; esgf_institutions($models_table; $ini) | fix_institutions($fixes[0])'"
        " > {output:q} 2> {log:q}"


rule cmip5_cvs_map_institutions:
    input:
        data="data-sources/cmip5-cvs/data/institutions-esgf.json",
        mapping="data-sources/cmip5-cvs/mapping/institutions.jq",
    output:
        "data-sources/cmip5-cvs/rdf/institutions.jsonld",
    log:
        "logs/cmip5_cvs/map_institutions.log",
    shell:
        "jq -f {input.mapping:q} {input.data:q} > {output:q} 2> {log:q}"
