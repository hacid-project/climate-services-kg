# Ids of the UKCP18 datasets: their components, and the variables to take from
# them (see the description of the id structures in datasets.jq); and the
# missing units.

import "./mapping/missing-units" as $MISSING_UNITS;

def _id_structure_by_collection_group:
    [
        {
            for_collections: ["land-gcm", "EuroCORDEX", "land-rcm", "land-cpm", "land-derived"],
            id_structure: ["variable", "scenario", "collection", "domain", "resolution", "model_variant_id", "frequency", "date_interval"]
        },
        {
            for_collections: ["land-prob"],
            id_structure: ["variable", "scenario", "collection", "domain", "resolution", "method", "baseline", "timeslice_or_gwl", "frequency", "date_interval"]
        },
        {
            for_collections: ["land-prob-rp"],
            id_structure: ["variable", "return_period", "scenario", "collection", "domain", "resolution", "method", "baseline", "timeslice_or_gwl", "frequency", "date_interval"]
        },
        {
            for_collections: ["land-indices"],
            id_structure: ["variable", "scenario", "collection", "model_variant_id", "frequency", "date_interval"]
        }
    ];

def _id_collection_map:
    {
        "land-eurocordex": "EuroCORDEX"
    };

def _id_comp_pos_by_collection:
    [
        _id_structure_by_collection_group |
        .[] |
        .id_structure as $id_structure |
        .for_collections[] |
        {
            key: .,
            value: (
                [
                    range(0; ($id_structure | length)) |
                    {
                        key: $id_structure[.],
                        value: .
                    }
                ] | from_entries
            )
        }
    ] | from_entries;

def decompose_id($collection):
    (.[:-3] | split("_")) as $id_comp_list |
    _id_comp_pos_by_collection[$collection] |
    with_entries(.value = $id_comp_list[.value]);

# Components of the id of a dataset (input: its metadata)
def id_comp_struct:
    .collection as $collection |
    if .return_period then "\($collection)-rp" else $collection end as $collection |
    .id | decompose_id($collection) |
    .collection |= if in(_id_collection_map) then _id_collection_map[.] end;

# Variables with a wrong value in the metadata of some datasets, replaced by
# the variable in their id (e.g. ensemble_member in EuroCORDEX datasets, var__
# for evspsblveg, air_temperature for tasAnom). The units of ensemble_member
# are not those of the variable: they are removed (see fix_units).
def fix_variable:
    if .collection != "marine-sim" and (.variable | IN("air_temperature", "ensemble_member", "var__")) then
        if .variable == "ensemble_member" then .units = null end |
        .variable = id_comp_struct.variable
    end;

# Units of the variables of the datasets whose units are missing (null or
# "None"), by collection and variable (mapping/missing-units.json): the units
# of the other datasets of the same collection and variable
def _missing_units: $MISSING_UNITS::MISSING_UNITS[0];

# A dataset (input: its metadata) with its units, if missing, taken from
# mapping/missing-units.json
def fix_units:
    if .units == null or .units == "None" then
        .units = _missing_units[.collection][.variable]
    end;
