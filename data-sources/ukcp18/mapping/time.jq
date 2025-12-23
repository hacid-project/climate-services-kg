import "./mapping/utils" as UTILS;

def is_leap_year:
    . % 4 == 0 and (. % 100 !=0 or . % 400 == 0);

def days_in_month($year):
    [31,28,31,30,31,30,31,31,30,31,30,31] as $days_by_month |
    if . == 2 and ($year | is_leap_year) then 29
    else $days_by_month[.]
    end;

def date_add_day:
    .year as $year |
    (.month | days_in_month($year)) as $days_in_month |
    .day += 1 |
    if .day > $days_in_month then
        .day = 1 |
        .month += 1 |
        if .month > 12 then
            .month = 1 |
            .year += 1
        end
    end;

def number_tostring($digits):
    tostring |
    "0" * ([$digits - length, 0] | max) + .;

def datetime_string:
    "\(.year | number_tostring(4))-\(.month | number_tostring(2))-\(.day | number_tostring(2))T00:00:00Z";

def normalize_date($roundUp):
    (.[0:4] | tonumber) as $year |
    (
        if length > 4 then
            .[4:6] | tonumber
        elif $roundUp then
            12
        else 
            1
        end
    ) as $month |
    (
        if length > 6 then 
            .[6:8] | tonumber
        elif $roundUp then
            $month | days_in_month($year)
        else
            1
        end
    ) as $day |
    {$year, $month, $day} | date_add_day |
    datetime_string;

def variable($interval; $grid):
    (
        [
            $grid.grid_type, $grid.step, $grid.period, $grid.in_period_step |
            strings
        ] |
        join("/")
    ) as $grid_type_id |

    {
        "@id": "\($interval."@id")/quantized/\($grid_type_id)",
        "@type": "data:DimensionalSpace",
        based_on_ds: {
            "@id": "time:gregorian"
        },
        discretization: {
            grid: $grid,
            "@id": "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/quantizations/\($grid_type_id)",
            based_on_ds: {
                "@id": "dimension:time" # xsd:duration
            },
            "@type":  @uri "https://w3id.org/hacid/onto/data/\($grid.class)",
            resolution_value: $grid.step,
            period_value: $grid.period,
            in_period_resolution_value: $grid.in_period_step
        },
        exact_bounding_region: $interval."@id"
    };

def interval($start_datetime; $end_datetime):
    {
        "@id": "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/regions/\($start_datetime)-\($end_datetime)",
        "@type": "data:TemporalRegion",
        $start_datetime,
        $end_datetime,
        label: "Time interval \($start_datetime) - \($end_datetime)",
        coment: "Time interval starting at date time \($start_datetime) and ending at date time \($end_datetime)."
    };

def mobile_interval($duration):
    (
        $duration |
        capture("P((?<years>[0-9]+)Y)?((?<months>[0-9]+)M)?((?<days>[0-9]+)D)?") |
        with_entries(.value |= if . then tonumber else 0 end) |
        "\(.years | UTILS::lpad(4; "0"))\((.months + 1) | UTILS::lpad(2; "0"))\((.days + 1) | UTILS::lpad(2; "0"))T00:00:00Z"
    ) as $end_datetime |
    {
        "@id": "https://w3id.org/hacid/data/cs/dimensions/time/reference-frames/gregorian/mobile-regions/\($duration)",
        "@type": "data:TemporalRegion",
        start_datetime: "0000-01-01T00:00:00Z",
        $end_datetime,
        label: "Mobile temporal interval with duration \($duration)",
        coment: "Time interval with no fixed starting date time and a duration of \($duration)."
    };

def specialization:
    {
        "@id": "\(."@id")/specialization",
        "@type": "data:VariableSpecialization",
        specialization_on: {
            "@id": "dimension:time"
        },
        selected_region: .
    };

# def fill_in_time:
#     .time_variable = dataset_to_variable |
#     .time_specialization = (.date_interval | specialization);

