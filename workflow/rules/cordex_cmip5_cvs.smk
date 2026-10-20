# Mapping of the CORDEX RCMs, with their institutes, to JSON-LD with jq, from
# the list of IS-ENES Data (CORDEX_RCMs_info.txt, generated from the CORDEX RCM
# registration sheet), read as raw text (mapping/rcms-info.jq), with some
# fixes (mapping/rcm-fixes.json).


rule cordex_cmip5_cvs:
    input:
        "data-sources/cordex-cmip5-cvs/rdf/models.jsonld",


# RCMs: [{model_id, institute_id, institute_name, terms_of_use}], with the
# fixed values and their reasons
rule cordex_cmip5_cvs_rcms:
    input:
        checkout=storage.git("{repo}#{version}".format(**config["cordex_cmip5_cvs"])),
        module="data-sources/cordex-cmip5-cvs/mapping/rcms-info.jq",
        fixes="data-sources/cordex-cmip5-cvs/mapping/rcm-fixes.json",
    output:
        "data-sources/cordex-cmip5-cvs/data/rcms.json",
    log:
        "logs/cordex_cmip5_cvs/rcms.log",
    shell:
        "jq -R -s -L data-sources/cordex-cmip5-cvs/mapping --slurpfile fixes {input.fixes:q}"
        " 'include \"rcms-info\"; rcms_info | fix_rcms($fixes[0])'"
        " {input.checkout:q}/CORDEX_RCMs_info.txt > {output:q} 2> {log:q}"


rule cordex_cmip5_cvs_map:
    input:
        data="data-sources/cordex-cmip5-cvs/data/rcms.json",
        mapping="data-sources/cordex-cmip5-cvs/mapping/models.jq",
    output:
        "data-sources/cordex-cmip5-cvs/rdf/models.jsonld",
    log:
        "logs/cordex_cmip5_cvs/map.log",
    shell:
        "jq -f {input.mapping:q} {input.data:q} > {output:q} 2> {log:q}"
