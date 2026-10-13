# IRI of the MIP variable corresponding to a variable of any edition of the
# CMOR tables (see mip-variables.jq for the input and mip-mapping.md).
#
#   jq -L data-sources/cmor-tables/mapping -f data-sources/cmor-tables/mapping/mip-variable-iri.jq <<< '{"out_name": "hus", "era": "cmip6", "table": "Amon", "dimensions": "longitude latitude plev19 time"}'
#   "https://w3id.org/hacid/data/cs/variables/mip/hus19"
#
# With --arg details true, the whole resolution is returned instead.

include "./mip-variables";

if $ARGS.named.details == "true" then mip_variable_resolution else mip_variable_iri end
