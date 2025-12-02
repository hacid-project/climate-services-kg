PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

INSERT  { ?s rdfs:comment ?comment. }
WHERE {
  # Any CORDEX simulation (Simulation or subclass) without a comment
  ?s a ccso:DynamicalDownscaling, ccso:SingleSimulation ; ;
     rdfs:label ?label .

  FILTER(STRSTARTS(LCASE(STR(?label)), "cordex."))
  FILTER NOT EXISTS { ?s rdfs:comment ?_already }

  BIND(STR(?label) AS ?L)

  # Strip "cordex."
  BIND(STRAFTER(?L, "cordex.") AS ?afterCordex)

  # {domain}-{res} part
  BIND(STRBEFORE(?afterCordex, ".") AS ?domRes)              # e.g. "EUR-44"
  BIND(STRBEFORE(?domRes, "-") AS ?domainCode)               # "EUR"
  BIND(STRAFTER(?domRes, CONCAT(?domainCode, "-")) AS ?res)  # "44" or "44i"

  # Tail after domain-resolution
  BIND(STRAFTER(?afterCordex, CONCAT(?domRes, ".")) AS ?tail)

  # First two segments after domRes
  BIND(STRBEFORE(?tail, ".") AS ?seg1)
  BIND(STRAFTER(?tail, CONCAT(?seg1, ".")) AS ?afterSeg1)
  BIND(STRBEFORE(?afterSeg1, ".") AS ?seg2)

  # Is seg1 actually a scenario? (short pattern: no GCM in label)
  BIND(LCASE(STR(?seg1)) AS ?seg1Lower)
  BIND(
    IF(
      ?seg1Lower = "historical" ||
      ?seg1Lower = "rcp26" ||
      ?seg1Lower = "rcp45" ||
      ?seg1Lower = "rcp60" ||
      ?seg1Lower = "rcp85",
      true,
      false
    ) AS ?seg1IsScenario
  )

  # Scenario code
  BIND(
    IF(?seg1IsScenario,
       ?seg1,        # cordex.DOM-RES.SCEN.RCM.vVER
       ?seg2         # cordex.DOM-RES.GCM.SCEN.RCM.vVER.RIP
    ) AS ?scen
  )

  # GCM code (empty string if not present in label)
  BIND(
    IF(?seg1IsScenario,
       "",
       STR(?seg1)
    ) AS ?gcmCode
  )

  # RCM code
  BIND(
    IF(?seg1IsScenario,
       STR(?seg2),   # short pattern: seg2 is RCM
       STRBEFORE(
         STRAFTER(?afterSeg1, CONCAT(?seg2, ".")),
         "."
       )             # full pattern: 3rd segment is RCM
    ) AS ?rcmCode
  )

  # Version + optional ensemble: everything after ".v"
  BIND(
    IF(
      ?seg1IsScenario,
      STRAFTER(
        ?L,
        CONCAT("cordex.", ?domRes, ".", ?scen, ".", ?rcmCode, ".v")
      ),
      STRAFTER(
        ?L,
        CONCAT("cordex.", ?domRes, ".", ?gcmCode, ".", ?scen, ".", ?rcmCode, ".v")
      )
    ) AS ?verRip
  )

  # Version: if there's a ".", take part before it, else entire verRip
  BIND(
    IF(CONTAINS(?verRip, "."),
       STRBEFORE(?verRip, "."),
       ?verRip
    ) AS ?ver
  )

  # Ensemble member (may be absent in short pattern)
  BIND(
    IF(CONTAINS(?verRip, "."),
       STRAFTER(?verRip, CONCAT(?ver, ".")),
       ""
    ) AS ?rip
  )

  # Scenario name mapping
  BIND(LCASE(STR(?scen)) AS ?scenLower)
  BIND(
    IF(?scenLower = "rcp26", "RCP2.6",
    IF(?scenLower = "rcp45", "RCP4.5",
    IF(?scenLower = "rcp60", "RCP6.0",
    IF(?scenLower = "rcp85", "RCP8.5",
    IF(?scenLower = "historical", "Historical",
       STR(?scen))))))
    AS ?scenarioName
  )

  # Resolution → degrees & km; detect 'i' suffix (regular grid)
  BIND(IF(REGEX(?res, "i$"), REPLACE(?res, "i$", ""), ?res) AS ?resCode)
  BIND(CONCAT("0.", ?resCode) AS ?deg)

  VALUES (?resCode ?km) {
    ("44" "50")
    ("22" "25")
    ("11" "12.5")
  }
  BIND(IF(BOUND(?km), ?km, "") AS ?kmApprox)
  BIND(IF(REGEX(?res, "i$"), " (regular grid)", "") AS ?regularNote)

  # Domain code → name
  VALUES (?domainCode ?domainName) {
    ("EUR" "Europe")
    ("AFR" "Africa")
    ("ANT" "Antarctica")
    ("ARC" "Arctic")
    ("AUS" "Australasia")
    ("EAS" "East Asia")
    ("NAM" "North America")
    ("SAM" "South America")
    ("SEA" "South-East Asia")
    ("WAS" "West Asia")
    ("CAM" "Central America")
    ("CAS" "Central Asia")
    ("MED" "Mediterranean")
    ("MNA" "Middle East and North Africa")
  }

  # --- Use KG to get GCM (GlobalClimateModel) & RCM (RegionalClimateModel) ---

  # GCM: only if we actually have a non-empty gcmCode
  # GCM: any subclass of ClimateModel whose label matches (loosely) gcmCode
  OPTIONAL {
    FILTER(STRLEN(?gcmCode) > 0)

    ?gcmRes rdf:type ?gcmType ;
            rdfs:label ?gcmLabel .
    # allow GlobalClimateModel or any other subclass of ClimateModel
    ?gcmType rdfs:subClassOf* ccso:ClimateModel .

    OPTIONAL {
      ?gcmRes ccso:isMaintainedBy ?gcmInst .
      OPTIONAL { ?gcmInst rdfs:label ?gcmInstLabel . }
    }

    # be tolerant to prefixes / small differences:
    FILTER(
      CONTAINS(LCASE(STR(?gcmLabel)), LCASE(?gcmCode)) ||
      CONTAINS(LCASE(?gcmCode), LCASE(STR(?gcmLabel)))
    )
  }

  # RCM
  OPTIONAL {
    ?rcmRes rdf:type ?rcmType ;
            rdfs:label ?rcmLabel .
    ?rcmType rdfs:subClassOf* ccso:ClimateModel .

    OPTIONAL {
      ?rcmRes ccso:isMaintainedBy ?rcmInst .
      OPTIONAL { ?rcmInst rdfs:label ?rcmInstLabel . }
    }

    FILTER(LCASE(STR(?rcmLabel)) = LCASE(?rcmCode))
  }

  # GCM sentence (only if we have some GCM info)
  BIND(
    IF(
      (BOUND(?gcmLabel) && STRLEN(STR(?gcmLabel)) > 0) ||
      STRLEN(?gcmCode) > 0,
      CONCAT(
        "The GCM used is ",
        COALESCE(
          IF(BOUND(?gcmLabel) && STRLEN(STR(?gcmLabel)) > 0, STR(?gcmLabel), ""),
          IF(STRLEN(?gcmCode) > 0, STR(?gcmCode), ""),
          "unknown GCM"
        ),
        IF(BOUND(?gcmInstLabel),
           CONCAT(" (", STR(?gcmInstLabel), ")"),
           ""),
        ". "
      ),
      ""   # no GCM sentence at all
    )
    AS ?gcmSentence
  )

  # RCM sentence (only if we have some RCM info)
  BIND(
    IF(
      (BOUND(?rcmLabel) && STRLEN(STR(?rcmLabel)) > 0) ||
      STRLEN(?rcmCode) > 0,
      CONCAT(
        "The RCM used is ",
        COALESCE(
          IF(BOUND(?rcmLabel) && STRLEN(STR(?rcmLabel)) > 0, STR(?rcmLabel), ""),
          IF(STRLEN(?rcmCode) > 0, STR(?rcmCode), ""),
          "unknown RCM"
        ),
        IF(BOUND(?rcmInstLabel),
           CONCAT(" (", STR(?rcmInstLabel), ")"),
           ""),
        ". "
      ),
      ""   # no RCM sentence
    )
    AS ?rcmSentence
  )

  # Final comment 
  BIND(CONCAT(
    "RCM simulation from CORDEX, covering the ", ?domainCode, " domain",
    IF(BOUND(?domainName), CONCAT(" (", ?domainName, ")"), ""), ". ",
    "Resolution: ", ?deg, " degrees",
    IF(BOUND(?kmApprox) && STRLEN(?kmApprox) > 0,
       CONCAT(" or ", ?kmApprox, " km"),
       ""),
    ?regularNote, ". ",
    "Scenario: ",
       COALESCE(STR(?scenarioName), "unknown"),
    ". ",
    ?gcmSentence,
    ?rcmSentence,
    "Version number: ",
       IF(STRLEN(?ver) > 0, STR(?ver), "unknown"),
    ". ",
    "Ensemble member: ",
       IF(STRLEN(?rip) > 0, STR(?rip), "unknown"),
    "."
  ) AS ?comment)
}
