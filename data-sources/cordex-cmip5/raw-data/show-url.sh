#!/usr/bin/env bash

BASE_URL="https://esgf.ceda.ac.uk/esg-search/search/"
FILTER_ITEM_TYPE="Dataset"
FILTER_PROJECTS="CORDEX"
FILTER_EXPERIMENTS="historical%2Crcp26%2Crcp45%2Crcp85"
REQUESTED_FACETS="rcm_name%2Cproject%2Cproduct%2Cdomain%2Cinstitute%2Cdriving_model%2Cexperiment%2Cexperiment_family%2Censemble%2Crcm_version%2Ctime_frequency%2Cvariable%2Cvariable_long_name%2Ccf_standard_name%2Cdata_node"
REQUESTED_FORMAT="application%2Fsolr%2Bjson"
BASE_PARAMS="replica=false&latest=true&format=$REQUESTED_FORMAT"
PARAMS="?$BASE_PARAMS&type=$FILTER_ITEM_TYPE&project=$FILTER_PROJECTS&experiment=$FILTER_EXPERIMENTS&facets=$REQUESTED_FACETS"
URL="$BASE_URL$PARAMS"

echo $URL
