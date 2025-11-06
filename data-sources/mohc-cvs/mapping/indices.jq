def to_camel_case:
    split(" ") |
    map((.[:1] | ascii_upcase) + (.[1:] | ascii_downcase)) |
    join("");

{
    "@context": {
        rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        data: "https://w3id.org/hacid/onto/data/",
        cs: "https://w3id.org/hacid/data/cs/",
        sector: "https://w3id.org/hacid/data/cs/climdex/sectors/",
        variable: "https://w3id.org/hacid/data/cs/variables/mip/",
        unit: "https://w3id.org/hacid/data/cs/unitsofmeasure/",
        dimension: "https://w3id.org/hacid/data/cs/dimensions/",
        label: "rdfs:label",
        comment: "rdfs:comment",
        acronym: "top:acronym",
        Definition: "top:definition",
        Unit: {
            "@id": "top:hasUnitOfMeasure",
            "@type": "@id"
        },
        hasValuesOn: {
            "@id": "data:hasValuesOn",
            "@type": "@id"
        },
        dependsOnVariable: {
            "@id": "data:dependsOnVariable",
            "@type": "@id"
        },
        suggestedQuantization: {
            "@id": "data:hasSuggestedQuantization",
            "@type": "@id"
        },
        derivedFrom: {
            "@id": "data:derivedFromVariable",
            "@type": "@id"
        },
        relatedTo: {
            "@id": "top:isRelatedToConcept",
            "@type": "@id"
        },
        identicalTo: {
            "@id": "data:isEquivalentTo",
            "@type": "@id"
        },
        Sectors: {
            "@id": "top:isClassifiedBy",
            "@type": "@id"
        },
        members: {
            "@reverse": "top:inScheme",
            "@type": "@id"
        }
    },
    "@graph": [
        to_entries | .[] |
        (.key | sub(" ";"-")) as $group_id |
        {
            "@id": @uri "cs:\($group_id)/indices",
            "@type": "top:ConceptScheme",
            members: [
                .value | to_entries | .[] |
                .key as $index_name |
                .value as $index_body |
#                (.key | to_camel_case) as $index_id |
                [
                    .value.Variants[] |
                    .Type as $variant_type |
                    (.References[]? // null) as $reference |
                    $index_body |
                    (."@id" = "cs:\($group_id)/indices/\($index_name | to_camel_case)\(
                        if $variant_type == "absolute" then
                            ""
                        else 
                            "/\($variant_type)\(
                                if $reference != null then
                                    "/\($reference)"
                                else
                                    ""
                                end
                            )"
                        end
                    )") |
                    (.label = "\($index_name)\(
                        if $variant_type == "absolute" then
                            ""
                        else 
                            " (\(
                                if $variant_type == "change-relative" then
                                    "% "
                                else
                                    ""
                                end
                            )change\(
                                if $reference != null then
                                    " from \($reference)"
                                else
                                    ""
                                end
                            ))"
                        end
                    )") |
                    if $variant_type == "change-relative" then
                        .Unit = "%"
                    end |
                    if .Unit then
                        .Unit |= {
                            "@id": @uri "unit:\(.)",
                            label: .
                        }
                    end |
                    del(.Variants)
                ] |
                . as $variants |
                range(. | length) |
                (if . > 0 then $variants[. - 1] else null end) as $prev_variant |
                $variants[.] |
                if $prev_variant then
                    .derivedFrom = $prev_variant."@id"
                else
                    . + (
                        [
                            if .AssociatedVariables then
                                .AssociatedVariables[] |
                                {
                                    type: "derivedFrom",
                                    related: @uri "variable:\(.)"
                                }
                            else
                                empty
                            end,
                            if .LinkToCLIMDEX then
                                .CLIMDEXRelation as $type |
                                {
                                    type: $type,
                                    related: @uri "climdex:\(.LinkToCLIMDEX)"
                                }
                            else
                                empty
                            end,
                            if .LinkedIndicators then
                                .LinkedIndicatorRelation as $type |
                                .LinkedIndicators | to_entries | .[] |
                                (.key | sub(" ";"-")) as $group_id |
                                .value[] |
                                {
                                    type: $type,
                                    related: "cs:\($group_id)/indices/\(. | to_camel_case)"
                                }
                            else
                                empty
                            end
                        ] |
                        group_by(.type) |
                        [
                            .[] | {
                                key: .[0].type,
                                value: [.[].related]
                            }
                        ] | from_entries
                    )
                end |
                if .Sectors then
                    .Sectors |= map(@uri "sector:\(.)")
                end |
                del(.DefinitionSource) |
                del(._AssociatedVariable) |
                del(.AssociatedVariables) |
                del(.LinkToCLIMDEX) | del(.CLIMDEXRelation) |
                del(.LinkedIndicators) | del(.LinkedIndicatorRelation)
            ]
        }
    ]
}

