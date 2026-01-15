#!/usr/bin/env bash

jq --library-path 'mapping' -f 'add-metadata.jq' <../data-sources/mohc-cvs/rdf/operations.jsonld >output/tasks.json

