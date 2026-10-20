# Variables of the UKCP18 datasets: the local variables
# (https://w3id.org/hacid/data/cs/variables/ukcp/...), specified with their
# relationships with the MIP variables and the conditions of their datasets in
# mapping/ukcp-variables.json (see its description in DECISIONS.md), and
# otherwise the MIP variables resolved through
# data-sources/cmor-tables/mapping/mip-mapping.json (the modules of
# data-sources/cmor-tables/mapping must be in the library path, -L).

include "mip-variables";

import "./mapping/ukcp-variables" as $UKCP_VARIABLES;
import "./mapping/ukcp18-time" as UKCP18_TIME;

def _local_variables: $UKCP_VARIABLES::UKCP_VARIABLES[0].variables;

def _local_variables_by_iri: _local_variables | map({key: .iri, value: .}) | from_entries;

# Variables named in some UKCP18 datasets by their CF standard name (their ids
# use the CMIP name, as the other datasets of the same variable)
def _variable_renames:
    {
        "air_pressure_at_sea_level": "psl",
        "subsurface_runoff_flux": "mrrob"
    };

def _ukcp_variables_collection: "https://w3id.org/hacid/data/cs/variables/ukcp";

# The MIP variable of a dataset (input: its metadata): the MIP variable of its
# name in the CMIP5 era (UKCP18 is based on CMIP5 models), with its units and,
# if known, the CMIP5 table of the source data (cmip5_table_id, e.g.
# "Table Amon (12 November 2010) 6e53...", for the land-gcm datasets)
def _mip_variable_iri:
    {
        out_name: (_variable_renames[.variable] // .variable),
        era: "cmip5",
        table: ((.cmip5_table_id // "" | capture("^Table (?<table>\\S+)").table) // null),
        units
    } |
    mip_variable_iri;

# Distribution representations (data ontology) of the probabilistic (land-prob)
# datasets, by their prob_data_type. The "cdf" datasets give the values of the
# variable at percentiles (in the units of the variable), i.e. its quantile
# function (data:QuantileFunction), not its cumulative distribution function
# (whose values are probabilities)
def _probability_representations:
    {
        pdf: "data:ProbabilityDensityFunction",
        cdf: "data:QuantileFunction",
        sample: "data:Sample"
    };

# Type of distribution representation of a dataset (input: its metadata), if
# probabilistic (land-prob), otherwise null
def distribution_representation_type:
    if .collection == "land-prob" then _probability_representations[.prob_data_type // ""] else null end;

# Whether a dataset (input: its metadata, with $name the name of its variable)
# matches a condition of a local variable ($condition, see
# ukcp-variables.json): each field of the condition is the value of the field
# in the metadata (null for a missing field), or a list of the possible values
def _matches($condition; $name):
    . as $metadata |
    all($condition | to_entries[];
        (if .key == "variable" then $name else $metadata[.key] end) as $value |
        if .value | type == "array" then .value | index([$value]) != null else .value == $value end
    );

# The local variable of a dataset (input: its metadata): the one of
# mapping/ukcp-variables.json with a condition matching the dataset (an error
# if more than one), or empty
def local_variable:
    (_variable_renames[.variable] // .variable) as $name |
    . as $metadata |
    [_local_variables[] | select(any(.datasets[]?; . as $c | $metadata | _matches($c; $name)))] |
    if length > 1 then error("More local variables for \($metadata | {variable, units, collection, return_period, prob_data_type, baseline_period}): \(map(.iri))") end |
    .[];

# The local variables of a dataset (input: its metadata): its local variable
# and those it is a representation of or derived from, recursively
def local_variables:
    def chain:
        ., (
            [.probabilistic_representation_of, .derived_from[]?] | .[] | strings |
            _local_variables_by_iri[.] | values | chain
        );
    [local_variable | chain] | unique_by(.iri)[];

# IRI of the variable of a dataset (input: its metadata): its local variable,
# if any, otherwise the MIP variable (or the IRI already resolved in the
# variable_iri field, see with_variable_iris)
def variable_iri:
    .variable_iri // (local_variable | .iri) // _mip_variable_iri;

# Key of the metadata of a dataset determining its variables
def variable_key: [.variable, .units, .cmip5_table_id, .collection, .return_period, .prob_data_type, .anomaly_type, .baseline_period] | tojson;

# The datasets (input: array of metadata) with the IRIs of their variables in
# the variable_iri field, resolved once for each key (variable_key)
def with_variable_iris:
    (unique_by(variable_key) | map({key: variable_key, value: variable_iri}) | from_entries) as $variable_iris |
    map(.variable_iri = $variable_iris[variable_key]);

# Nodes of the local variables (mapping/ukcp-variables.json), with the terms of
# the context of variables.jq; and the nodes of their units and baseline periods
def ukcp_variable_nodes:
    def unit: "https://w3id.org/hacid/data/cs/unitsofmeasure/\(@uri)";
    [
        _local_variables[] |
        (.baseline | if . then UKCP18_TIME::str_to_interval else null end) as $baseline |
        {
            "@id": .iri,
            "@type": (["data:DeterministicVariable"] + (.types // [])),
            is_member_of: _ukcp_variables_collection,
            label,
            acronym,
            is_anomaly_of: .anomaly_of,
            has_baseline_region: $baseline."@id",
            baseline: $baseline,
            derived_from_variable: .derived_from,
            is_linear_transformation_of: .linear_transformation_of,
            is_probabilistic_representation_of: .probabilistic_representation_of,
            has_unit_of_measure: (.units | if . then unit else null end),
            has_values_on: (.units | if . then unit else null end)
        }
    ] |
    ([.[].baseline | values] | unique_by(."@id")) as $baselines |
    map(del(.baseline)) +
    $baselines + (
        [.[].has_unit_of_measure | values] | unique |
        map({
            "@id": .,
            "@type": ["top:UnitOfMeasure", "data:DimensionalSpace"],
            "rdfs:label": (ltrimstr("https://w3id.org/hacid/data/cs/unitsofmeasure/") | @urid)
        })
    );
