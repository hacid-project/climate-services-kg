PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/>
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX mips: <https://w3id.org/hacid/data/cs/mips/>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX dimension: <https://w3id.org/hacid/data/cs/dimensions/>
PREFIX georeference: <https://w3id.org/hacid/data/cs/dimensions/geodetic/reference-frames/>

INSERT  { ?rcm_simulation rdfs:comment ?rcm_simulation_descr }
WHERE {
    SELECT
        ?rcm_simulation
        (
            CONCAT(
                "RCM simulation from CORDEX, ",
                "covering the ", ?cordex_domain_descr,
                IF(BOUND(?geodetic_resolution),
                    CONCAT(
                        " Resolution: ", STR(?geodetic_resolution), " degrees",
                        " or ~", STR(?geodetic_resolution_km), " km",
                        IF(?geodetic_reference_frame = georeference:WGS84, " (regular grid)", ""),
                    "."
                    ),
                    ""
                ),
                " Experiment: ", ?experiment_label, ". ",
                ?gcm_descr,
                ?rcm_descr,
                "Ensemble member: ", ?gcm_simulation_member_id, "."
            ) AS ?rcm_simulation_descr
        )
    WHERE {
        {
            SELECT
                ?rcm_simulation ?rcm_descr
                ?gcm_simulation
                (
                    CONCAT(
                        "The GCM used is ", ?gcm_label,
                        " (",
                        GROUP_CONCAT(COALESCE(?gcm_inst_label, ?gcm_inst_code); SEPARATOR="; ") ,
                        "). "
                    ) AS ?gcm_descr
                )
            WHERE {
                {
                    SELECT
                        ?rcm_simulation
                        (
                            CONCAT(
                                "The RCM used is ", ?rcm_label,
                                " (",
                                GROUP_CONCAT(COALESCE(?rcm_inst_label, ?rcm_inst_code); SEPARATOR="; ") ,
                                "). "
                            ) AS ?rcm_descr
                        )
                    WHERE {
                        ?rcm_simulation a ccso:DynamicalDownscaling, ccso:SingleSimulation ;
                            ^ccso:hasMemberSimulation/^top:hasComponent/top:isComponentOf mips:cordex-cmip5;
                            ccso:usesModel ?rcm.
                    
                        ?rcm rdfs:label ?rcm_label;
                            ccso:isMaintainedBy ?rcm_inst .
                        ?rcm_inst top:acronym ?rcm_inst_code .
                        OPTIONAL {
                        ?rcm_inst rdfs:label ?rcm_inst_label .
                        }
                    
                        FILTER NOT EXISTS { ?rcm_simulation rdfs:comment ?_already }

                    }
                    GROUP BY ?rcm_simulation ?rcm_label
                }

                ?rcm_simulation ccso:isDownscalingOf ?gcm_simulation.
            
                ?gcm_simulation a ccso:GlobalClimateSimulation, ccso:SingleSimulation ;
                    ccso:usesModel ?gcm.
                ?gcm rdfs:label ?gcm_label;
                    ccso:isMaintainedBy ?gcm_inst .
                ?gcm_inst top:acronym ?gcm_inst_code .
                OPTIONAL {
                    ?gcm_inst rdfs:label ?gcm_inst_label .
                }

            }
            GROUP BY ?rcm_simulation ?rcm_descr ?gcm_simulation ?gcm_label
        }

        ?experiment top:isComponentOf mips:cmip5;
            rdfs:label ?experiment_label;
            ccso:hasMemberSimulation ?gcm_simulation.

        ?gcm_simulation ccso:simulationConfigurationId ?gcm_simulation_member_id.

        ?rcm_simulation data:hasOutput/data:dependsOnVariable ?geodetic_variable.

        ?geodetic_variable
            data:basedOnDimensionalSpace ?geodetic_reference_frame;
            top:isConstituentOf ?cordex_domain;
            data:hasDiscretization/data:hasResolutionValue ?geodetic_resolution.
    
        ?geodetic_reference_frame data:basedOnDimensionalSpace* dimension:geodetic.

        VALUES (?geodetic_resolution ?geodetic_resolution_km) {
            ("0.125"^^xsd:float 12.5)
            ("0.25"^^xsd:float 25.0)
            ("0.5"^^xsd:float 50.0)
            ("0.11"^^xsd:float 12.5)
            ("0.22"^^xsd:float 25.0)
            ("0.44"^^xsd:float 50.0)
        }

        ?cordex_domain rdfs:comment ?cordex_domain_descr.
    }
}