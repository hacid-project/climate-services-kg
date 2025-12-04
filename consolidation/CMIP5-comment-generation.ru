PREFIX to: <http://purl.obolibrary.org/obo/TO_>
PREFIX top: <https://w3id.org/hacid/onto/top-level/>
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX mips: <https://w3id.org/hacid/data/cs/mips/>

INSERT  { ?gcm_simulation rdfs:comment ?gcm_simulation_descr }
WHERE {
    SELECT
        ?gcm_simulation
        (
            CONCAT(
                "GCM simulation from CMIP5. ",
                "Experiment: ", ?experiment_label, ". ",
                ?gcm_descr,
                "Ensemble member: ",
                ?gcm_simulation_member_id,
                "."
            ) AS ?gcm_simulation_descr
        )
    WHERE {
        {
            SELECT
                ?experiment
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
                ?experiment top:isComponentOf mips:cmip5;
                    ccso:hasMemberSimulation ?gcm_simulation.
                ?gcm_simulation a ccso:GlobalClimateSimulation, ccso:SingleSimulation ;
                    ccso:usesModel ?gcm.
                ?gcm rdfs:label ?gcm_label;
                    ccso:isMaintainedBy ?gcm_inst .
                ?gcm_inst top:acronym ?gcm_inst_code .
                OPTIONAL {
                    ?gcm_inst rdfs:label ?gcm_inst_label .
                }

                FILTER NOT EXISTS { ?gcm_simulation rdfs:comment ?_already }
            }
            GROUP BY ?experiment ?gcm_simulation ?gcm_label
        }

        ?experiment rdfs:label ?experiment_label.

        ?gcm_simulation ccso:simulationConfigurationId ?gcm_simulation_member_id.
    }
}
