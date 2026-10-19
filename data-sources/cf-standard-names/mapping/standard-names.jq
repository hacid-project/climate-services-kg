# Mapping of the CF standard name table (data/cf-standard-name-table.json,
# converted from the XML of the table) to JSON-LD: a variable for each entry,
# member of the CF variables, with its units of measure, and the aliases, the
# same as (owl:sameAs) their entries, with the alias as alternative label.
#
# The entries whose name is also an alias (of another entry) are left out, see
# DECISIONS.md. Empty units or descriptions are left out.

def present: select(. != "");

.standard_name_table |
[.alias[].id] as $aliases |
[.entry[] | select(.id | IN($aliases[]) | not)] as $entries |
{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        owl: "http://www.w3.org/2002/07/owl#",
        top: "https://w3id.org/hacid/onto/top-level/",
        data: "https://w3id.org/hacid/onto/data/",
        label: {"@id": "rdfs:label", "@language": "en"},
        comment: {"@id": "rdfs:comment", "@language": "en"},
        isMemberOf: {"@id": "top:isMemberOf", "@type": "@id"},
        hasUnitOfMeasure: {"@id": "top:hasUnitOfMeasure", "@type": "@id"},
        hasValuesOn: {"@id": "data:hasValuesOn", "@type": "@id"},
        sameAs: {"@id": "owl:sameAs", "@type": "@id"},
        altLabel: "top:altLabel"
    },
    "@graph": [
        # Variables
        (
            $entries[] |
            ((.canonical_units | present | @uri "https://w3id.org/hacid/data/cs/unitsofmeasure/\(.)") // null) as $unit |
            {
                "@id": @uri "https://w3id.org/hacid/data/cs/variables/cf/\(.id)",
                "@type": "data:DeterministicVariable",
                isMemberOf: "https://w3id.org/hacid/data/cs/variables/cf",
                label: .id,
                comment: ((.description | present) // null),
                hasUnitOfMeasure: $unit,
                hasValuesOn: $unit
            } |
            with_entries(select(.value != null))
        ),
        # Units of measure
        (
            [$entries[].canonical_units | present] | unique | .[] |
            {
                "@id": @uri "https://w3id.org/hacid/data/cs/unitsofmeasure/\(.)",
                "@type": ["top:UnitOfMeasure", "data:DimensionalSpace"],
                "rdfs:label": .
            }
        ),
        # Aliases
        (
            .alias[] |
            {
                "@id": @uri "https://w3id.org/hacid/data/cs/variables/cf/\(.id)",
                sameAs: @uri "https://w3id.org/hacid/data/cs/variables/cf/\(.entry_id)"
            },
            {
                "@id": @uri "https://w3id.org/hacid/data/cs/variables/cf/\(.entry_id)",
                altLabel: .id
            }
        )
    ]
}
