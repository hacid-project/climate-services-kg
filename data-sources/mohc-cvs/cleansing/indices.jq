import "./cleansing/fix_index_names" as fix_index_module;

# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

{
    "Day of year (1 = January 1st)": "day of year (1 = January 1st)",
    "Days": "days",
    "Days/year": "days/year",
    "Events/year": "events/year",
    "Months/year": "months/year",
    "Proportion of time": "Proportion of time",
} as $unit_map |

{
    "Agriculture": "Agriculture and Food Security",
    "Agriculture and food security": "Agriculture and Food Security",
    "agriculture and food security": "Agriculture and Food Security",
    "Biodiversity": "Biodiversity/Ecosystems",
    "Biodiversity/ Ecosystems": "Biodiversity/Ecosystems",
    "Human health": "Human Health",
    "Water resources": "Water Resources",
    "water resources": "Water Resources",
    "disaster risk reduction": "Disaster Risk Reduction",
    "forestry/GHG": "Forestry/GHG",
    "secondary: Transport": "Transport",
    "transport and energy": ["Transport", "Energy"]
} as $sector_map |

{
    "Climate ADAPT": "Climate-ADAPT",
    "Copernicus CCS": "C3S"
} as $source_map |

def fix_sector:
    trim | ($sector_map[.]? | (.[]? // .)) // .;

(
    [.[] |
        .Name |= fix_index_module::fix_index_name |
        .AssociatedVariables = [
            .AssociatedVariable |
            gsub("\\(.*\\)"; "") |
            split(".") | .[0] | split("or") | .[0] | split("/") | .[0] |
            split(",") | .[] | split("+") | .[] |
            trim | select(length > 0)
        ] |
        ._AssociatedVariable = .AssociatedVariable |
        del(.AssociatedVariable) |
        .Units |= [split(";") | .[] | split(",") | .[] | trim | fix_sector] |
        .LinkedIndicators |= [select(length > 0) | split(";") | .[] | split(",") | .[] | fix_index_module::fix_index_name] |
        .Sectors = [.Sector | .[] | fix_sector] |
        del(.Sector) |
        with_entries(select(.value | length > 0) | .value |= trim)
    ] |
    group_by(.DefinitionSource) |
    [
        .[] | {
            key: .[0].DefinitionSource,
#            value: {
#                Name: .[0].DefinitionSource,
#                Members:[.[] | {
#                    key: .Name,
#                    value: .
#                }] | from_entries
#            }
            value: (
                [.[] | {
                    key: .Name,
                    value: del(.Name)
                }] | from_entries
            )
        }
    ] | from_entries
) as $grouped_indices | 

$grouped_indices |
with_entries(
#    .value.Members 
    .value |= with_entries(
        .value.LinkedIndicators |= fix_index_module::fix_indices($grouped_indices)
    )
)
