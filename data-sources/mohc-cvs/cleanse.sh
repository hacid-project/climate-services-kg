#!/usr/bin/env bash

jq -f 'cleansing/get_climdex_index_names.jq' <../climdex/rdf/climdex.jsonld >data/climdex_index_names.json
jq -f 'cleansing/indices.jq' <data-raw-json/Indices.json >data/indices.json
jq -f 'cleansing/tasks.jq' <data-raw-json/Tasks.json >data/operations.json
jq -f 'cleansing/hazards.jq' <data-raw-json/Hazards.json >data/hazards.json
jq -f 'cleansing/methods.jq' <data-raw-json/Methods.json >data/methods.json

