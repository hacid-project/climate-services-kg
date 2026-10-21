#!/bin/sh
# Serves the KG built locally by the workflow (rule consolidate) with Fuseki, to
# inspect it: the TDB2 dataset (kg/tdb2, or the location given as first argument)
# is served read-only at http://localhost:3030/kg (SPARQL endpoint /kg/sparql),
# with the union of the named graphs as the default graph, as seen by the updates
# of the consolidation. fuseki-server (Apache Jena Fuseki) must be on the PATH;
# the dataset cannot be served while the workflow is writing it (TDB2 lock).
# Further arguments are passed to fuseki-server (e.g. --port=3031).

LOCATION="${1:-kg/tdb2}"
[ $# -gt 0 ] && shift

exec fuseki-server --loc "$LOCATION" --set tdb:unionDefaultGraph=true "$@" /kg
