#!/usr/bin/env bash

#jq --library-path 'mapping' -f 'mapping/spatial-grids.jq' --null-input | tee >(jq '.grid_map' >'data/spatial-grid-map.json') >rdf/spatial-grids.jsonld
#jq --library-path 'mapping' -f 'mapping/extract-model-variants.jq' <data/ceda_ukcp18_metadata_merged.json >data/model-variants.json
jq --library-path 'mapping' -f 'mapping/datasets.jq' <data/sample-by-kind.json >rdf/sample-by-kind.jsonld 2>data/issues.log

