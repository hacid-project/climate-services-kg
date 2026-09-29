#!/usr/bin/env bash

jq -f 'mapping/aliases.jq' <data/cf-standard-name-table.json >rdf/aliases.jsonld
