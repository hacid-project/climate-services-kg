#!/usr/bin/env bash

jq -f 'mapping/indices.jq' <data/Indices.json >rdf/indices.jsonld