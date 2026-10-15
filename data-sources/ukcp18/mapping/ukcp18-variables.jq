# Variables of the UKCP18 datasets: the MIP variables resolved through
# data-sources/cmor-tables/mapping/mip-mapping.json (the modules of
# data-sources/cmor-tables/mapping must be in the library path, -L), and the
# UKCP18 variables not defined in the CMOR tables or with units other than those
# of the MIP variable, and the return levels and probability representations
# of the probabilistic datasets (https://w3id.org/hacid/data/cs/variables/ukcp/...,
# see ukcp_variables).
#
# Needs data/mip-variable-units.json: the units of the variables of the KG, by IRI.

include "mip-variables";

import "./data/mip-variable-units" as $MIP_VARIABLE_UNITS;
import "./mapping/ukcp18-time" as UKCP18_TIME;

def _mip_variable_units: $MIP_VARIABLE_UNITS::MIP_VARIABLE_UNITS[0];

# Units of the UKCP18 datasets that are a linear transformation of units of the
# MIP variables (assuming the density of water for precipitation and snow)
def _linear_conversions:
    {
        "degC": ["K"],
        "hPa": ["Pa"],
        "mm/day": ["kg m-2 s-1"],
        "mm/hour": ["kg m-2 s-1"],
        "mm": ["kg m-2"]
    };

# Variables named in some UKCP18 datasets by their CF standard name (their ids
# use the CMIP name, as the other datasets of the same variable)
def _variable_renames:
    {
        "air_pressure_at_sea_level": "psl",
        "subsurface_runoff_flux": "mrrob"
    };

def _ukcp_variables_base: "https://w3id.org/hacid/data/cs/variables/ukcp/";

def _ukcp_variables_collection: "https://w3id.org/hacid/data/cs/variables/ukcp";

# UKCP18 variables not defined in the CMOR tables, with the MIP variables they
# are derived from (as variable names in the CMIP5 era)
def _ukcp_variables:
    {
        # soil moisture stress factor
        "beta": {},
        # 1-day and 5-day total precipitation
        "pr1day": {derived_from: ["pr"]},
        "pr5day": {derived_from: ["pr"]},
        # latitude and strength of the eddy-driven jet (from the zonal wind)
        "jetlat": {derived_from: ["ua"]},
        "jetstr": {derived_from: ["ua"]},
        # winter Atlantic pressure gradient (NAO)
        "naodjf": {derived_from: ["psl"]},
        # Met Office weather types (from the mean sea level pressure)
        "wtype8": {derived_from: ["psl"]},
        "wtype30": {derived_from: ["psl"]}
    };

def _mip_variable_iri_of($name): {out_name: $name, era: "cmip5"} | mip_variable_iri;

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

def _lcfirst: (.[0:1] | ascii_downcase) + .[1:];

# Anomaly classes by anomaly_type
def _anomaly_types:
    {
        "absolute_change": "data:AbsoluteAnomaly",
        "percentage_change": "data:RelativeAnomaly"
    };

# Years of a baseline period (input: baseline_period, e.g. "b8100" or
# "1981-2000") as "<start year>-<end year>", or null if unknown. In the
# b<start><end> form the years are the last two digits, from 1900 (the end
# year in the following century if before the start one)
def _baseline_years:
    if type != "string" then
        null
    elif test("^b[0-9]{4}$") then
        (1900 + (.[1:3] | tonumber)) as $start |
        (1900 + (.[3:5] | tonumber)) as $end |
        "\($start)-\(if $end < $start then $end + 100 else $end end)"
    elif test("^[0-9]{4}-[0-9]{4}$") then
        .
    else
        null
    end;

# Distribution representations (data ontology) of the probabilistic (land-prob)
# datasets, by their prob_data_type. The "cdf" datasets give the values of the
# variable at percentiles (in the units of the variable), i.e. its quantile
# function (data:QuantileFunction), not its cumulative distribution function
# (whose values are probabilities)
def _probability_representations:
    {
        pdf: {type: "data:ProbabilityDensityFunction", text: "Probability density of"},
        cdf: {type: "data:QuantileFunction", text: "Quantile function of"},
        sample: {type: "data:Sample", text: "Sample of"}
    };

# Type of distribution representation of a dataset (input: its metadata), if
# probabilistic (land-prob), otherwise null
def distribution_representation_type:
    if .collection == "land-prob" then _probability_representations[.prob_data_type // ""].type else null end;

# The UKCP18 variables of a dataset (input: its metadata), from the base
# variable to the variable of the dataset (the last one), as descriptors
# {iri, types, text, tag, units} with the links of the variable (IRIs):
# anomaly_of (with baseline, the temporal region of the baseline period),
# derived_from, linear_transformation_of, probabilistic_representation_of; and
# local_of (for the analysis), the MIP variable of a local version. Empty for a
# dataset of a MIP variable. The variables are:
# - the base variable:
#   - the variables above, derived from MIP variables;
#   - each <variable>Anom, the anomaly of the MIP variable <variable> with
#     respect to a baseline period, <variable>Anom/<start year>-<end year>
#     (<variable>Anom if the baseline period is unknown), a data:AbsoluteAnomaly
#     for an absolute_change (anomaly_type), a data:RelativeAnomaly for a
#     percentage_change, otherwise a data:Anomaly. The baseline period is
#     linked with the shortcut data:hasBaselineRegion (the baseline variable,
#     the climatology over the period, is not represented). It is the
#     interval of calendar years (UKCP18 climatologies may use years from
#     December to November);
#   - a local version of a MIP variable, if the units of the dataset are not
#     those of the MIP variable, which is a linear transformation of it if the
#     units are (see _linear_conversions) (not for the probabilistic datasets,
#     whose variables below are of the MIP variable);
# - for the return levels (land-prob datasets with a return_period), the return
#   level of the base variable for the return period, <base>/<return period>,
#   derived from the base variable (data:derivedFromVariable). A return level
#   is a form of aggregation (a quantile of the distribution of the annual
#   maxima) and, as the other
#   forms of aggregation (min, max, mean, ...) are not represented in detail,
#   neither is it (no specific class, nor properties for the return period).
#   A more detailed representation of the aggregations could cover it in the
#   future;
# - for the probabilistic datasets (land-prob), the probability representation
#   (pdf, cdf, sample) of the previous variable, <previous>/<pdf|cdf|sample>, a
#   data:DistributionRepresentation linked to it with the shortcut
#   data:isProbabilisticRepresentationOf (without modelling its random version).
def ukcp_variables:
    (_variable_renames[.variable] // .variable) as $name |
    ((.variable_long_name // null) | if . then sub(" probability density$"; "") else null end) as $long_name |
    (.collection == "land-prob") as $probabilistic |
    (if $probabilistic then _probability_representations[.prob_data_type // ""] else null end) as $representation |
    .units as $units |
    (
        if _ukcp_variables[$name] != null then
            {
                iri: (_ukcp_variables_base + ($name | @uri)),
                text: ($long_name // $name),
                derived_from: [_ukcp_variables[$name].derived_from[]? | _mip_variable_iri_of(.)]
            }
        elif $name | test(".Anom$") then
            (.anomaly_type == "percentage_change") as $relative |
            (.baseline_period | _baseline_years) as $baseline_years |
            {
                iri: (
                    _ukcp_variables_base + ($name | @uri) +
                    if $baseline_years then "/" + $baseline_years else "" end
                ),
                types: [_anomaly_types[.anomaly_type // ""] // "data:Anomaly"],
                # (some long names already end with "anomaly")
                text: (
                    ($long_name // ($name | rtrimstr("Anom")) | sub(" anomaly$"; "")) +
                    (if $relative then " relative anomaly" else " anomaly" end) +
                    if $baseline_years then " with respect to \($baseline_years)" else "" end
                ),
                tag: ([$name, $baseline_years | values] | join(", ")),
                anomaly_of: _mip_variable_iri_of($name | rtrimstr("Anom")),
                baseline: (if $baseline_years then $baseline_years | UKCP18_TIME::str_to_interval else null end)
            }
        elif $probabilistic then
            # MIP variable, as base of the variables of the probabilistic datasets
            {iri: _mip_variable_iri, mip: true, text: ($long_name // $name)}
        else
            _mip_variable_iri as $mip_variable |
            _mip_variable_units[$mip_variable] as $mip_units |
            if $units != null and $mip_units != null and $units != $mip_units then
                {
                    iri: (_ukcp_variables_base + ($name | @uri) + "/" + ($units | @uri)),
                    text: ($long_name // $name),
                    tag: "\($name), \($units)",
                    units: $units,
                    local_of: $mip_variable,
                    linear_transformation_of: (
                        if (_linear_conversions[$units] // []) | index($mip_units) then $mip_variable else null end
                    )
                }
            else
                {iri: $mip_variable, mip: true}
            end
        end |
        .tag //= $name |
        .path = (if .mip then _ukcp_variables_base + ($name | @uri) else .iri end) |
        # units of the values of the dataset, unless they are probability densities
        if (.mip | not) and .units == null and ($representation.type // "") != "data:ProbabilityDensityFunction" then
            .units = $units
        end
    ) as $base |
    (
        if $probabilistic and .return_period then
            (.return_period | ltrimstr("rp")) as $years |
            {
                iri: ($base.path + "/" + (.return_period | @uri)),
                path: ($base.path + "/" + (.return_period | @uri)),
                text: "\($base.text) \($years)-year return level",
                tag: "\($base.tag), \(.return_period)",
                units: (if $representation.type != "data:ProbabilityDensityFunction" then $units else null end),
                derived_from: [$base.iri]
            }
        else
            null
        end
    ) as $return_level |
    (($return_level // $base)) as $represented |
    (
        if $representation then
            {
                iri: ($represented.path + "/" + .prob_data_type),
                types: [$representation.type],
                text: "\($representation.text) \($represented.text | _lcfirst)",
                tag: "\($represented.tag), \(.prob_data_type)",
                units: $units,
                probabilistic_representation_of: $represented.iri
            }
        else
            null
        end
    ) as $representation_variable |
    [($base | select(.mip | not)), $return_level, $representation_variable | values];

# IRI of the variable of a dataset (input: its metadata): the last UKCP18
# variable, if any, otherwise the MIP variable (or the IRI already resolved in
# the variable_iri field, see with_variable_iris)
def variable_iri:
    .variable_iri // (ukcp_variables | last | .iri) // _mip_variable_iri;

# Key of the metadata of a dataset determining its variables
def variable_key: [.variable, .units, .cmip5_table_id, .collection, .return_period, .prob_data_type, .anomaly_type, .baseline_period] | tojson;

# The datasets (input: array of metadata) with the IRIs of their variables in
# the variable_iri field, resolved once for each key (variable_key)
def with_variable_iris:
    (unique_by(variable_key) | map({key: variable_key, value: variable_iri}) | from_entries) as $variable_iris |
    map(.variable_iri = $variable_iris[variable_key]);

# Nodes of the UKCP18 variables of the datasets (input: array of metadata),
# with the terms of the context of datasets.jq: label (the most common among
# the datasets, preferring those with a long name), units (the most common),
# links; and the nodes of their units and baseline periods
def ukcp_variable_nodes:
    def most_common: group_by(.) | max_by(length) | .[0];
    [
        group_by(variable_key)[] |
        length as $count |
        (.[0].variable_long_name != null) as $named |
        .[0] | ukcp_variables[] | . + {count: $count, named: $named}
    ] |
    group_by(.iri) |
    map(
        . as $descriptors |
        .[0] + {
            label: (
                # preferring the long names in plain words (e.g. not soil_moisture_stress_factor)
                (map(select(.named and (.text | test("_") | not))) | if length > 0 then . else $descriptors end) |
                [.[] | "\(.text) (\(.tag))" as $label | range(0; .count) | $label] | most_common
            ),
            units: ([.[] | .units as $units | select($units != null) | range(0; .count) | $units] | if length > 0 then most_common else null end)
        } |
        {
            "@id": .iri,
            "@type": (["data:Variable"] + (.types // [])),
            is_member_of: _ukcp_variables_collection,
            label,
            acronym: (.tag | split(", ") | .[0]),
            is_anomaly_of: .anomaly_of,
            has_baseline_region: .baseline."@id",
            baseline: .baseline,
            derived_from_variable: .derived_from,
            is_linear_transformation_of: .linear_transformation_of,
            is_probabilistic_representation_of: .probabilistic_representation_of,
            has_unit_of_measure: (.units | if . then "https://w3id.org/hacid/data/cs/unitsofmeasure/\(@uri)" else null end),
            has_values_on: (.units | if . then "https://w3id.org/hacid/data/cs/unitsofmeasure/\(@uri)" else null end)
        }
    ) |
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
