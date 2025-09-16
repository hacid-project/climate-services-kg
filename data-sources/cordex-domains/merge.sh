#!/usr/bin/env bash

INPUT_REGULAR="raw-data/CORDEX-CMIP5_regular_grids.csv"
INPUT_ROTATED="raw-data/CORDEX-CMIP5_rotated_grids.csv"
OUTPUT="data/CORDEX-CMIP5.csv"

awk <$INPUT_ROTATED -F',' '{
    if (NR == 1)
        print "type,area_id," $0
    else
        print "rotated," substr($2,1,3) "," $0
}' >$OUTPUT

awk <$INPUT_REGULAR -F',' '{
    if (NR > 1)
        print "regular," substr($2,1,3) "," $0
}' >>$OUTPUT
