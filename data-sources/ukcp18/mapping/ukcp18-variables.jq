# IRIs of the variables of the UKCP18 datasets: the MIP variables resolved
# through data-sources/cmor-tables/mapping/mip-mapping.json (the modules of
# data-sources/cmor-tables/mapping must be in the library path, -L).

include "mip-variables";

# IRI of the variable of a dataset (input: its metadata): the MIP variable of
# its name in the CMIP5 era (UKCP18 is based on CMIP5 models), with its units
# and, if known, the CMIP5 table of the source data (cmip5_table_id, e.g.
# "Table Amon (12 November 2010) 6e53...", for the land-gcm datasets)
# (or the IRI already resolved in the variable_iri field, see with_variable_iris)
def variable_iri:
    .variable_iri // ({
        out_name: .variable,
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
