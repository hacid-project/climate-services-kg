#!/usr/bin/env bash

jq --library-path 'mapping' -f 'mapping/sample.jq' <data/ceda_ukcp18_metadata_merged.json >data/sample-by-kind.json
