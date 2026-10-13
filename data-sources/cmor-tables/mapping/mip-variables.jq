# IRIs of the MIP variables, resolving variables of previous editions of the
# CMOR tables through mip-mapping.json (see mip-mapping.md).
#
# Module, to be included or imported, e.g. (from the repository root):
#   jq -L data-sources/cmor-tables/mapping 'include "mip-variables"; mip_variable_iri'
# or run mip-variable-iri.jq.
#
# Input: an out_name, or an object describing the variable as known (all the
# fields but out_name are optional):
#   {
#       "out_name": "hus",
#       "era": "cmip6",            # era of the variable (case insensitive)
#       "quantity": "specific_humidity",  # CF standard name
#       "table": "Amon",
#       "dimensions": "longitude latitude plev19 time"  # or an array
#   }

import "./mip-mapping" as $MIP_MAPPING;

def _mip_variables_base: "https://w3id.org/hacid/data/cs/variables/mip/";

# Lists are either space-separated strings or arrays
def _words:
    if type == "array" then .[]
    elif type == "string" then splits("\\s+") | select(. != "")
    else empty
    end;

# Numeric parts of a version, to sort the entries: "6.3.27-fixed" -> [6, 3, 27]
def _version_key: [scan("[0-9]+") | tonumber];

# Input as an object, with normalised era and dimensions
def _variable_spec:
    (if type == "string" then {out_name: .} end) |
    {
        id: .out_name,
        era: (.era | if . != null then ascii_downcase end),
        quantity,
        table,
        dimensions: (if .dimensions != null then [.dimensions | _words] | unique end)
    };

# Conditions of a mapping entry or rename group (for_tables, dimensions,
# quantity) against the variable: each one must be known and match
def _applies_to($v):
    ((has("for_tables") | not) or ($v.table != null and any(.for_tables[]; . == $v.table))) and
    ((has("dimensions") | not) or ($v.dimensions != null and (.dimensions | unique) == $v.dimensions)) and
    ((has("quantity") | not) or ($v.quantity != null and .quantity == $v.quantity));

# Entries of a keep/sign_change/unit_change section as {version, kind, entry},
# where the section is either a list (no versions, as for cmip5) or an object
# version -> list; entries are either ids or objects with an id
def _versioned_entries($kind):
    if type == "array" then .[] | {version: null, kind: $kind, entry: .}
    elif type == "object" then to_entries[] | .key as $version | .value[] | {version: $version, kind: $kind, entry: .}
    else empty
    end |
    .entry |= (if type == "string" then {id: .} end);

# Resolution of a variable with a mapping (the array in mip-mapping.json):
#   {
#       id,        # out_name of the variable in the last version, or in the
#                  # version given by era/version if it is a previous variable
#       era, version,  # null for a variable of the last version, otherwise
#                      # the era and version of the matching entry (version is
#                      # null if the era has no versions in the mapping)
#       kind,      # null, "keep", "sign_change" or "unit_change"
#       entry,     # the matching keep/sign_change/unit_change entry
#       renames    # renames applied, as [{era, from, to}]
#   }
def mip_variable_resolution($mapping):
    _variable_spec as $v |
    ($mapping | map(.era) | index($v.era)) as $start |
    reduce (if $start == null then empty else $mapping[$start:][] end) as $section (
        {id: $v.id, era: null, version: null, kind: null, entry: null, renames: []};
        if .kind != null then .
        else
            . as $state |
            ($v + {id: $state.id}) as $current |
            (first(
                [
                    $section | (
                        (.keep | _versioned_entries("keep")),
                        (.sign_change | _versioned_entries("sign_change")),
                        (.unit_change | _versioned_entries("unit_change"))
                    )
                ] |
                sort_by(.version | if . == null then [] else _version_key end) |
                .[] |
                select(.entry.id == $current.id and (.entry | _applies_to($current)))
            ) // null) as $match |
            if $match != null then
                .era = $section.era | .version = $match.version | .kind = $match.kind | .entry = $match.entry
            else
                (first($section.rename[]? | select(_applies_to($current)) | .map[$current.id] // empty) // null) as $new_id |
                if $new_id != null then
                    .renames += [{era: $section.era, from: .id, to: $new_id}] | .id = $new_id
                end
            end
        end
    );

def mip_variable_resolution: mip_variable_resolution($MIP_MAPPING::MIP_MAPPING[0]);

# IRI of a resolution: <base><out_name> for a variable of the last version,
# <base><era>/<version>/<out_name> for a variable of a previous version
def mip_variable_resolution_iri:
    _mip_variables_base + ([.era, .version, .id] | map(select(. != null) | @uri) | join("/"));

def mip_variable_iri($mapping): mip_variable_resolution($mapping) | mip_variable_resolution_iri;

def mip_variable_iri: mip_variable_resolution | mip_variable_resolution_iri;
