#!/usr/bin/env bash

jq -f 'cleansing/methods-add-source.jq' <data/methods.json >data/methods-updated.json

