# Climate Science Workflow ontology
The Climate Science Workflow ontology module of the [HACID ontology network](https://github.com/hacid-project/knowledge-graph) represents concepts and relationships that describe the workflow of tasks that is executed when handling a climate information request from an organisation or person.

[![DOI](https://zenodo.org/badge/372536364.svg)](https://zenodo.org/)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC_BY_4.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

[comment]: < Ontology URI: [https://w3id.org/)> 

[comment]: < ![overview](diagrams/workflow.jpg)> 

## Relevant statistics

- Number of classes:  33
- Number of object properties: 22
- Number of datatype properties: 12
- Number of logical axioms: 73

## Competency questions addressed by this ontology module

| **ID**   | **Competency question**                                              |
| -------- | -------------------------------------------------------------------- |
| **CQ1**  | What are the tasks in a climate services workflow?                   |
| **CQ2**  | How do the tasks interconnect?                                       |
| **CQ3**  | Which roles are defined in a workflow?                               |
| **CQ4**  | Which agents are defined in a workflow?                              |
| **CQ5**  | Which actions are included in the workflow execution?                |
| **CQ6**  | Which tasks belong to a specific role?                               |
| **CQ7**  | Which are the parts of a task?                                       |
| **CQ6**  | Which tasks belong to a specific role?                               |
| **CQ7**  | Which are the parts of a task?                                       |
| **CQ8**  | Which actions execute a specific task?                               |
| **CQ9**  | Who/What is the agent that participates in a action?                 |

## Competency questions that will be addressed by this ontology module

| **ID**   | **Competency question**                                              |
| -------- | -------------------------------------------------------------------- |
| **CQ10** |                                                                      |
| **CQ11** |                                                                      |
| **CQ12** |                                                                      |


## Examples of SPARQL queries addressed by the module

- Which roles are defined in the workflow?

```
PREFIX csw: <http://example.org/csw#>.
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
PREFIX top: <http://example.org/top#>.

SELECT ?role
WHERE {
?workflow rdf:type csw:Workflow,
          top:definesRole ?role. }

```

- Which workflow executions require external expertise?
```
PREFIX csw: <http://example.org/csw#>.
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
PREFIX top: <http://example.org/top#>.

SELECT ?workflowExecution
WHERE {
?workflow rdf:type csw:Workflow,
          top:definesTask ?task,
          top:satisfies ?workflowExecution.
?workflowExecution rdf:type csw:Workflow.
?task rdf:type top:Task.

FILTER(str(?task)='ExternalExpertiseRequest') }

```

## Imported ontologies

### Imported from the HACID Ontology Network

- [Top Module](https://github.com/polifonia-project/core-ontology/)

## Licence
CC BY
