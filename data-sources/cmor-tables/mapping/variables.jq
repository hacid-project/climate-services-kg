# Mapping of the variable definitions of one edition of the CMOR tables to JSON-LD.
#
# Input: the array of the tables of the edition (see variables-jsonld.jq).
# Each out_name is a variable https://w3id.org/hacid/data/cs/variables/mip/<out_name>.
#
#   jq -L data-sources/cmor-tables/mapping -f data-sources/cmor-tables/mapping/variables.jq <tables>

include "./variables-jsonld";

variable_entries |
variables_jsonld(
    @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.out_name)";
    "\(.long_name) (\(.out_name))"
)
