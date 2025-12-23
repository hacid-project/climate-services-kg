#!/usr/bin/env bash

#jq -f 'mapping/map.jq' <data/ukcp18-5km-metadata.json >rdf/ukcp18-5km-metadata.jsonld
#jq -f 'mapping/map.jq' <data/sample.json >rdf/sample.jsonld

jq --library-path 'mapping' -f 'mapping/spatial-grids.jq' --null-input | tee >(jq '.grid_map' >'data/spatial-grid-map.json') >rdf/spatial-grids.jsonld
jq --library-path 'mapping' -f 'mapping/datasets.jq' <data/sample-by-kind.json >rdf/sample-by-kind.jsonld 2>data/issues.log

