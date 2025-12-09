PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX top: <https://w3id.org/hacid/onto/top-level/> 
PREFIX dimension: <https://w3id.org/hacid/data/cs/dimensions/>
PREFIX time: <https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/>

INSERT {
    GRAPH ?simulationGraph {
        ?simulationOutput
            data:dependsOnVariable ?simulationTemporalGrid;
            data:isSpecializedAccordingTo ?simulationTemporalSpecialization.
        ?simulationTemporalGrid a data:DimensionalSpace;
            data:basedOnDimensionalSpace time:gregorian;
            data:hasExactBoundingRegion ?simulationTemporalRegion;
            data:hasDiscretization ?simulationQuantization.
        ?simulationTemporalSpecialization a data:VariableSpecialization;
            data:isSpecializationOn dimension:time;
            data:hasSelectedRegion ?simulationTemporalRegion.
        ?simulationTemporalRegion a data:TemporalRegion;
            rdfs:label ?simulationTemporalRegionLabel;
            rdfs:comment ?simulationTemporalRegionComment;
            data:hasStartDateTime ?simulationStartTime;
            data:hasEndDateTime ?simulationEndTime.
        ?simulationQuantization
#            a ?finestTemporalQuantizationType;
            a data:SimpleRegularBinning;
            data:hasResolutionValue ?minResolution.
#           data:hasPeriodValue ?minGridPeriod.
    }
}
WHERE {
    {
        SELECT
            ?simulationGraph ?simulationOutput
            (MIN(?startTime) AS ?simulationStartTime)
            (MAX(?endTime)AS ?simulationEndTime) 
#            (MAX(?quantizationTypeId) AS ?mostFineGrainedQuantizationTypeId)
            (MIN(?resolution) AS ?minResolution)
#            (MIN(?gridPeriod) AS ?minGridPeriod)
        WHERE {
	        ?simulation rdf:type/rdfs:subClassOf ccso:Simulation.
            GRAPH ?simulationGraph {
                ?simulation data:hasOutput ?simulationOutput
            }
            ?simulationOutput top:hasComponent+/data:dependsOnVariable ?temporalDS.
            ?temporalDS
                data:basedOnDimensionalSpace+ dimension:time;
                data:hasExactBoundingRegion [
                    data:hasStartDateTime ?startTime;
                    data:hasEndDateTime ?endTime
                ];
                data:hasDiscretization ?quantization.
            ?quantization a ?quantizationType.
            OPTIONAL {?quantization data:hasResolutionValue ?resolution}.
#                OPTIONAL {?quantization data:hasPeriodValue ?gridPeriod}.
            VALUES (?quantizationType ?quantizationTypeId) {
                (data:SimpleRegularBinning 'regular')
                (data:SinglePeriodicBinning 'periodic')
                (data:RegularPeriodicBinning 'regular-periodic')
                (data:SingleBinBinning 'constant')
            }.
            FILTER NOT EXISTS {
                ?simulationOutput data:dependsOnVariable [
                    data:basedOnDimensionalSpace+ dimension:time;
                    data:hasExactBoundingRegion ?simulationTemporalRegion
                ]
            }
        }
        GROUP BY ?simulationGraph ?simulationOutput
    }
    BIND(CONCAT(STR(?simulationStartTime), " ", STR(?simulationEndTime)) AS ?simInterval)
    BIND("(.*) (.*)" AS ?re)
    BIND(
        IRI(REPLACE(?simInterval, ?re,
            "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/regions/$1-$2"
        )) AS ?simulationTemporalRegion
    ).
    BIND(
        STRLANG(REPLACE(?simInterval, ?re,
            "Time interval $1 - $2"
        ), "en") AS ?simulationTemporalRegionLabel
    ).
    BIND(
        STRLANG(REPLACE(?simInterval, ?re,
            "Time interval starting at date time $1 and ending at date time $2."
        ), "en") AS ?simulationTemporalRegionComment
    ).
    BIND(
        IRI(REPLACE(?simInterval, ?re,
            "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/regions/$1-$2/specialization"
        )) AS ?simulationTemporalSpecialization
    ).
    BIND(
        CONCAT(
#            ?mostFineGrainedQuantizationTypeId,
            'regular',
            COALESCE(CONCAT ('/', STR(?minResolution)), '')
#            COALESCE(CONCAT ('/', STR(?minGridPeriod)), '')
        ) AS ?gridTypeId
    ).
    BIND(
        IRI(
            CONCAT(
                REPLACE(
                    ?simInterval, ?re,
                    "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/regions/$1-$2/"
                ),
                ?gridTypeId
            )
        ) AS ?simulationTemporalGrid
    ).
    BIND(
        IRI(
            CONCAT(
                "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/quantizations/",
                ?gridTypeId
            )
        ) AS ?simulationQuantization
    ).
    # VALUES (?finestTemporalQuantizationType ?mostFineGrainedQuantizationTypeId) {
    #     (data:RollingRegularGrid 'rolling')
    #     (data:PeriodicRegularGrid 'periodic')
    #     (data:ConstantDimensionalSpace 'constant')
    # }.
}
