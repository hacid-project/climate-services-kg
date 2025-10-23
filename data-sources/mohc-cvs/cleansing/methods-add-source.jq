# Incomplete trim function, just good enough for current usage
def trim:
    ltrimstr(" ") | ltrimstr("\t") |  ltrimstr("\n") |
    rtrimstr(" ") | rtrimstr("\t") |  rtrimstr("\n");

def unpack_definition:
    [.Definition | match("\\n\\[[0-9]*\\]"; "g")] as $references |
    if ($references | length) > 0 then
        .Definition as $definition |
        .Definition |= .[:$references[0].offset] |
        .DefinitionSources = [
            range($references | length) |
            if . < ($references | length) - 1 then
                $definition[$references[.].offset + $references[.].length:$references[.+1].offset]
            else
                $definition[$references[.].offset + $references[.].length:]
            end
        ]
    else
        (.Definition | split("\n")) as $definition_rows |
        ([$definition_rows.[] | test("(http)|\\([12][0-9][0-9][0-9]\\)")] | rindex(false)) as $definition_end |
        if ($definition_end + 1) < ($definition_rows | length) then
            .Definition = ($definition_rows[:$definition_end + 1] | join("\n")) |
            .DefinitionSources = $definition_rows[$definition_end + 1:]
        end
    end |
    [.Definition | match(" \\(Wikidata: (Q[0-9]+)\\)")] as $wiki_ref_matches |
    if ($wiki_ref_matches | length) > 0 then
        .WikidataRefs = [$wiki_ref_matches[].captures[].string] |
        .Definition |= .[:$wiki_ref_matches[0].offset]
    end |
    .Definition |= trim |
    if .DefinitionSources then
        .DefinitionSources |= map(trim)
    end;

map(unpack_definition | .Methods |= map(unpack_definition))