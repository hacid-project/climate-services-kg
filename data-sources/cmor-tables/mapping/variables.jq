# Mapping of the variable definitions of one edition of the CMOR tables to JSON-LD.
#
# Input: the array of the tables of the edition (see variables-jsonld.jq).
# Each out_name is a variable https://w3id.org/hacid/data/cs/variables/mip/<out_name>.
# Arguments: --slurpfile cf_names data-sources/cf-standard-names/data/standard-names.json
# --slurpfile cf_fixes data-sources/cmor-tables/mapping/cf-standard-name-fixes.json
# (see cf_standard_names in variables-jsonld.jq)
#
#   jq -L data-sources/cmor-tables/mapping --slurpfile cf_names <names> --slurpfile cf_fixes <fixes> \
#       -f data-sources/cmor-tables/mapping/variables.jq <tables>

include "./variables-jsonld";

variable_entries |
variables_jsonld(
    @uri "https://w3id.org/hacid/data/cs/variables/mip/\(.out_name)";
    "\(.long_name) (\(.out_name))";
    cf_standard_names($cf_names[0]; $cf_fixes[0])
)
