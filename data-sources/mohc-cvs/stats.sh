#!/usr/bin/env bash

jq -f 'indices-stats.jq' <data/Indices.json >data/indices-stats.json
jq -f 'tasks-stats.jq' <data/Tasks.json >data/tasks-stats.json

#jq -f 'stats.jq' <data/sample.json >data/stats.json