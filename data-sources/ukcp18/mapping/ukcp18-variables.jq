# Variables of the UKCP18 datasets: the MIP variables resolved through
# data-sources/cmor-tables/mapping/mip-mapping.json (the modules of
# data-sources/cmor-tables/mapping must be in the library path, -L), and the
# UKCP18 variables not defined in the CMOR tables
# (https://w3id.org/hacid/data/cs/variables/ukcp/<name>).

include "mip-variables";

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

# The UKCP18 variable of a dataset (input: its metadata), if its variable is not
# a MIP variable: {name, iri, anomaly_of, derived_from} (IRIs of MIP variables).
# Besides the variables above, each <variable>Anom is the anomaly of the MIP
# variable <variable>.
def ukcp_variable:
    (_variable_renames[.variable] // .variable) as $name |
    if _ukcp_variables[$name] != null then
        {
            name: $name,
            derived_from: [_ukcp_variables[$name].derived_from[]? | _mip_variable_iri_of(.)]
        }
    elif $name | test(".Anom$") then
        {name: $name, anomaly_of: _mip_variable_iri_of($name | rtrimstr("Anom"))}
    else
        null
    end |
    if . != null then .iri = _ukcp_variables_base + (.name | @uri) end;

# IRI of the variable of a dataset (input: its metadata): the UKCP18 variable,
# if any, otherwise the MIP variable of its name in the CMIP5 era (UKCP18 is
# based on CMIP5 models), with its units and, if known, the CMIP5 table of the
# source data (cmip5_table_id, e.g. "Table Amon (12 November 2010) 6e53...",
# for the land-gcm datasets) (or the IRI already resolved in the variable_iri
# field, see with_variable_iris)
def variable_iri:
    .variable_iri // ukcp_variable.iri // ({
        out_name: (_variable_renames[.variable] // .variable),
        era: "cmip5",
        table: ((.cmip5_table_id // "" | capture("^Table (?<table>\\S+)").table) // null),
        units
    } |
    mip_variable_iri);

# The datasets (input: array of metadata) with the IRIs of their variables in
# the variable_iri field, resolved once for each variable, units and table
def with_variable_iris:
    def key: [.variable, .units, .cmip5_table_id] | tojson;
    (unique_by(key) | map({key: key, value: variable_iri}) | from_entries) as $variable_iris |
    map(.variable_iri = $variable_iris[key]);

# Nodes of the UKCP18 variables of the datasets (input: array of metadata),
# with the terms of the context of datasets.jq: label from the long name of the
# variable (of the datasets that are not probability densities), anomalies
# linked to their MIP variable (ccso:isAnomalyOf), the others to the MIP
# variables they are derived from (data:derivedFromVariable)
def ukcp_variable_nodes:
    [.[] | {variable, variable_long_name}] |
    group_by(.variable) |
    map(
        (.[0] | ukcp_variable) as $variable |
        select($variable != null) |
        (
            [.[].variable_long_name | strings | select(test("probability density") | not)] |
            unique | .[0]
        ) as $long_name |
        {
            "@id": $variable.iri,
            "@type": "data:Variable",
            is_member_of: _ukcp_variables_collection,
            label: (
                if $long_name == null then $variable.name
                elif $variable.anomaly_of then "\($long_name) anomaly (\($variable.name))"
                else "\($long_name) (\($variable.name))"
                end
            ),
            acronym: $variable.name,
            is_anomaly_of: $variable.anomaly_of,
            derived_from_variable: $variable.derived_from
        }
    ) |
    unique_by(."@id");
