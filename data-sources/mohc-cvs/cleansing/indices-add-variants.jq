def get_date_ranges:
    [capture("(?<ref>[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9])").ref];

walk((
    select(.Units?) |
    . as $index |
    .Variants = [
        .Units.[] |
        if contains("change") then
            if contains("abs") then
                {Type:"absolute"}
            else
                empty
            end,
            (
                get_date_ranges as $date_ranges |
                if startswith("%") then
                    {Type:"change-relative"}
                else
                    {Type:"change-absolute"}
                end | 
                if $date_ranges | length > 0 then
                    .References = $date_ranges
                else
                    ($index.Definition | get_date_ranges) as $date_ranges |
                    if $date_ranges | length > 0 then
                        .References = $date_ranges
                    end
                end
            )
        else
            {Type:"absolute"}
        end 
    ] |
    if .Units[0] | startswith("%") | not then
        .Unit = (
            .Units[0] |
            sub(" \\(abs and change[^)]*\\)$"; "") |
            sub(" change from .*$"; "")
        )
    end |
    del(.Units)

) // .) 
