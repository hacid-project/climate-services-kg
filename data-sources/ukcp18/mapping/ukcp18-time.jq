import "./mapping/time" as TIME;


def str_to_interval:
    split("-") as $dates |
    ($dates[0] | TIME::normalize_date(false)) as $start_datetime |
    ($dates[1] | TIME::normalize_date(true)) as $end_datetime |
    TIME::interval($start_datetime; $end_datetime);

def str_to_mobile_interval:
    {
        "1y": "P1Y",
        "20y": "P20Y",
        "30y": "P30Y"
    }[.] as $duration |
    TIME::mobile_interval($duration);

def dataset_to_interval($id_comp_struct):
    if $id_comp_struct.date_interval then
        $id_comp_struct.date_interval | str_to_interval
    else
        .time_slice_type | str_to_mobile_interval
    end;

def dataset_to_variable($interval):

    (
        {
            regular: {
                type: "RegularBinning",
                instances: {
                    "1hr": "PT1H",
                    "3hr": "PT3H",
                    day: "P1D",
                    mon: "P1M",
                    seas: "P3M",
                    ann: "P1Y",
                    "ann-20y": "P20Y",
                    "ann-30y": "P30Y"
                }
            },
            "regular-periodic": {
                type: "PeriodicRegularBinning",
                instances: {
                    "mon-20y": {
                        in_period_step: "P1M",
                        period: "P1Y",
                        step: "P20Y"
                    },
                    "mon-30y":  {
                        in_period_step: "P1M",
                        period: "P1Y",
                        step: "P30Y"
                    },
                    "seas-20y":  {
                        in_period_step: "P3M",
                        period: "P1Y",
                        step: "P20Y"
                    },
                    "seas-30y":  {
                        in_period_step: "P3M",
                        period: "P1Y",
                        step: "P30Y"
                    }
                }
            }
        } |
        to_entries | [
            .[] |
            .key as $grid_type | .value |
            .type as $class | .instances | to_entries | .[] |
            .value |=
                if isempty(. | strings) | not then {
                    step: .,
                    period: null,
                    in_period_step: null
                } end + {
                    $grid_type,
                    $class
                }
        ] | from_entries
    ) as $frequency_map |

    # dataset_to_interval($id_comp_struct) as $interval |
    $frequency_map[.frequency] as $grid |
    TIME::variable($interval; $grid);

# def fill_in_time:
#     .time_variable = dataset_to_variable |
#     .time_specialization = (.date_interval | specialization);

