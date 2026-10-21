#!/bin/sh
# Serves the KG built locally by the workflow (rule consolidate) with Fuseki, to
# inspect it: the TDB2 dataset (kg/tdb2, or the location given as first argument)
# is served read-only at http://localhost:3030/kg (SPARQL endpoint /kg/sparql),
# with the union of the named graphs as the default graph, as seen by the updates
# of the consolidation. fuseki-server (Apache Jena Fuseki) must be on the PATH;
# the dataset cannot be served while the workflow is writing it (TDB2 lock).
# Further arguments are passed to fuseki-server (e.g. --port=3031).
# The union default graph is set in a configuration file, written to a temporary
# file, as the command line of fuseki-server has no option for it (--set was
# removed in Fuseki 6).

LOCATION="${1:-kg/tdb2}"
[ $# -gt 0 ] && shift

if [ ! -d "$LOCATION" ]; then
    echo "No TDB2 dataset at $LOCATION (run the rule consolidate first)" >&2
    exit 1
fi
LOCATION="$(cd "$LOCATION" && pwd)"

CONF_DIR="$(mktemp -d "${TMPDIR:-/tmp}/serve_kg.XXXXXX")" || exit 1
CONF="$CONF_DIR/config.ttl"
trap 'rm -rf "$CONF_DIR"' EXIT
trap 'exit 130' INT TERM

cat > "$CONF" <<EOF
PREFIX :       <#>
PREFIX fuseki: <http://jena.apache.org/fuseki#>
PREFIX tdb2:   <http://jena.apache.org/2016/tdb#>

:service a fuseki:Service ;
    fuseki:name "kg" ;
    fuseki:endpoint [ fuseki:operation fuseki:query ] ;
    fuseki:endpoint [ fuseki:operation fuseki:query ; fuseki:name "sparql" ] ;
    fuseki:endpoint [ fuseki:operation fuseki:query ; fuseki:name "query" ] ;
    fuseki:endpoint [ fuseki:operation fuseki:gsp-r ; fuseki:name "get" ] ;
    fuseki:dataset :dataset .

:dataset a tdb2:DatasetTDB2 ;
    tdb2:location "$LOCATION" ;
    tdb2:unionDefaultGraph true .
EOF

fuseki-server --config="$CONF" "$@"
