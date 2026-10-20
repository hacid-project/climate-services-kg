# Parsing of the list of the CORDEX RCMs of IS-ENES (CORDEX_RCMs_info.txt of
# https://github.com/IS-ENES-Data/IS-ENES-Data.github.io, generated from the
# CORDEX RCM registration sheet), read as raw text: after the comments (#),
# a line for each RCM, with columns of fixed width:
#
#   <model id> <institute id> <terms of use> <institution name>
#
# A model id longer than its column runs into the institute id, without
# spaces (e.g. CLMcom-ETH-COSMO-crCLIM-v1-1CLMcom-ETH): the two are split
# taking the institute id as the end of the string that is also the start of
# the model id (the model ids start with the institute ids). The terms of use
# are unrestricted or non-commercial. The spaces in the names are normalised.

def rcms_info:
    split("\n") |
    map(
        select(test("^\\s*(#|$)") | not) |
        capture("^(?<ids>.+?)\\s+(?<terms_of_use>unrestricted|non-commercial)\\s+(?<institute_name>.*?)\\s*$") |
        (.ids | [splits("\\s+")]) as $ids |
        (
            if ($ids | length) == 2 then {model_id: $ids[0], institute_id: $ids[1]}
            else $ids[0] | capture("^(?<model_id>(?<prefix>.+)-.+)\\k<prefix>$") | {model_id, institute_id: .prefix}
            end
        ) + {
            institute_name: (.institute_name | gsub("\\s+"; " ")),
            terms_of_use
        }
    );

# Fixes of the RCMs ($fixes, mapping/rcm-fixes.json): {<model id>: {<field>:
# <value>, ..., reason}}, the values of the fields to use instead of those of
# the list, kept in "original", with the reason in "fix".
def fix_rcms($fixes):
    map(
        if .model_id | in($fixes) then
            $fixes[.model_id] as $fix |
            ($fix | del(.reason)) as $values |
            . + $values + {
                original: with_entries(select(.key | in($values))),
                fix: $fix.reason
            }
        end
    );
