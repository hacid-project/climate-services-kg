# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

def to_camel_case:
    split(" ") |
    map((.[:1] | ascii_upcase) + (.[1:] | ascii_downcase)) |
    join("");

def split_by_sep:
    match("[- (),.?!;,\n\t]|[^- (),.?!;,\n\t]+"; "g") | .string;

def capitalize($all):
    {of: true, the: true} as $exceptions |
    [ split_by_sep ] |
    [
        (
            .[0] |
            if (.[1:] | ascii_downcase) == .[1:] then
                (.[:1] | ascii_upcase) + .[1:]
            end
        ),
        (
            .[1:].[] |
            if (.[1:] | ascii_downcase) == .[1:] then
                if $all and (in($exceptions) | not) then
                    (.[:1] | ascii_upcase) + .[1:]
                else
                    (.[:1] | ascii_downcase) + .[1:]
                end
            end
        )
    ] | join("");

def capitalize_first:
    capitalize(false);

def capitalize_all:
    capitalize(true);