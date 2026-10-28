# Framing of mapped nodes (input: an array of JSON-LD nodes without context, e.g.
# a page of the output of datasets.jq, workflow/scripts/paginate.jq) as a JSON-LD document
# with the context of the UKCP18 datasets

import "./mapping/context" as CONTEXT;

{
    "@context": CONTEXT::context,
    "@graph": .
}
