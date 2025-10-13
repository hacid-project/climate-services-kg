# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

[
    .[] |
    .BackwardDependency |= (select(length > 0) | split("\n") | .[] | trim | select(length > 0)) |
    .ForwardDependecy |= (select(length > 0) | split("\n") | .[] | trim | select(length > 0))
] 