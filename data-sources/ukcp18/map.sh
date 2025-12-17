#!/usr/bin/env bash

#jq -f 'mapping/map.jq' <data/ukcp18-5km-metadata.json >rdf/ukcp18-5km-metadata.jsonld
#jq -f 'mapping/map.jq' <data/sample.json >rdf/sample.jsonld

jq -f 'mapping/spatial-grids.jq' --null-input | tee >(jq '.grid_map' >'data/spatial-grid-map.json') >rdf/spatial-grids.jsonld
jq -f 'mapping/datasets.jq' <data/ceda_ukcp18_metadata_merged.json >rdf/ceda_ukcp18_metadata_merged.jsonld 2>data/issues.log

