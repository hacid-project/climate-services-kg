# Mapping to JSON-LD of the variables of the CMIP5 datasets defined locally for
# their model, as they are not in the CMOR tables (the local entries of
# mapping/variables.json): each variable, in the format of the CMOR tables, is
# mapped as those (variables_jsonld in
# data-sources/cmor-tables/mapping/variables-jsonld.jq), as
# https://w3id.org/hacid/data/cs/variables/cmip5/<model>/<name>, member of the
# collection of the variables of the model (associated with the model), with
# the label "<long name> (<name>, <model>)".
#
# Input: mapping/variables.json. Arguments: --slurpfile cf_names
# data-sources/cf-standard-names/data/standard-names.json, --slurpfile cf_fixes
# data-sources/cmor-tables/mapping/cf-standard-name-fixes.json; the modules of
# this directory and of data-sources/cmor-tables/mapping must be in the library
# path (-L).

include "variables-jsonld";
include "esgf";

cf_standard_names($cf_names[0]; $cf_fixes[0]) as $cf |
[
    .local | to_entries[] |
    .key as $model |
    (
        .value | to_entries | map(.value + {out_name: .key}) |
        variables_jsonld(
            .out_name | cmip5_model_variable_iri($model);
            "\(.long_name) (\(.out_name), \($model))";
            cmip5_model_variables_collection($model);
            $cf
        )
    ),
    {
        "@context": {
            rdfs: "http://www.w3.org/2000/01/rdf-schema#",
            top: "https://w3id.org/hacid/onto/top-level/"
        },
        "@graph": [
            {
                "@id": cmip5_model_variables_collection($model),
                "@type": "top:Collection",
                "rdfs:label": {"@value": "\($model) variables", "@language": "en"},
                "rdfs:comment": {
                    "@value": "Collection of the variables of the CMIP5 datasets of the model \($model) that are not in the CMIP5 CMOR tables.",
                    "@language": "en"
                },
                "top:associatedWith": {"@id": (ns + "models/" + ($model | quote))}
            }
        ]
    }
] |
{
    "@context": (map(."@context") | add),
    "@graph": (map(."@graph"[]) | unique)
}
