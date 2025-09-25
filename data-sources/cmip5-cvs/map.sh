#!/usr/bin/env bash

csvjson data/institutions.csv | jq -f 'mapping/institutions.jq' >rdf/institutions.jsonld
csvjson data/experiments.csv | jq -f 'mapping/experiments.jq' >rdf/experiments.jsonld