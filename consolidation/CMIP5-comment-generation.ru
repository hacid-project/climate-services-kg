PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

INSERT  { ?s rdfs:comment ?comment. }
WHERE {
  # Any single GCM simulation
  ?s a ccso:GlobalClimateSimulation, ccso:SingleSimulation ;
     rdfs:label ?label .

  FILTER(STRSTARTS(LCASE(STR(?label)), "cmip5."))
  FILTER NOT EXISTS { ?s rdfs:comment ?_already }

  # --- parse cmip5.<gcmCode>.<scenCode>.<rip> from the label ---

  BIND(STR(?label) AS ?L)
  BIND(STRAFTER(?L, "cmip5.") AS ?rest1)
  BIND(STRBEFORE(?rest1, ".") AS ?gcmCode)
  BIND(STRAFTER(?rest1, CONCAT(?gcmCode, ".")) AS ?rest2)
  BIND(STRBEFORE(?rest2, ".") AS ?scenCode)
  BIND(STRAFTER(?rest2, CONCAT(?scenCode, ".")) AS ?rip)

  # scenario label (RCP names)
  BIND(LCASE(STR(?scenCode)) AS ?scenLower)
  BIND(
    IF(?scenLower = "rcp26", "RCP2.6",
    IF(?scenLower = "rcp45", "RCP4.5",
    IF(?scenLower = "rcp60", "RCP6.0",
    IF(?scenLower = "rcp85", "RCP8.5",
       STR(?scenCode))))) AS ?scenarioName
  )

  # --- OPTIONAL model + institution from the KG ---

  OPTIONAL {
    ?s ccso:usesModel ?gcmRes .

    OPTIONAL {
      ?gcmRes rdf:type ?gcmType .
      ?gcmType rdfs:subClassOf* ccso:ClimateModel .
    }

    OPTIONAL { ?gcmRes rdfs:label ?gcmLabel . }

    OPTIONAL {
      ?gcmRes ccso:isMaintainedBy ?inst .
      OPTIONAL { ?inst rdfs:label ?instLabel . }
    }
  }

  # --- build comment even if some bits are missing ---

  BIND(
    CONCAT(
      "GCM simulation from CMIP5. ",
      "Scenario: ", COALESCE(?scenarioName, "unknown"), ". ",
      "The GCM used is ",
         COALESCE(STR(?gcmLabel), STR(?gcmCode), "unknown"),
      IF(BOUND(?instLabel),
         CONCAT(" (", STR(?instLabel), ")"),
         ""),
      ". Ensemble member: ",
         COALESCE(STR(?rip), "unknown"),
      "."
    ) AS ?comment
  )
}
