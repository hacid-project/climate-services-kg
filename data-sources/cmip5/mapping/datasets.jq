# Mapping of the CMIP5 datasets (ESGF search results) to JSON-LD.
#
# Input: the response of an ESGF search of CMIP5 datasets (data/cmip5.json, see
# query.txt), {"response": {"docs": [...]}}.
#
# Port of the RML mapping rml/cmip5.ttl and of its functions in ws-data-rml.py.
# For each dataset (master_id cmip5.<product>.<institute>.<model>.<experiment>.
# <time_frequency>.<realm>.<cmor_table>.<ensemble>):
# - the dataset, its simulation output (all the datasets of the same model,
#   experiment, ensemble member and product), the outputs of the ensemble and of
#   the experiment, and the output of CMIP5;
# - the simulation, the ensemble, the experiment and the model, with its
#   institute;
# - the variables of the dataset, its spatial grid and its temporal grid (the
#   time interval of the dataset rounded to the time frequency).
#
# The IRIs of the variables are those of the MIP variables (see
# data-sources/cmor-tables/mapping/mip-mapping.md), resolved from the
# definitions of the variables in the CMIP5 CMOR tables (see _variable_specs).
#
# Arguments: --slurpfile cmor_tables <tables of the CMIP5 CMOR tables>
# (data-sources/cmor-tables/data/cmip5/5.0.json); the modules of
# data-sources/cmor-tables/mapping must be in the library path (-L).

include "variables-jsonld";
include "mip-variables";

# --- Time

def _is_leap_year: . % 4 == 0 and (. % 100 != 0 or . % 400 == 0);

def _days_in_month($year):
    if . == 2 and ($year | _is_leap_year) then 29
    else [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][. - 1]
    end;

# Dates as {y, m, d}
def _date_key: [.y, .m, .d];

def _add_day:
    if .d < (.y as $y | .m | _days_in_month($y)) then .d += 1
    elif .m < 12 then .m += 1 | .d = 1
    else .y += 1 | .m = 1 | .d = 1
    end;

def _add_months($n): (.y * 12 + .m - 1 + $n) as $months | .y = ($months / 12 | floor) | .m = $months % 12 + 1;

def _pad($digits): tostring | ("0" * ([$digits - length, 0] | max)) + .;

def _datetime_string: "\(.y | _pad(4))-\(.m | _pad(2))-\(.d | _pad(2))T00:00:00Z";

# ISO date time (as in the ESGF results, e.g. 1859-12-01T12:00:00Z) rounded down
# or up to the time frequency: the time frequencies shorter than a day are
# rounded to days, monClim to months
def _round_datetime($frequency; $up):
    (
        capture("^(?<y>[0-9]+)-(?<m>[0-9]+)-(?<d>[0-9]+)T(?<hh>[0-9]+):(?<mm>[0-9]+):(?<ss>[0-9.]+)")
        // error("unsupported date time: \(.)")
    ) |
    map_values(tonumber) |
    (.hh == 0 and .mm == 0 and .ss == 0) as $midnight |
    {y, m, d} as $date |
    ({"1hr": "day", "3hr": "day", "6hr": "day", "monClim": "mon"}[$frequency] // $frequency) as $granularity |
    if $granularity == "day" then
        $date | if $up and ($midnight | not) then _add_day end
    elif $granularity == "mon" then
        ($date | .d = 1) | if $up and _date_key < ($date | _date_key) then _add_months(1) end
    elif $granularity == "sem" then
        ($date | .m = ([.m, 6] | min) | .d = 1) | if $up and _date_key < ($date | _date_key) then _add_months(6) end
    elif $granularity == "yr" then
        ($date | .m = 1 | .d = 1) | if $up and _date_key < ($date | _date_key) then .y += 1 end
    else
        error("unknown granularity \($frequency)")
    end |
    _datetime_string;

# Temporal grids of the time frequencies: [description, grid type, step, period,
# step in period, offset]
def _time_frequencies:
    {
        "1hr": ["one hour", "regular", "PT1H", null, null, null],
        "3hr": ["three hours", "regular", "PT3H", null, null, null],
        "6hr": ["six hours", "regular", "PT6H", null, null, null],
        "day": ["day", "regular", "P1D", null, null, null],
        "mon": ["month", "regular", "P1M", null, null, null],
        "monClim": ["all time aggregated month of the year", "periodic", null, "P1M", "P1Y", null],
        "sem": ["season", "regular", "P3M", null, null, "P2M"],
        "yr": ["year", "regular", "P1Y", null, null, null],
        "fx": ["all time", null, null, null, null, null]
    };

# Temporal grid of a dataset (null if its time interval is not known)
def _temporal_grid:
    .time_frequency[0] as $frequency |
    if .datetime_start == null or .datetime_stop == null then null
    else
        ([.datetime_start, .datetime_stop] | min | _round_datetime($frequency; false)) as $start |
        ([.datetime_start, .datetime_stop] | max | _round_datetime($frequency; true)) as $end |
        (_time_frequencies[$frequency] // error("unknown time frequency \($frequency)")) as [$description, $type, $step, $period, $in_period_step, $offset] |
        {
            $start,
            $end,
            grid_type_id: (if $type != null then [$type, $step, $period, $in_period_step, $offset | values] | join("/") else null end),
            dimensional_space_type: {
                points: "IntervalSampling",
                regular: "SimpleRegularBinning",
                periodic: "SinglePeriodicBinning",
                constant: "SingleBinBinning"
            }[$type // ""],
            $step,
            $period,
            $in_period_step,
            $offset
        }
    end;

# --- IRIs

def _ns: "https://w3id.org/hacid/data/cs/";

# Percent-encoding as in Python's urllib.parse.quote (keeping "/")
def _quote: @uri | gsub("%2F"; "/");

def _id($iri): {"@id": $iri};

# Typed literal (null if the value is null)
def _typed($type): if . == null then null else {"@value": ., "@type": $type} end;

# English literal (null if the value is null)
def _en: if . == null then null else {"@value": ., "@language": "en"} end;

# --- Variables

# Definitions of a variable of a dataset in the CMIP5 CMOR tables, as the input
# of mip_variable_iri: the entries of the table of the dataset whose key or
# out_name is the variable (the ESGF results use either), or if there are none
# (e.g. a variable of the "day" table in "cfDay", or tables not in the CMOR
# tables, as "AmonExtras") the entries of any table. Among them, a climatology
# (time frequency monClim) is defined on time2, the other datasets not. Of the
# remaining entries, only the table, dimensions, standard name and units on
# which all agree are given.
def _variable_specs($entries_by_name):
    . as {$table, $variable, $frequency} |
    ($entries_by_name[$variable] // []) as $entries |
    (
        [$entries[] | select(.table == $table)] |
        if . == [] then $entries end |
        ([.[] | select((.dimensions | test("\\btime2\\b")) == ($frequency == "monClim"))] | if . == [] then null end) // .
    ) as $candidates |
    def agreed(f): [$candidates[] | f] | unique | if length == 1 then .[0] else null end;
    {
        out_name: (agreed(.out_name) // $variable),
        era: "cmip5",
        table: (if $candidates == [] then $table else agreed(.table) end),
        dimensions: agreed(.dimensions),
        quantity: agreed(.standard_name),
        units: agreed(.units)
    };

# --- Mapping

# Entries of the CMIP5 CMOR tables by key and out_name
(
    $cmor_tables[0] |
    [
        .[] | select(.variable_entry) |
        ((.Header.table_id // "") | sub("^Table "; "")) as $table |
        .variable_entry | to_entries[] |
        .value + {key, out_name: (.value.out_name // .key), $table}
    ] |
    [.[] | {name: .key, entry: .}, {name: .out_name, entry: .}] |
    group_by(.name) |
    map({key: .[0].name, value: (map(.entry) | unique)}) |
    from_entries
) as $entries_by_name |
# IRIs of the variables of the datasets, by table, variable and time frequency
(
    [
        .response.docs[] |
        {table: .cmor_table[0], variable: .variable[]?, frequency: .time_frequency[0]}
    ] |
    unique |
    map({key: "\(.table) \(.variable) \(.frequency)", value: (_variable_specs($entries_by_name) | mip_variable_iri)}) |
    from_entries
) as $variable_iris |
[
    .response.docs[] |
    (.master_id | split(".")) as $parts |
    {
        product: $parts[1],
        institute: $parts[2],
        model: $parts[3],
        experiment: $parts[4],
        ensemble: $parts[-1]
    } as $id |

    (_ns + "datasets/\(.master_id)") as $dataset |
    (_ns + "datasets/cmip5.\($id.model).\($id.experiment).\($id.ensemble).\($id.product)") as $output |
    (_ns + "simulations/cmip5.\($id.model).\($id.experiment).\($id.ensemble)") as $simulation |
    (_ns + "simulations/cmip5.\($id.model).\($id.experiment)") as $ensemble |
    (_ns + "datasets/cmip5.\($id.model).\($id.experiment).\($id.product)") as $ensemble_output |
    (_ns + "mips/cmip5/experiments/\($id.experiment)") as $experiment |
    (_ns + "datasets/cmip5.\($id.experiment)/output") as $experiment_output |
    "\($simulation)/geodetic-grid" as $space |
    [.model[] | _ns + "models/\(_quote)"] as $models |
    [.institute[] | _ns + "organizations/\(_quote)"] as $institutes |
    .cmor_table[0] as $table |
    .time_frequency[0] as $frequency |
    [.variable[]? | $variable_iris["\($table) \(.) \($frequency)"]] as $variables |
    [
        .experiment[] |
        {
            rcp45: "RCP/RCP4.5",
            rcp85: "RCP/RCP8.5",
            rcp26: "RCP/RCP2.6",
            rcp60: "RCP/RCP6"
        }[.] // empty |
        _ns + "scenarios/\(.)"
    ] as $scenarios |
    _temporal_grid as $time |
    (
        if $time != null then
            "\(_ns)dimensions/time/reference-frames/gregorian/regions/\($time.start)-\($time.end)"
        else null end
    ) as $region |
    (if $region != null then "\($region)/specialization" else null end) as $time_specialization |
    (
        if $time.grid_type_id != null then
            {
                variable: "\($region)/quantized/\($time.grid_type_id)",
                quantization: "\(_ns)dimensions/time/reference-frames/gregorian/quantizations/\($time.grid_type_id)"
            }
        else null end
    ) as $time_grid |
    ($scenarios | map(_id(.))) as $refers_to_scenario |
    ($variables | map(_id(.))) as $holds_variable |
    _id(_ns + "dimensions/geodetic/all/specialization") as $geodetic_specialization |

    # Dataset
    {
        "@id": $dataset,
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": .master_id,
        "data:holdsSpecializationOfVariable": $holds_variable,
        "data:dependsOnVariable": [_id($space), ($time_grid.variable | values | _id(.))],
        "data:isSpecializedAccordingTo": [($time_specialization | values | _id(.)), $geodetic_specialization],
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the simulation
    {
        "@id": $output,
        "@type": ["ccso:SingleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment).\($id.ensemble).\($id.product)" | _en),
        "ccso:productId": $id.product,
        "rdfs:comment": [.description[]? | _en],
        "data:holdsSpecializationOfVariable": $holds_variable,
        "data:dependsOnVariable": _id($space),
        "top:hasComponent": _id($dataset),
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Simulation
    {
        "@id": $simulation,
        "@type": ["ccso:SingleSimulation", "ccso:GlobalClimateSimulation"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment).\($id.ensemble)" | _en),
        "top:componentIdentifier": $id.ensemble,
        "data:hasOutput": _id($output),
        "ccso:usesModel": ($models | map(_id(.))),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Ensemble
    {
        "@id": $ensemble,
        "@type": ["ccso:PerturbedParameterClimateEnsembleSimulation", "ccso:GlobalClimateSimulation"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment)" | _en),
        "top:hasComponent": _id($simulation),
        "data:hasOutput": _id($ensemble_output),
        "ccso:usesModel": ($models | map(_id(.))),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the ensemble
    {
        "@id": $ensemble_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("cmip5.\($id.model).\($id.experiment).\($id.product)" | _en),
        "data:holdsSpecializationOfVariable": $holds_variable,
        "top:hasComponent": _id($output),
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Experiment
    {
        "@id": $experiment,
        "@type": ["ccso:ClimateModelIntercomparisonExperiment", "ccso:GlobalClimateSimulation"],
        "top:hasComponent": _id($ensemble),
        "data:hasOutput": _id($experiment_output),
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of the experiment
    {
        "@id": $experiment_output,
        "@type": ["ccso:EnsembleProjection", "ccso:ScenarioBasedProjection"],
        "rdfs:label": ("output of cmip5.\($id.experiment)" | _en),
        "data:holdsSpecializationOfVariable": $holds_variable,
        "top:hasComponent": _id($ensemble_output),
        "data:isSpecializedAccordingTo": $geodetic_specialization,
        "ccso:refersToScenario": $refers_to_scenario
    },
    # Output of CMIP5
    {
        "@id": (_ns + "mips/cmip5/output"),
        "top:hasComponent": _id($experiment_output)
    },
    # Model
    (
        [.model[] | _en] as $labels |
        $models[] |
        {
            "@id": .,
            "@type": "ccso:GlobalClimateModel",
            "rdfs:label": $labels,
            "ccso:isMaintainedBy": ($institutes | map(_id(.)))
        }
    ),
    # Institute
    (
        .institute as $acronyms |
        $institutes[] |
        {
            "@id": .,
            "@type": "top:Organization",
            "top:acronym": $acronyms
        }
    ),
    # Spatial grid
    {
        "@id": $space,
        "@type": "data:DimensionalSpace",
        "data:basedOnDimensionalSpace": _id(_ns + "dimensions/geodetic/reference-frames/WGS84"),
        "data:hasExactBoundingRegion": _id(_ns + "dimensions/geodetic/all")
    },
    # Temporal grid
    (
        $time | values |
        {
            "@id": $time_specialization,
            "@type": "data:VariableSpecialization",
            "data:isSpecializationOn": _id(_ns + "dimensions/time"),
            "data:hasSelectedRegion": _id($region)
        },
        {
            "@id": $region,
            "@type": "data:TemporalRegion",
            "data:hasStartDateTime": (.start | _typed("xsd:dateTime")),
            "data:hasEndDateTime": (.end | _typed("xsd:dateTime")),
            "rdfs:label": ("Time interval \(.start) - \(.end)" | _en),
            "rdfs:comment": ("Time interval starting at date time \(.start) and ending at date time \(.end)." | _en)
        },
        (
            $time_grid | values |
            {
                "@id": .variable,
                "@type": "data:DimensionalSpace",
                "data:basedOnDimensionalSpace": _id(_ns + "dimensions/time/reference-frames/gregorian"),
                "data:hasDiscretization": _id(.quantization),
                "data:hasExactBoundingRegion": _id($region)
            },
            {
                "@id": .quantization,
                "@type": "data:\($time.dimensional_space_type)",
                "data:basedOnDimensionalSpace": _id(_ns + "dimensions/time"),
                "data:hasResolutionValue": ($time.step | _typed("xsd:duration")),
                "data:hasPeriodValue": ($time.period | _typed("xsd:duration")),
                "data:hasInPeriodResolutionValue": ($time.in_period_step | _typed("xsd:duration")),
                "data:hasOffsetValue": ($time.offset | _typed("xsd:duration"))
            }
        )
    )
] |
# without empty values, each node once
map(with_entries(select(.value != null and .value != []))) |
unique |
{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        xsd: "http://www.w3.org/2001/XMLSchema#",
        top: "https://w3id.org/hacid/onto/top-level/",
        ccso: "https://w3id.org/hacid/onto/ccso/",
        data: "https://w3id.org/hacid/onto/data/"
    },
    "@graph": .
}
