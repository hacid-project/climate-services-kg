# Mapping of variable definitions of the CMOR tables to JSON-LD (module, used
# by variables.jq and mip-previous-variables.jq, and for the tables in the same
# format of other sources, as data-sources/cordex-cmip5/mapping/variables.jq).
#
# The tables of an edition have the shape of CMOR 3 JSON tables (legacy CMOR 2
# tables are converted by cmor2-tables.jq)
#   [{"Header": {...}, "variable_entry": {"tas": {...}, ...}, ...}, ...]
# Tables without variable entries (e.g. CV or coordinates) are ignored.
#
# Port of the RML mapping in ../rml/variables.ttl (same IRIs and triples), except
# that a variable in multiple realms (e.g. "atmos atmosChem") is now a member of
# each of them, instead of a single realm named after the whole string.

# Lists in the tables are either space-separated strings (CMIP5/CMIP6) or arrays (MIP tables)
def words:
    if type == "array" then .[]
    elif type == "string" then splits("\\s+") | select(. != "")
    else empty
    end;

# Missing values are not mapped
def present: select(. != null and . != "");

# CF standard names, to link the variables to the CF variables of the KG only
# by names of the CF standard name table: {names, fixes}, from the names of the
# table ($names, data-sources/cf-standard-names/data/standard-names.json, its
# entries and aliases) and the corrections of the names of the CMOR tables that
# are not in it ($fixes, cf-standard-name-fixes.json, {<name>: {standard_name,
# note}})
def cf_standard_names($names; $fixes):
    {names: ($names | map({key: ., value: true}) | from_entries), fixes: $fixes};

# The CF standard name of a standard name of the CMOR tables (input), given the
# CF standard names ($cf, see cf_standard_names): the name or its correction,
# if in the table, otherwise none (e.g. placeholders as "missing")
def cf_standard_name($cf):
    ($cf.fixes[.].standard_name // .) | select($cf.names[.]);

# Dimensions (CMOR axes) to dimensional spaces (see data-sources/common-spacetime.ttl)
def _dimension_map:
    {
        "longitude": ["geodetic"],
        "xant": ["geodetic"],
        "xgre": ["geodetic"],
        "time": ["time"],
        "time1": ["time"],
        "time2": ["time"],
        "time3": ["time"],
        "gridlatitude": ["geodetic-lat"],
        # rotated grids of the CORDEX tables (rlon rlat, as longitude latitude)
        "rlon": ["geodetic"],
        "alevel": ["elevation"],
        "alevhalf": ["elevation"],
        "olevel": ["elevation"]
    };

# Variable entries of all the tables, with their out_name and table
# (table_id without the "Table " prefix of the CMIP5/CMIP6 tables)
def variable_entries:
    [
        .[] |
        ((.Header.table_id // "") | sub("^Table "; "")) as $table |
        .variable_entry // {} | to_entries.[] |
        .value + {out_name: ((.value.out_name | present) // .key), table: $table}
    ];

# JSON-LD document of variable entries (as given by variable_entries), with the
# IRI and the label of each variable given by iri_of and label_of (applied to
# the entry; the label only if the entry has a long_name), members of the
# collection $collection (and of their realms), specializations of the CF
# variables of their standard names ($cf, see cf_standard_names and
# cf_standard_name)
def variables_jsonld(iri_of; label_of; $collection; $cf):
    . as $entries |
    _dimension_map as $dimension_map |
    {
        "@context": {
            rdfs: "http://www.w3.org/2000/01/rdf-schema#",
            top: "https://w3id.org/hacid/onto/top-level/",
            data: "https://w3id.org/hacid/onto/data/",
            label: {"@id": "rdfs:label", "@language": "en"},
            comment: {"@id": "rdfs:comment", "@language": "en"},
            acronym: {"@id": "top:acronym", "@language": "en"},
            isMemberOf: {"@id": "top:isMemberOf", "@type": "@id"},
            isSpecializationOfVariable: {"@id": "data:isSpecializationOfVariable", "@type": "@id"},
            dependsOnVariable: {"@id": "data:dependsOnVariable", "@type": "@id"},
            hasUnitOfMeasure: {"@id": "top:hasUnitOfMeasure", "@type": "@id"},
            hasValuesOn: {"@id": "data:hasValuesOn", "@type": "@id"}
        },
        "@graph": [
            # Variables
            (
                [
                    $entries.[] |
                    .out_name as $out_name |
                    ((.units | present | @uri "https://w3id.org/hacid/data/cs/unitsofmeasure/\(.)") // null) as $unit |
                    {
                        "@id": iri_of,
                        "@type": "data:DeterministicVariable",
                        isMemberOf: [
                            $collection,
                            (.modeling_realm | words | @uri "https://w3id.org/hacid/data/cs/realms/\(.)")
                        ],
                        label: (((.long_name | present) as $long_name | label_of) // null),
                        isSpecializationOfVariable: (
                            (
                                .standard_name | present | cf_standard_name($cf) |
                                @uri "https://w3id.org/hacid/data/cs/variables/cf/\(.)"
                            ) // null
                        ),
                        dependsOnVariable: [
                            .dimensions | words | $dimension_map[.] // [] | .[] |
                            @uri "https://w3id.org/hacid/data/cs/dimensions/\(.)"
                        ] | unique,
                        comment: ((.comment | present) // null),
                        acronym: $out_name,
                        hasUnitOfMeasure: $unit,
                        hasValuesOn: $unit
                    } |
                    with_entries(select(.value != null and .value != []))
                ] | unique | .[]
            ),
            # Realms
            (
                [$entries.[] | .modeling_realm | words] | unique | .[] |
                {
                    "@id": @uri "https://w3id.org/hacid/data/cs/realms/\(.)",
                    "@type": "top:Collection"
                }
            ),
            # Units of measure
            (
                [$entries.[] | .units | present] | unique | .[] |
                {
                    "@id": @uri "https://w3id.org/hacid/data/cs/unitsofmeasure/\(.)",
                    "@type": ["top:UnitOfMeasure", "data:DimensionalSpace"],
                    "rdfs:label": .
                }
            )
        ]
    };

# JSON-LD document of variable entries of the CMOR tables, members of the
# collection of the MIP variables
def variables_jsonld(iri_of; label_of; $cf):
    variables_jsonld(iri_of; label_of; "https://w3id.org/hacid/data/cs/variables/mip"; $cf);
