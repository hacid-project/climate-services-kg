#!/usr/bin/env bash

jq -f 'cleansing/indices.jq' <data-raw-json/Indices.json >data/indices.json
jq -f 'cleansing/tasks.jq' <data-raw-json/Tasks.json >data/operations.json
jq -f 'cleansing/hazards.jq' <data-raw-json/Hazards.json >data/hazards.json
#jq -f 'stats.jq' <data/indices.json >stats/indices-stats.json

