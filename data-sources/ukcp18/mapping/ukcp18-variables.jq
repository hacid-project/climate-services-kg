# Variables of the UKCP18 datasets: the local variables
# (https://w3id.org/hacid/data/cs/variables/ukcp/...), generated from their
# specification in mapping/ukcp-variables.json (see DECISIONS.md), and
# otherwise the MIP variables resolved through
# data-sources/cmor-tables/mapping/mip-mapping.json (the modules of
# data-sources/cmor-tables/mapping must be in the library path, -L).

include "mip-variables";

import "./mapping/ukcp-variables" as $UKCP_VARIABLES;
import "./mapping/ukcp18-time" as UKCP18_TIME;

def _spec: $UKCP_VARIABLES::UKCP_VARIABLES[0];

def _ukcp_variables_base: "https://w3id.org/hacid/data/cs/variables/ukcp/";

# IRI of a local variable (input: its path, e.g. ["tasAnom", "1981-2000"])
def _local_iri: _ukcp_variables_base + (map(@uri) | join("/"));

def _mip_variable_iri_of($name): {out_name: $name, era: "cmip5"} | mip_variable_iri;

def _lcfirst: (.[0:1] | ascii_downcase) + .[1:];

# Inverse of units (input: units, e.g. "W m-2" -> "W-1 m2"), for the
# probability densities
def _inverse_units:
    split(" ") |
    map(
        capture("^(?<base>.*?)(?<exponent>-?[0-9]+)?$") |
        (-(.exponent // "1" | tonumber)) as $exponent |
        .base + (if $exponent == 1 then "" else ($exponent | tostring) end)
    ) |
    join(" ");

# The local variables, generated from the specification: [{path, iri, types,
# text, tags, units, anomaly_of, baseline, derived_from,
# linear_transformation_of, local_version_of,
# probabilistic_representation_of}] (relationships as IRIs, label as
# "<text> (<tags>)"):
# - variables: the UKCP18 variables not in the CMOR tables, derived from MIP
#   variables, <id>;
# - other_units: the versions of MIP variables in other units, <variable>/<units>,
#   linear transformations of the MIP variable if linear;
# - anomalies: the anomalies of MIP variables for each baseline period,
#   <id>/<baseline>, absolute or relative;
# - return_levels: the return levels of a local or MIP variable for each
#   return period, <variable>/<period>, derived from it;
# - the distribution representations (distributions) of the anomalies and of
#   the return levels, <base>/<distribution>, in the units of the base (their
#   inverse for densities).
def _generated_variables:
    _spec as $spec |
    def distributions($names):
        . as $base |
        $names[] as $name |
        $spec.distributions[$name] as $d |
        {
            path: ($base.path + [$name]),
            types: [$d.type],
            text: "\($d.label) of \($base.text | _lcfirst)",
            tags: ($base.tags + [$name]),
            units: ($base.units | if . and $d.inverse_units then _inverse_units else . end),
            probabilistic_representation_of: ($base.path | _local_iri)
        };
    [
        (
            $spec.variables | to_entries[] |
            {
                path: [.key],
                text: .value.label,
                tags: [.key],
                units: .value.units,
                derived_from: [.value.derived_from[]? | _mip_variable_iri_of(.)]
            }
        ),
        (
            $spec.other_units | to_entries[] |
            .key as $variable | .value.label as $label |
            _mip_variable_iri_of($variable) as $mip |
            .value.units | to_entries[] |
            {
                path: [$variable, .key],
                text: $label,
                tags: [$variable, .key],
                units: .key,
                local_version_of: $mip,
                linear_transformation_of: (if .value.linear then $mip else null end)
            }
        ),
        (
            $spec.anomalies as $anomalies |
            $anomalies.variables | to_entries[] |
            .key as $id | .value as $anomaly |
            $anomalies.baselines | to_entries[] |
            {
                path: [$id, .key],
                types: [{absolute: "data:AbsoluteAnomaly", relative: "data:RelativeAnomaly"}[$anomaly.type] // "data:Anomaly"],
                text: "\($anomaly.label) \(if $anomaly.type == "relative" then "relative anomaly" else "anomaly" end) with respect to \(.value.label)",
                tags: [$id, .key],
                units: $anomaly.units,
                anomaly_of: _mip_variable_iri_of($anomaly.anomaly_of),
                baseline: "\(.value.start)-\(.value.end)"
            } |
            ., distributions($anomalies.distributions)
        ),
        (
            $spec.return_levels as $levels |
            $levels.variables | to_entries[] |
            .key as $variable |
            ($spec.variables[$variable] // {}) as $local |
            {
                path: [$variable],
                text: (.value.label // $local.label),
                tags: [$variable],
                units: (.value.units // $local.units),
                iri: (if $spec.variables[$variable] then [$variable] | _local_iri else _mip_variable_iri_of($variable) end)
            } as $base |
            $levels.periods | to_entries[] |
            {
                path: [$variable, .key],
                text: "\($base.text) \(.value.years)-year return level",
                tags: [$variable, .key],
                units: $base.units,
                derived_from: [$base.iri]
            } |
            ., distributions($levels.distributions)
        )
    ] |
    map(.iri = (.path | _local_iri));

def _local_variables: _generated_variables;

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
def _mip_variable_iri($mip_index):
    {
        out_name: (_variable_renames[.variable] // .variable),
        era: "cmip5",
        table: ((.cmip5_table_id // "" | capture("^Table (?<table>\\S+)").table) // null),
        units
    } |
    mip_variable_iri_indexed($mip_index);

# Index of data-sources/cmor-tables/mapping/mip-mapping.json, to resolve the
# MIP variables of many datasets (built once, e.g. mip_index as $mip_index)
def mip_index: mip_mapping_index(mip_mapping);

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

# Path of the local variable of a dataset (input: its metadata), from the
# specification, or null:
# - probabilistic datasets (with a prob_data_type): the distribution of the
#   anomaly of the baseline period of the dataset (baseline_period, one of the
#   datasets ids of a baseline), or of the return level of the dataset
#   (return_period), if the distribution is one of those of the anomalies or
#   return levels;
# - other datasets: the UKCP18 variable, the anomaly of the baseline period,
#   or the version of the MIP variable in the units of the dataset.
def _local_path:
    _spec as $spec |
    (_variable_renames[.variable] // .variable) as $name |
    .baseline_period as $period |
    (
        first(
            $spec.anomalies.baselines | to_entries[] |
            select(.key == $period or (.value.datasets | index([$period]))) | .key
        ) // null
    ) as $baseline |
    if .prob_data_type then
        .prob_data_type as $distribution |
        if $spec.anomalies.variables[$name] and $baseline then
            [$name, $baseline] + ([$distribution] | select($spec.anomalies.distributions | index($distribution)))
        elif .return_period and $spec.return_levels.variables[$name] and $spec.return_levels.periods[.return_period] then
            [$name, .return_period] + ([$distribution] | select($spec.return_levels.distributions | index($distribution)))
        else
            null
        end
    elif $spec.variables[$name] then
        [$name]
    elif $spec.anomalies.variables[$name] and $baseline then
        [$name, $baseline]
    elif $spec.other_units[$name].units[.units // ""] then
        [$name, .units]
    else
        null
    end;


# The local variables of a dataset (input: its metadata): its local variable
# and those it is a representation of or derived from, recursively
def local_variables: local_variables(local_variables_by_iri);

# The local variables by IRI (generated from the specification: built once to
# find the local variables of many datasets, local_variables($by_iri))
def local_variables_by_iri: _local_variables_by_iri;

# The local variables of a dataset (input: its metadata), with the local
# variables by IRI (local_variables_by_iri)
def local_variables($by_iri):
    def chain:
        ., (
            [.probabilistic_representation_of, .derived_from[]?] | .[] | strings |
            $by_iri[.] | values | chain
        );
    [_local_path | values | _local_iri | $by_iri[.] | values | chain] | unique_by(.iri)[];

# IRI of the variable of a dataset (input: its metadata): its local variable
# (from its path), if any, otherwise the MIP variable resolved with $mip_index
# (mip_index) (or the IRI already resolved in the variable_iri field)
def variable_iri($mip_index):
    .variable_iri // (_local_path | values | _local_iri) // _mip_variable_iri($mip_index);

# (building the index, unless the IRI is already resolved: for a few datasets)
def variable_iri: .variable_iri // variable_iri(mip_index);

# Key of the metadata of a dataset determining its variables
def variable_key: [.variable, .units, .cmip5_table_id, .collection, .return_period, .prob_data_type, .anomaly_type, .baseline_period] | tojson;

# Nodes of the local variables (generated from mapping/ukcp-variables.json), with the terms of
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
            label: "\(.text) (\(.tags | join(", ")))",
            acronym: .tags[0],
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
