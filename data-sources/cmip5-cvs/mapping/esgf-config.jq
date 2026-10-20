# Controlled vocabularies of CMIP5 from the configuration of the ESGF
# publisher (https://github.com/ESGF/config), read as raw text:
# - publisher-configs/ini/esg.cmip5.ini: the maps experiment_description_map
#   ("experiment | description") and institute_map ("model | institute");
# - publisher-configs/esgcet_models_table.txt: lines "project | model | URL |
#   description", the description being "<model name>, <institute name>" or
#   just a name; the cmip5 lines give the names of the institutes of the
#   models.
#
# The institutions are obtained joining the institute map with the models
# table. The models are matched ignoring the case (the table has e.g. both
# HadCM3 and HADCM3, the map inmcm4 and the table INMCM4).

def _lines: split("\n");

# Lines of a block of an ini file: the indented lines after the line $header
def ini_block($header):
    _lines | .[index($header) + 1:] as $rest |
    $rest[: ([range($rest | length) | select($rest[.] | test("^\\s+\\S") | not)] | first // ($rest | length))];

# Models of CMIP5 in the models table: [{model, description, name, parsed}],
# the name being the description without the part up to the first ", "
# (usually the name of the model), if any (parsed)
def esgf_cmip5_models($models_table):
    $models_table | _lines |
    map(
        select(test("^\\s*#") | not) |
        split("|") | map(trim) |
        select(length == 4 and .[0] == "cmip5") |
        {
            model: .[1],
            description: .[3],
            name: (.[3] | if test(", ") then sub("^[^,]*, "; "") else . end),
            parsed: (.[3] | test(", "))
        }
    );

# Rows of a map of the ini ("<key> | <value>"): [[key, value]]
def ini_map($name):
    ini_block($name) | map(split("|") | map(trim));

# The experiments of the ini (experiment_description_map): [{id, description}]
def esgf_experiments($ini):
    $ini | ini_map("experiment_description_map = map(experiment : experiment_description)") |
    map({id: .[0], description: .[1]});

# The institute_map of the ini: [{model, institute}]
def esgf_institute_map($ini):
    $ini | ini_map("institute_map = map(model : institute)") |
    map({model: .[0], institute: .[1]});

# Institutions: [{id, acronym, description, models, candidates}], with
# - id: the id of the institute in upper case, as in the ids of the CMIP5
#   datasets (e.g. CCCMA for CCCma);
# - acronym: the id of the institute in the map;
# - candidates: the names of the institute given by the lines of its models,
#   with the number of lines and whether they were parsed from a description
#   with ", " (otherwise they may be names of models or projects, e.g.
#   "Community Climate System Model 4"), excluding the names that are just the
#   id of a model (e.g. SP-CCSM4);
# - description: the most frequent candidate (null if none; the first in
#   alphabetical order if more are as frequent).
def esgf_institutions($models_table; $ini):
    esgf_cmip5_models($models_table) as $models |
    [$models[].model | ascii_downcase] as $model_ids |
    esgf_institute_map($ini) |
    group_by(.institute) |
    map(
        (map(.model)) as $institute_models |
        [$institute_models[] | ascii_downcase] as $keys |
        [
            $models[] |
            select(.model | ascii_downcase | IN($keys[])) |
            {name, parsed} |
            select(.name | ascii_downcase | IN($model_ids[]) | not)
        ] as $names |
        ($names | group_by(.) | map(.[0] + {lines: length}) | sort_by(-.lines)) as $candidates |
        {
            id: (.[0].institute | ascii_upcase),
            acronym: .[0].institute,
            description: ($candidates[0].name // null),
            models: $institute_models,
            candidates: $candidates
        }
    );

# Fixes of the institutions ($fixes, mapping/institution-fixes.json, by id):
# - names: {<id>: {name, reason}}, the name to use instead of that of ESGF,
#   kept in esgf_description, with the reason in fix;
# - excluded: {<id>: reason}, the institutions to leave out.
def fix_institutions($fixes):
    map(
        select(.id | in($fixes.excluded) | not) |
        if .id | in($fixes.names) then
            . + {
                description: $fixes.names[.id].name,
                esgf_description: .description,
                fix: $fixes.names[.id].reason
            }
        end
    );
