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
