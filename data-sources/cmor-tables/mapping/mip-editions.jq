# Editions of the CMOR tables needed for the mapping to the MIP variables
# (see mip-mapping.md): the edition of the current era, whose variables are the
# MIP variables, and the editions of the previous variables kept separate (the
# versions with keep/sign_change/unit_change entries in mip-mapping.json).
#
# Input: the configuration of the eras (config/cmor-tables-eras.json).
# Output: the editions as <source>/<edition> (as in config/config.yaml)
#   {"current": "mip/v6.5.0.4", "previous": ["cmip5/5.0", "cmip6/6.0.12", ...]}
#
#   jq -L data-sources/cmor-tables/mapping -f data-sources/cmor-tables/mapping/mip-editions.jq config/cmor-tables-eras.json

include "./mip-variables";

def edition($edition): "\(era_source)/\($edition)";

(.eras | map({key: .era, value: .}) | from_entries) as $eras |
{
    current: (
        ($eras[.current] // error("current era not in the eras: \(.current)")) |
        edition(.edition // error("no edition for the current era \(.era)"))
    ),
    previous: [
        mip_mapping[] |
        ($eras[.era] // error("era of the mapping not in the eras: \(.era)")) as $era |
        [mip_section_entries | .version] | unique | .[] |
        if . == null then
            # era without versions
            $era | edition(.edition // error("no edition for the era \(.era)"))
        else
            . as $version | $era | edition($version)
        end
    ] | unique
}
