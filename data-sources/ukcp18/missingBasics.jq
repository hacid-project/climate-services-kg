[
    .[] |
    select((.id and .collection) | not)
] | .[0:100]
