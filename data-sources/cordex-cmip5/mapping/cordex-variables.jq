# Variables of the CORDEX-CMIP5 datasets (ESGF search results), shared by the
# mapping (datasets.jq) and the analysis of the variables
# (analysis/variables-check.jq).
#
# The modules of data-sources/cmip5/mapping (esgf.jq) and of
# data-sources/cmor-tables/mapping must be in the library path (-L).

include "esgf";

# CMIP5 CMOR tables of the time frequencies of the CORDEX datasets, where
# their variables are looked up first (the variables of the other frequencies,
# as 1hr and sem, in any table)
def frequency_tables:
    {
        "3hr": ["3hr"],
        "6hr": ["6hrPlev", "6hrLev"],
        "day": ["day", "cfDay"],
        "mon": ["Amon", "Lmon", "LImon", "OImon", "aero", "cfMon"],
        "fx": ["fx"]
    };

# Key of a variable of a dataset of a time frequency
def variable_key($variable; $frequency): "\($variable) \($frequency)";

# IRIs of the variables of the datasets (input: their ESGF metadata, as an
# array), by variable_key: the MIP variables resolved from the definitions of
# the variables in the CMIP5 CMOR tables (cmip5_variable_iri), in the tables
# of the time frequency of the dataset first ($entries_by_name: the CMIP5 CMOR
# tables by cmip5_entries_by_name)
def variable_iris($entries_by_name):
    [.[] | {variable: .variable[], frequency: .time_frequency[0]}] |
    unique |
    map({
        key: variable_key(.variable; .frequency),
        value: (.tables = (frequency_tables[.frequency] // []) | cmip5_variable_iri($entries_by_name))
    }) |
    from_entries;
