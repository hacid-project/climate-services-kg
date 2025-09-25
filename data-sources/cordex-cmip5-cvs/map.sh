#!/usr/bin/env bash

csvjson data/CORDEX_RCMs.csv | jq -f 'mapping/models.jq' >rdf/models.jsonld
