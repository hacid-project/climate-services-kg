# Framing of the mapped nodes (inputs, read with -n: the output of datasets.jq,
# a node per line) as JSON-LD documents of $block_size nodes (--argjson) with
# the context of the UKCP18 datasets, a document per line.
# The nodes of the CMIP5 and CORDEX-CMIP5 simulations, outputs and models (and
# their membership in the UKCP18 ensembles), given again by each dataset
# referring to them, are written once (among the last $cache_size distinct
# ones, --argjson): the other nodes are all kept, as the nodes of a UKCP18
# simulation, given again by each of its datasets, differ (in the variables of
# its outputs).
# The modules of workflow/scripts must be in the library path (-L).

include "best_effort_unique";
include "paginate";

import "./mapping/context" as CONTEXT;

[
    "https://w3id.org/hacid/data/cs/simulations/cmip5.",
    "https://w3id.org/hacid/data/cs/simulations/cordex.",
    "https://w3id.org/hacid/data/cs/datasets/cmip5.",
    "https://w3id.org/hacid/data/cs/datasets/cordex.",
    "https://w3id.org/hacid/data/cs/mips/",
    "https://w3id.org/hacid/data/cs/models/"
] as $repeated_prefixes |

# The key of a repeated node (the node itself, as a string), null for the others
# (startswith, faster than a regular expression)
def repeated_key:
    ."@id" as $id |
    if ($id | type) == "string" and any($repeated_prefixes[]; . as $prefix | $id | startswith($prefix)) then
        tojson
    else
        null
    end;

paginate(best_effort_unique_by(inputs; repeated_key; $cache_size); $block_size) |
{
    "@context": CONTEXT::context,
    "@graph": .
}
