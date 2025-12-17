#!/usr/bin/env bash

jq -f 'missingBasics.jq' <data/ceda_ukcp18_metadata_merged.json >data/missingBasics.json
#jq -f 'stats.jq' <data/sample.json >data/stats.json