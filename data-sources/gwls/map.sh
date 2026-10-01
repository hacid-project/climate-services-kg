#!/usr/bin/env bash

jq -f 'mapping/gwls.jq' --null-input >rdf/gwls.jsonld