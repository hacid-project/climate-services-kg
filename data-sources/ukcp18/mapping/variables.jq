# Mapping of the local variables of the UKCP18 datasets (mapping/ukcp-variables.json)
# to JSON-LD, with their units and baseline periods (no input).

import "./mapping/context" as CONTEXT;
import "./mapping/ukcp18-variables" as VARIABLES;

{
    "@context": CONTEXT::context,
    "@graph": VARIABLES::ukcp_variable_nodes
} |
walk( if type == "object" or type =="array" then map_values( select(values) ) end )
