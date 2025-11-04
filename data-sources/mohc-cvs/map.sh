#!/usr/bin/env bash

jq -f 'mapping/indices.jq' <data/indices.json >rdf/indices.jsonld
jq -f 'mapping/cvs.jq' <data/cv-map.json >rdf/cvs.jsonld
jq -f 'mapping/operations.jq' <data/operations.json >rdf/operations.jsonld
jq -f 'mapping/methods.jq' <data/methods.json >rdf/methods.jsonld
jq -f 'mapping/hazards.jq' <data/hazards.json >rdf/hazards.jsonld