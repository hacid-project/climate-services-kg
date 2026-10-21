# JSON-LD context of the UKCP18 datasets (datasets.jq) and of their local
# variables (variables.jq)

import "./mapping/jsonld" as JSONLD;

def context:
(
    {
        rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        data: "https://w3id.org/hacid/onto/data/",
        index: "https://w3id.org/hacid/data/cs/climdex/indices/",
        sector: "https://w3id.org/hacid/data/cs/climdex/sectors/",
        parameter: "https://w3id.org/hacid/data/cs/climdex/parameters/",
        variable: "https://w3id.org/hacid/data/cs/variables/mip/",
        unit: "https://w3id.org/hacid/data/cs/unitsofmeasure/",
        dimension: "https://w3id.org/hacid/data/cs/dimensions/",
        aggregation: "https://w3id.org/hacid/data/cs/climdex/index-time-aggregations/",
        temporalgrid: "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/quantizations/",
        time: "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/",
        geodetic: "https://w3id.org/hacid/data/cs/dimensions/geodetic/reference-frames/",
        ensemble: {
            "@reverse": "top:hasComponent"
        }
    } +
    (
        {
            "@type": {
                "@id": {
                    has_output: "data:hasOutput",
                    sub_dataset: "top:hasComponent",
                    dependent_variable: "data:holdsSpecializationOfVariable",
                    single_dependent_variable: "data:isSpecializationOfVariable",
                    independent_variable: "data:dependsOnVariable",
                    downscaling_of: "ccso:isDownscalingOf", 
                    model: "ccso:usesModel", 
                    scenario: "ccso:refersToScenario", 
                    gwl: "ccso:refersToGlobalWarmingLevel", 
                    maintained_by: "ccso:isMaintainedBy",
                    specialization_criterion: "data:isSpecializedAccordingTo",
                    specialization_on: "data:isSpecializationOn",
                    selected_region: "data:hasSelectedRegion",
                    based_on_ds: "data:basedOnDimensionalSpace",
                    discretization: "data:adoptsQuantization",
                    exact_bounding_region: "data:hasExactBoundingRegion",
                    is_member_of: "top:isMemberOf",
                    is_anomaly_of: "data:isAnomalyOf",
                    has_baseline_region: "data:hasBaselineRegion",
                    is_probabilistic_representation_of: "data:isProbabilisticRepresentationOf",
                    derived_from_variable: "data:derivedFromVariable",
                    is_linear_transformation_of: "data:isLinearTransformationOf",
                    has_unit_of_measure: "top:hasUnitOfMeasure",
                    has_values_on: "data:hasValuesOn",
                },
                "http://www.w3.org/2001/XMLSchema#dateTime": {
                    start_datetime: "data:hasStartDateTime",
                    end_datetime: "data:hasEndDateTime"
                },
                "http://www.w3.org/2001/XMLSchema#duration": {
                    resolution_value: "data:hasResolutionValue",
                    period_value: "data:hasPeriodValue",
                    in_period_resolution_value: "data:hasInPeriodResolutionValue"
                }
            },
            "@language": {
                en: {
                    label: "rdfs:label",
                    comment: "rdfs:comment",
                    acronym: "top:acronym"
                }
            }

        } | JSONLD::unpack
    )
);
