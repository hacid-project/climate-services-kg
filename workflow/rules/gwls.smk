# The global warming levels (1.5 to 6 °C, by 0.5 °C), generated with jq
# (mapping/gwls.jq) without input.


rule gwls:
    input:
        "data-sources/gwls/rdf/gwls.jsonld",


rule gwls_generate:
    input:
        mapping="data-sources/gwls/mapping/gwls.jq",
    output:
        "data-sources/gwls/rdf/gwls.jsonld",
    log:
        "logs/gwls/generate.log",
    shell:
        "jq -n -f {input.mapping:q} > {output:q} 2> {log:q}"
