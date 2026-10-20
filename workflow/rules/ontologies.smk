# The HACID ontologies used by the KG, from their git repository
# (hacid-project/knowledge-graph, ontologies/{name}/{name}.owl), at the commit
# of config.yaml (ontologies).


rule ontologies:
    input:
        expand("data-sources/ontologies/{name}.owl", name=config["ontologies"]["names"]),


rule ontologies_owl:
    input:
        checkout=storage.git("{repo}#{version}".format(**config["ontologies"])),
    output:
        "data-sources/ontologies/{name}.owl",
    wildcard_constraints:
        name="|".join(config["ontologies"]["names"]),
    shell:
        "cp {input.checkout:q}/ontologies/{wildcards.name}/{wildcards.name}.owl {output:q}"
