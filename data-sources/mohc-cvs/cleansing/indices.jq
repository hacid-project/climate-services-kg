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
    "12-month river drought (extreme)": "12-Month River Drought (Extreme)",
    "12-month river drought (severe)": "12-Month River Drought (Severe)",
    "24-month river drought (extreme)": "24-Month River Drought (Extreme)",
    "24-month river drought (severe)": "24-Month River Drought (Severe)",
    "Accumulated frost": "Accumulated Frost",
    "Amber heat-health alert": "Amber Heat-Health Alert",
    "Average temperature": "Average Temperature",
    "Cold weather alert": "Cold weather alert",
    "Cooling degree days": "Cooling Degree Days",
    "Crop growth duration": "Crop Growth Duration",
    "Dairy cattle heat stress": "Dairy Cattle Heat Stress",
    "Days above field capacity": "Days Above Field Capacity",
    "Frost days": "Frost Days",
    "Growing degree days": "Growing Degree Days",
    "Growing season length": "Growing Season Length",
    "Heat stress": "Heat Stress",
    "Heating degree days": "Heating Degree Days",
    "Low flows (10-year return period)": "Low Flows (10-Year Return Period)",
    "Low flows (2-year return period)": "Low Flows (2-Year Return Period)",
    "Low flows (likelihood of current 10-year event)": "Low Flows (Likelihood of Current 10-Year Event)",
    "Marine Heatwaves Days index (MHD)": "Marine Heatwaves Days Index (MHD)",
    "Maximum temperature": "Maximum Temperature",
    "Mean soil moisture": "Mean Soil Moisture",
    "Mean temperature": "Mean Temperature",
    "Met Office heatwave": "Met Office Heatwave",
    "Minimum temperature":  "Minimum Temperature",
    "Ocean pH level": "Ocean pH Level",
    "Rail: bad weather days": "Rail: Bad Weather Days",
    "Rail: high temperatures": "Rail: High Temperatures",
    "Record-breaking weather (hottest day)": "Record-Breaking Weather (Hottest Day)",
    "Record-breaking weather (hottest month)": "Record-Breaking Weather (Hottest Month)",
    "Record-breaking weather (wettest month)": "Record-Breaking Weather (Wettest Month)",
    "River flood": "River Flood",
    "River discharge": "River Discharge",
    "River flood (ClimateADAPT)": "River Flood",
    "River flood (10-year return period)": "River Flood (10-Year Return Period)",
    "River flood (2-year return period)": "River Flood (2-Year Return Period)",
    "River flood (5-year return period)": "River Flood (5-Year Return Period)",
    "River flood (likelihood of current 10-year event)": "River Flood (Likelihood of Current 10-Year Event)",
    "River flood (UK CRI)": [
        "River Flood (10-Year Return Period)",
        "River Flood (2-Year Return Period)",
        "River Flood (5-Year Return Period)",
        "River Flood (Likelihood of Current 10-Year Event)"
    ],
    "River runoff": "River Runoff",
    "Road accident risk": "Road Accident Risk",
    "Road melt risk": "Road Melt Risk",
    "SPEI drought": "SPEI Drought",
    "SPI drought": "SPI Drought",
    "Self-calibrating Palmer Drought Severity Index (scPDSI)": "Self-Calibrating Palmer Drought Severity Index (scPDSI)",
    "Soil moisture": "Soil Moisture",
    "Start of crop growing season": "Start of Crop Growing Season",
    "Start of field operations (Tsum200)":  "Start of Field Operations (Tsum200)",
    "Total precipitation": "Total Precipitation",
    "Tropical nights": "Tropical Nights",
    "Very hot days": "Very Hot Days",
    "Wheat heat stress": "Wheat Heat Stress",
    "Wildfire: FFMC 99th percentile": "Wildfire: FFMC 99th Percentile",
    "Wildfire: FFMC 00th percentile": "Wildfire: FFMC 00th Percentile"
} as $index_map |

{
    "Climate ADAPT": "Climate-ADAPT",
    "Copernicus CCS": "C3S"
} as $source_map |

{
    "Climate-ADAPT": {
        "Maximum temperature (climateADAPT)": "Maximum Temperature",
        "Minimum temperature (climateADAPT)": "Minimum Temperature"
    },
    "UK CRI": {
        "Maximum temperature (CRI)": "Maximum Temperature",
        "Minimum temperature (CRI)": "Minimum Temperature"
    }
} as $source_index_map |

def fix_sector:
    trim |
    if in($sector_map) then
        $sector_map[.] | if isempty(arrays) | not then .[] end
    end;

def fix_index_name:
    trim |
    if in($index_map) then
        $index_map[.] | if isempty(arrays) | not then .[] end
    end;

(
    [.[] |
        .Name |= fix_index_name |
        .AssociatedVariableSimple = [
            .AssociatedVariable |
            gsub("\\(.*\\)"; "") |
            split(".") | .[0] | split("or") | .[0] | split("/") | .[0] |
            split(",") | .[] | split("+") | .[] |
            trim | select(length > 0)
        ] |
        .Units |= [split(";") | .[] | split(",") | .[] | trim | fix_sector] |
        .LinkedIndicators |= [select(length > 0) | split(";") | .[] | split(",") | .[] | fix_index_name] |
        .Sector |= [.[] | fix_sector] 
    ] |
    group_by(.DefinitionSource) |
    [
        .[] | {
            key: .[0].DefinitionSource,
            value: {
                Name: .[0].DefinitionSource,
                Members:[.[] | {
                    key: .Name,
                    value: .
                }] | from_entries
            }
        }
    ] | from_entries
) as $grouped_indices | 

(
    [
        (
            $grouped_indices | to_entries | .[] |
            .key as $group_id |
            .value.Members | to_entries | .[] |
            .value = {
                group: $group_id,
                index: .key
            }
        ),
        (
            $source_index_map | to_entries | .[] |
            .key as $group_id |
            .value | to_entries | .[] | {
                key: .key,
                value: {
                    group: $group_id,
                    index: .value
                }
            }
        )
    ] | from_entries
) as $index_to_group_map |

$grouped_indices |
with_entries(
    .value.Members |= with_entries(
        .value.LinkedIndicators |= (select(length > 0) | map($index_to_group_map[.]))
    )
)
