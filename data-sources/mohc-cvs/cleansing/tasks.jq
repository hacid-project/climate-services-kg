# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

# gerund_to_base: convert a regular gerund (string) -> base verb (string).
# Works for most regular patterns; extend "exceptions" with irregular gerunds if needed.
def gerund_to_base:
    # small exceptions map (extend if you want to cover irregulars)
    {
        "being":"be","having":"have","doing":"do","going":"go","getting":"get","setting":"set",
        "collecting": "collect",
        "requesting": "request",
        "listing": "list",
        "looking": "look",
        "selecting": "select",
        "extracting": "extract",
        "conducting": "conduct",
        "performing": "perform",
        "rejecting": "reject",
        "sending": "send",
        "presenting": "present",
        "postprocessing": "postprocess"
        } as $exceptions |

    # 1) explicit exception hit (returns mapped base) OR continue with rules using .
    if (in($exceptions)) then
        $exceptions[.]
    else

        # 2) "eeing" -> "ee" (seeing -> see ; freeing -> free)
        if test("eeing$") then sub("eing$"; "e")

        # 3) "ying" ambiguous cases:
        #    - short forms like "dying","tying","lying" are usually from base ending in "ie" -> restore "ie"
        #    - longer forms like "crying","studying" are from base ending in "y" -> restore "y"
        elif test("ying$") then
            if (length <= 5) then  # heuristic: short words (5 chars e.g. dying, tying, lying)
                sub("ying$"; "ie")
            else
                sub("ying$"; "y")
            end

        # 4) doubled final consonant before -ing (running -> run, stopping -> stop)
        elif test("([bcdfghjklmnpqrstvwxyz])\\1ing$") then
            sub("([bcdfghjklmnpqrstvwxyz])\\1ing$"; "\\1")

        # 5) verbs formed by dropping final 'e' before adding -ing (making -> make)
        #    Heuristic: if replacing "ing" by "e" produces a plausible-looking -e form,
        #    and not caught by previous rules, restore 'e'.
        #    We apply this *after* doubling-consonant/x/ying rules so it won't overfire.
        elif test("[^aeiou]ing$") and ( (sub("ing$"; "e") | test("^[a-z]{2,}e$")) ) then
            sub("ing$"; "e")

        # 6) fallback: drop -ing (talking -> talk, opening -> open)
        elif test("ing$") then
            sub("ing$"; "")
        else
            .
        end
    end;

def base_to_third_person:
    if test("(s|x|z|ch|sh)$") then
        # verbs ending in s, x, z, ch, sh → add "es"
        . + "es"
    elif test("[^aeiou]y$") then
        # consonant + y → replace y with ies (try → tries)
        sub("y$"; "ies")
    elif test("e$") then
        # verbs ending with e → add s (make → makes)
        . + "s"
    elif test("o$") then
        # verbs ending with o → usually add es (go → goes)
        . + "es"
    else
        # default: just add s
        . + "s"
    end;

def fix_description:

    {
        "Less than 1 year\n1-3 years\n4-6 years\n7-10 years\nMore than 10 years":
            "The operation that quantifies years of experience in using climate data",
        "Low Medium High. A measure of the extent to which a user is willing to accept uncertainty and potential adverse outcomes related to climate risks. For example, a low risk tolerance indicates a preference for detailed quantification of even the most extreme climate scenarios, enabling proactive planning and adaptation to minimise potential impacts. ":
            "The operation that rates risk tolerance, i.e. a measure of the extent to which a user is willing to accept uncertainty and potential adverse outcomes related to climate risks: for example, a low risk tolerance indicates a preference for detailed quantification of even the most extreme climate scenarios, enabling proactive planning and adaptation to minimise potential impacts."
    } as $replace_map |

    [
        "The task of manually ",
        "The task of spatially ",
        "The task of "
    ] as $prefixes |

    if in($replace_map) then
        $replace_map[.]
    else
        . as $description | 
        reduce $prefixes.[] as $prefix (
            $description;
            if startswith($prefix) then
                ltrimstr($prefix) | split(" ") |
                [
                    "The operation that",
                    (.[0] | gerund_to_base | base_to_third_person),
                    .[1:].[]
                ] | join(" ")
            end
        )
    end;

{
    "Organisation Type": "OrganisationType",
    "Organization Size": "OrganizationSize",
    "Sector": "Sector",
    "Hazard": "Hazard",
    "Risk rating": "RiskRating",
    "Index; variable": "Index; variable",
    "Global warming level": "Global warming level",
    "Method": "Method",
    "Emission scenario": "Emission scenario",
    "Sub-annual period": "Sub-annual period",
    "Observation type": "Observation type",
    "Access point": "Access point",
    "Climate simulations": "Climate simulations",
    "Observation datasets": "Observation datasets",
    "Method": "Method",
    "Confidence level: low, medium, high": "Confidence level: low, medium, high"
} as $cv_map |

{
    "Information requester": "InformationRequester",
    "Case creator": "CaseCreator",
    "Case solver": "CaseSolver"
} as $role_map |

{
    "Search additional Information": "Search additional information"
} as $task_name_map |

def fix_tax_name:
    $task_name_map[.] // .;

def get_information_type:
    . as $task |
    if .AssociatedEntities | startswith("Text") then
        {type: "text"}
    elif .AssociatedEntities == "Number" or  .AssociatedEntities == "Spatial resolution" then
        {type: "number"}
    elif .AssociatedEntities | startswith("Date") then
        {type: "date"}
    elif .AssociatedEntities == "Temporal resolution" then
        {type: "duration"}
    elif .AssociatedEntities == "Spatial region" then
        {type: "geodetic-region"}
    else
        {type: "uri", cv: (.AssociatedEntities | ($cv_map[.] // "unknown"))}
    end |
    if $task.Range == "Yes" then
        {type: "range", items: .}
    elif $task.Range == "Optional" then
        {type: "range-or-exact", items: .}
    end;

[
    .[] |
    with_entries(select(.value | length > 0)) |
    .WorkflowInfo = (
        {
            Roles: .Role | map($role_map[.] // "unknown"),
            InformationType: .InformationType
        }
        +   if .Condition then {Condition: .Condition} else {} end
        +   if .BackwardDependency then
                {
                    BackwardDependencies: [
                        .BackwardDependency
                        | (select(length > 0) | split("\n") | .[] | trim | select(length > 0))]}
            else
                {}
            end
        +   if .ForwardDependecy then
                {
                    ForwardDependencies: [
                        .ForwardDependecy
                        | (select(length > 0) | split("\n") | .[] | trim | select(length > 0))]}
            else
                {}
            end
    ) |
    del(.BackwardDependency) | del(.ForwardDependecy) |
    del(.Role) | del(.InformationType) | del(.Condition) |
    .Description = (.TaskDescription | fix_description) |
    del(.TaskDescription) |
    if .AssociatedEntities then .AssociatedData = get_information_type end |
    del(.AssociatedEntities) | del(.Range)
] as $all_operations |

[
    $all_operations | .[] | select(.Task | length > 0) |
    .Name = (.Task | fix_tax_name) |
    del(.Task)
] as $generic_operations |

(
    [
        $all_operations | .[] | select(.Subtask | length > 0) |
        .Name = (.Subtask | fix_tax_name) |
        del(.Subtask) |
        .ParentTask |= fix_tax_name
    ] | group_by(.ParentTask) |
    [
        .[] | {
            key: .[0].ParentTask,
            value: map(del(.ParentTask))
        }
    ]| from_entries
) as $specific_operations |

[
    $generic_operations | .[] |
    .Specializations = (
        select(.Name | in($specific_operations)) |
        $specific_operations[.Name]
    )
] | group_by(.ParentTask) |
[
    (.[] | select(.[0].ParentTask) | {
        Name: .[0].ParentTask,
        Specializations: map(del(.ParentTask))
    }),
    (.[] | select(.[0].ParentTask | not) | .[])
]
