# Mapping of the variable definitions of one edition of the CMOR tables to JSON-LD.
#
# Input: an edition document, as produced by workflow/scripts/extract-cmor-tables.sh
#   {
#     "source": "cmip6", "edition": "6.9.33", "repository": "...", "commit": "...",
#     "tables": [{"file": "Tables/CMIP6_Amon.json", "Header": {...}, "variable_entry": {...}}, ...]
#   }
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

# Dimensions (CMOR axes) to dimensional spaces (see data-sources/common-spacetime.ttl)
{
    "longitude": ["geodetic"],
    "xant": ["geodetic"],
    "xgre": ["geodetic"],
    "time": ["time"],
    "time1": ["time"],
    "time2": ["time"],
    "time3": ["time"],
    "gridlatitude": ["geodetic-lat"],
    "alevel": ["elevation"],
    "alevhalf": ["elevation"],
    "olevel": ["elevation"]
} as $dimension_map |

# Variable entries of all the tables
[
    .tables.[] | .variable_entry // {} | to_entries.[] |
    .value + {out_name: ((.value.out_name | present) // .key)}
] as $entries |

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
                    "@id": @uri "https://w3id.org/hacid/data/cs/variables/mip/\($out_name)",
                    "@type": "data:Variable",
                    isMemberOf: [
                        "https://w3id.org/hacid/data/cs/variables/mip",
                        (.modeling_realm | words | @uri "https://w3id.org/hacid/data/cs/realms/\(.)")
                    ],
                    label: ((.long_name | present | "\(.) (\($out_name))") // null),
                    isSpecializationOfVariable: (
                        (.standard_name | present | @uri "https://w3id.org/hacid/data/cs/variables/cf/\(.)") // null
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
}
