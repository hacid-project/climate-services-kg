#!/usr/bin/env bash

jq -f 'cleansing/methods-add-source.jq' <data/methods.json >data/methods-updated.json
jq -f 'cleansing/indices-add-variants.jq' <data/indices.json >data/indices-updated.json

