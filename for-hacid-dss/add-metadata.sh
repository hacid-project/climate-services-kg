#!/usr/bin/env bash

jq --indent 4 -f 'add-metadata.jq' <../data-sources/mohc-cvs/rdf/operations.jsonld >output/tasks.json

