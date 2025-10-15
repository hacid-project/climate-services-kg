#!/usr/bin/env bash

jq -f 'mapping/indices.jq' <data/indices.json >rdf/indices.jsonld
jq -f 'mapping/operations.jq' <data/operations.json >rdf/operations.jsonld