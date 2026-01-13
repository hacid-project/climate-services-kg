#!/usr/bin/env bash

jq -f 'stats.jq' <data/ceda_ukcp18_metadata_merged.json >data/stats-all.json
#jq -f 'stats.jq' <data/sample.json >data/stats.json

#jq -f 'spatial-stats.jq' <data/ceda_ukcp18_metadata_merged.json >data/spatial-stats.json
