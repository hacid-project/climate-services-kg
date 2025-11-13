# Living List of CQs and Queries

## Climate Models

### List climate models

List climate models with available projections, organised by institution and type.

```sparql
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>

SELECT 
	?org ?org_label ?org_descr
	?model_type
	?model ?model_label ?model_descr
	(COUNT(DISTINCT ?simulation) AS ?num_simulations)
WHERE {
    ?model a ccso:ClimateModel;
    	a ?model_type;
    	ccso:isMaintainedBy ?org.
    ?org rdfs:label ?org_label.
    OPTIONAL {
	    ?org rdfs:comment ?org_descr.
    }
    ?model_type rdfs:subClassOf ccso:ClimateModel.
    ?model rdfs:label ?model_label.
    OPTIONAL {
	    ?model rdfs:comment ?model_descr.
    }
    ?simulation ccso:usesModel ?model
}
GROUP BY 
	?org ?org_label ?org_descr
	?model_type
	?model ?model_label ?model_descr
ORDER BY ?org ?model_type ?model
```

## Climate Variables and Metrics

### List CF variables

List climate variables defined in [CF Metadata Conventions](https://cfconventions.org/) and their usage in available projections.

```sparql
PREFIX top: <https://w3id.org/hacid/onto/top-level/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX data: <https://w3id.org/hacid/onto/data/>

SELECT 
	?var ?var_label ?var_descr
	(COUNT(DISTINCT ?dataset) AS ?num_datasets_using_it)
WHERE {
  	?var a data:Variable;
  	    top:isMemberOf <https://w3id.org/hacid/data/cs/variables/cf>;
  	    rdfs:label ?var_label.
  	OPTIONAL {
    	?var rdfs:comment ?var_descr.
  	}
    OPTIONAL {
	    ?dataset data:holdsSpecializationOfVariable* ?var
    }
}
GROUP BY
	?var ?var_label ?var_descr
ORDER BY DESC(?num_datasets_using_it) ?var
```

### List set of MIP variables

List MIP climate variables that specialize a specific CF variable (in this example air-temperature) and their usage.

```sparql
PREFIX top: <https://w3id.org/hacid/onto/top-level/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX cf: <https://w3id.org/hacid/data/cs/variables/cf/>

SELECT 
	?var ?var_label ?var_descr
	(COUNT(DISTINCT ?dataset) AS ?num_datasets_using_it)
WHERE {
    ?var a data:Variable;
  		top:isMemberOf <https://w3id.org/hacid/data/cs/variables/mip>;
        data:holdsSpecializationOfVariable* cf:air_temperature;
        rdfs:label ?var_label.
    OPTIONAL {
        ?var rdfs:comment ?var_descr.
    }
    OPTIONAL {
	    ?dataset data:holdsSpecializationOfVariable* ?var
    }
}
GROUP BY
	?var ?var_label ?var_descr
ORDER BY DESC(?num_datasets_using_it) ?var
```

### List set of climdex indices

List climate change indices that are associated to a specific sector according climdex.org classification (in this case "Water resources and food security"), each one alongside the (MIP) variable from which it is computed.

```sparql
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX sector: <https://w3id.org/hacid/data/cs/climdex/sectors/>

SELECT 
	?index ?index_label ?index_descr ?index_dim ?index_definition
WHERE {
    ?index a data:Variable;
        top:isMemberOf <https://w3id.org/hacid/data/cs/climdex/indices>;
        top:isClassifiedBy sector:Water%20resources%20and%20food%20security;
        rdfs:label ?index_label;
        data:derivedFromVariable ?from_variable.
    OPTIONAL {
        ?index rdfs:comment ?index_descr.
    }
    OPTIONAL {
        ?index data:hasValuesOn ?index_dim.
    }
    OPTIONAL {
        ?index top:definition ?index_definition.
    }
}
ORDER BY ?index
```

## Climate Projections

### Filter simulations

Filter available simulations by chosen emission scenario (in this case RCP4.5), available variables (in this case tas), and required spatial resolution (in this case less than 0.2 degrees).

```sparql
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/> 
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX rcp: <https://w3id.org/hacid/data/cs/scenarios/RCP/>
PREFIX mip: <https://w3id.org/hacid/data/cs/variables/mip/>
PREFIX dimension: <https://w3id.org/hacid/data/cs/dimensions/>

SELECT ?model ?simulation ?output ?geodeticResolution
WHERE {
    ?simulation a ccso:Simulation;
        ccso:refersToScenario rcp:RCP4.5;
        data:hasOutput ?output.
    ?output data:holdsSpecializationOfVariable* mip:tas;
    data:dependsOnVariable ?geodeticVariable.
    ?geodeticVariable
        data:holdsSpecializationOfVariable* dimension:geodetic;
        data:hasDiscretization/data:hasResolutionValue ?geodeticResolution.
	FILTER(?geodeticResolution < 0.2)
}
ORDER BY ?model ?simulation ?output
```

### Filter output datasets

Filter datasets from a simulation (in this case cmip5.HadCM3.rcp45.r10i1p1), based on available variables (in this case tas), and required exact temporal resolution (in this case one month).

```sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/> 
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX mip: <https://w3id.org/hacid/data/cs/variables/mip/>
PREFIX dimension: <https://w3id.org/hacid/data/cs/dimensions/>
PREFIX sim: <https://w3id.org/hacid/data/cs/simulations/>

SELECT ?dataset
WHERE {
    sim:cmip5.HadCM3.rcp45.r10i1p1 data:hasOutput/top:hasPart* ?dataset.
    ?dataset data:holdsSpecializationOfVariable* mip:tas;
    	data:dependsOnVariable ?temporalVariable.
	?temporalVariable
        data:holdsSpecializationOfVariable* dimension:time;
        data:hasDiscretization/data:hasResolutionValue "P1M"^^xsd:duration.
}
ORDER BY ?dataset
```

### List Dynamical Downscalings

List dynamical downscaling simulations based on a specific global simulation (in this case cmip5.HadCM3.rcp45.r10i1p1), organized by used regional models and showing the corresponding spatial coverage.

```sparql
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/> 
PREFIX ccso: <https://w3id.org/hacid/onto/ccso/>
PREFIX data: <https://w3id.org/hacid/onto/data/>
PREFIX mip: <https://w3id.org/hacid/data/cs/variables/mip/>
PREFIX dimension: <https://w3id.org/hacid/data/cs/dimensions/>
PREFIX sim: <https://w3id.org/hacid/data/cs/simulations/>
PREFIX geo: <http://www.opengis.net/ont/geosparql#>

SELECT ?organization ?regional_model ?downscaling ?geodetic_region
WHERE {
    ?downscaling ccso:isDownscalingOf sim:cmip5.HadGEM2-ES.rcp26.r1i1p1;
    	ccso:usesModel ?regional_model;
         data:hasOutput/data:isSpecializedAccordingTo [
            data:isSpecializationOn/data:holdsSpecializationOfVariable* dimension:geodetic;
            data:hasSelectedRegion/geo:asWKT ?geodetic_region
        ].
    ?regional_model ccso:isMaintainedBy ?organization.
}
ORDER BY ?organization ?regional_model ?downscaling
```

## Climate Service Workflow

List all the defined operations, the possible plans to execute them, and the number of tasks the plans are composed of.

```sparql
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/>

SELECT 
	?operation ?operation_label
	?plan ?plan_label
	(COUNT(?task) as ?num_tasks)
WHERE {
    ?operation a top:Operation;
    	rdfs:label ?operation_label;
    	top:isRealizedByPlan ?plan.
    ?plan rdfs:label ?plan_label;
    	top:definesTask ?task
}
GROUP BY
	?operation ?operation_label
	?plan ?plan_label
ORDER BY
	?operation ?plan
```

List tasks and subtasks of a specific plan (in this case a ClimateDataCollectionPlan), in order of precedence, alongside the optional output information role of each subtask.

```sparql
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX top: <https://w3id.org/hacid/onto/top-level/>
PREFIX plans: <https://w3id.org/hacid/data/cs/wf/plans/>

SELECT 
	?plan ?task ?task_label
	(COUNT(DISTINCT ?following_task) AS ?num_following_tasks)
WHERE {
    plans:ClimateDataCollectionPlan top:definesTask ?task.
    ?task rdfs:label ?task_label;
        top:directlyPrecedes* ?following_task.
}
GROUP BY ?plan ?task ?task_label
ORDER BY DESC(?num_following_tasks)
```

## Climate Service Case

### List all climate cases (executions of the climate process wf) in the KG

TODO

### Show outputs produced by actions in the execution of the workflow associated to a climate case

TODO

### Show simulations relevant to the case (specifically, conforming to the selected emission scenario and producing in the output the selected variable)

TODO
