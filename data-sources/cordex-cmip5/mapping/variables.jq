# Mapping to JSON-LD of the variables of the CORDEX-CMIP5 datasets defined
# locally: the variables requested by CORDEX (the CORDEX standard output,
# CORDEX_standard_output.json, in the format of the CMOR tables) that are not
# variables of the KG (see local_variables in cordex-variables.jq), mapped as
# the variables of the CMOR tables (variables_jsonld in
# data-sources/cmor-tables/mapping/variables-jsonld.jq), as
# https://w3id.org/hacid/data/cs/variables/cordex/<out_name>, members of the
# collection https://w3id.org/hacid/data/cs/variables/cordex.
#
# Arguments (run with -n): --slurpfile standard_output
# CORDEX_standard_output.json, --slurpfile cmor_tables (the CMIP5 CMOR tables,
# as for datasets.jq), --slurpfile kg_variables
# data-sources/cmor-tables/data/variable-iris.json; the modules of this
# directory, of data-sources/cmip5/mapping and of
# data-sources/cmor-tables/mapping must be in the library path (-L).

include "variables-jsonld";
include "esgf";
include "cordex-variables";

($cmor_tables[0] | cmip5_entries_by_name) as $entries_by_name |
($kg_variables[0] | iri_set) as $kg |
[local_variables($standard_output[0]; $entries_by_name; $kg) | to_entries[] | .value + {out_name: .key}] |
variables_jsonld(
    .out_name | cordex_variable_iri;
    "\(.long_name) (\(.out_name))";
    cordex_variables_collection
)
