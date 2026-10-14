# Mapping of the variables of previous CMOR tables to the MIP variables

`mip-mapping.json` maps the variables defined in previous editions of the CMOR
tables (CMIP5 and CMIP6) to the variables of the last edition considered, the
last release of [mip-cmor-tables](https://github.com/PCMDI/mip-cmor-tables)
(CMIP6Plus). The KG has one variable per `out_name` of the last edition, plus
a separate variable for each previous variable that cannot be identified with
one of them.

`mip-variables.jq` implements this interpretation, giving the IRI of the
variable (see [Variable IRIs](#variable-iris)), and the workflow maps the
previous variables to the KG (see [Mapping to the KG](#mapping-to-the-kg)).

## Structure

The file is an array of **eras**, oldest first (currently `cmip5` and `cmip6`).
Each era describes the changes from its variables to those of the following
eras:

```json
[
    {
        "era": "cmip5",
        "keep": ["cfc11", ...],
        "rename": [{"for_tables": ["Omon", "Oyr", "Oclim"], "map": {"hfls": "hflso", ...}}, ...],
        "unit_change": [{"id": "thetao", "units": "K", "offset": -273.15}, ...]
    },
    {
        "era": "cmip6",
        "keep": {"6.0.12": ["albs", "od550aerstrat"], ...},
        "rename": [...],
        "sign_change": {"6.0.13": [{"id": "sistryubot", "quantity": "downward_y_stress_at_sea_ice_base"}]},
        "unit_change": {"6.0.13": [{"id": "tso", "units": "K", "offset": -273.15}], ...}
    }
]
```

All names (`id`, the keys and values of `map`) are `out_name`s, the
`variable_id` of the datasets, not the keys of the table entries.

### `keep`, `sign_change`, `unit_change`

Variables of the era that keep a separate identity, as they are not the same
variable as the one with the same name in the last edition:

- `keep`: the variable was deleted, or its meaning or its measurement
  specifications (e.g. units that cannot be converted) changed afterwards;
- `sign_change`: like `keep`, and the variable is the exact opposite of the
  current variable with the same name (e.g. a stress in the opposite
  direction);
- `unit_change`: like `keep`, and the variable is the same quantity as the
  current one in other units: `units` are the old units and the value in the
  current units is `value * factor + offset` (`factor` defaults to 1, `offset`
  to 0).

Each section is either a list (for an era with a single version, as `cmip5`)
or an object from a **version** of the CMOR tables of the era to a list. The
version is the last one in which the variable is defined with that meaning
and specifications, and it names the variable (see
[Variable IRIs](#variable-iris)). It is not used to match the variables: the
version of the CMOR tables is not known for a dataset, so an entry applies to
all the variables of its era (and of the previous eras) with its `id` and
conditions. An entry for a variable that still exists with the same name must
therefore have conditions that tell the old definition from the following
ones: its `quantity` or, if the quantity did not change, its `units`.

An entry is either an `out_name` or an object with:

- `id`: the `out_name`;
- `for_tables` (optional): the tables to which the entry applies;
- `dimensions` (optional): the dimensions of the variable to which the entry
  applies (the same set, in any order);
- `quantity` (optional): the CF standard name of the old variable. It
  distinguishes the old variable from the current one: the entry applies only
  if the quantity of the variable is known and the same. An old variable
  defined with different standard names has an entry for each;
- `units` (optional for `keep` and `sign_change`, required for
  `unit_change`): the units of the old variable, as written in the tables.
  The entry applies only if the units of the variable are known and the same;
- `new_quantity` (optional): the CF standard name to use for the variable,
  replacing the one in the tables;
- for `unit_change`: `factor`, `offset`, as above.

### `rename`

Groups of renames, from names of the era to the names they have in the next
era (or in the last edition, for the last era). A rename means that the two
names are the same variable (same quantity, units and specifications).

```json
{"for_tables": ["Amon"], "dimensions": ["longitude", "latitude", "plevs", "time2"], "map": {"tro3": "o3Clim", ...}}
```

`for_tables` and `dimensions` are optional and restrict the group as for the
entries above. The first group that applies to the variable and has its name
in `map` gives the new name.

## Resolution

A variable is described by its `out_name` and, when known, its era, its
table, its dimensions, its CF quantity and its units (as in the metadata of a
dataset).
It is resolved going through the eras, from its own era to the last one,
starting with its own name:

1. In the era, the `keep`, `sign_change` and `unit_change` entries are
   considered in order of version. The first entry matching the current name
   (and its conditions) gives the identity of the variable: the variable of
   that era and version. The resolution stops.
2. Otherwise, if a rename of the era applies, the current name becomes the
   new one.
3. Go on with the next era.

If no entry matches, the variable is the variable of the last edition with
the resulting name.

So the changes in an era apply to the variables of the previous eras too: a
CMIP5 `tos` in K is the CMIP6 `tos` up to 6.0.19 (`unit_change`), a CMIP6
`hus` in `Amon` on `plev19` is the MIP `hus19`, and so is a CMIP5 `hus` in
`Amon` on `plevs` (the 17 levels of `plevs` are the first 17 of `plev19`).

Notes:

- A condition (`for_tables`, `dimensions`, `quantity`, `units`) is satisfied
  only if the corresponding information on the variable is known and
  matches. In particular, a variable whose units are not known never
  resolves to a `unit_change` entry: e.g. a CMIP5 `tos` without units is the
  current `tos`, with units `K` it is the CMIP6 `tos` up to 6.0.19. Units are
  compared as strings, so they must be written as in the tables (e.g. `1e-9`,
  `mol m-2 s-1`).
- Without an era, the name is taken as the name of a variable of the last
  edition.

## Variable IRIs

- Variable of the last edition: `https://w3id.org/hacid/data/cs/variables/mip/<out_name>`
  (as in `variables.jq`), e.g. `.../variables/mip/hus19`;
- Variable of a previous era or version (resolved with a `keep`,
  `sign_change` or `unit_change` entry):
  `https://w3id.org/hacid/data/cs/variables/mip/<era>/<version>/<out_name>`,
  or `.../mip/<era>/<out_name>` if the era has no versions, e.g.
  `.../variables/mip/cmip6/6.0.19/tos`, `.../variables/mip/cmip5/tossq`.

`mip-variable-iri.jq` returns the IRI, from the repository root:

```bash
jq -L data-sources/cmor-tables/mapping -f data-sources/cmor-tables/mapping/mip-variable-iri.jq <<< '
    {"out_name": "hus", "era": "CMIP6", "table": "Amon", "dimensions": "longitude latitude plev19 time"}'
# "https://w3id.org/hacid/data/cs/variables/mip/hus19"
```

The input is an `out_name` or an object with `out_name` and, optionally,
`era`, `quantity`, `units`, `table` and `dimensions` (string or array). With
`--arg details true` it returns the whole resolution (resulting name, era,
version, kind and entry of the match, renames applied).

Other jq programs can use the module `mip-variables.jq`, which reads
`mip-mapping.json` from its own directory:

```jq
include "mip-variables";   # jq -L data-sources/cmor-tables/mapping
{"out_name": "tossq", "era": "cmip5"} | mip_variable_iri
# "https://w3id.org/hacid/data/cs/variables/mip/cmip5/tossq"
```

It defines `mip_variable_iri`, `mip_variable_resolution` (and the same with a
mapping as argument, e.g. `mip_variable_iri($mapping)`).

## Mapping to the KG

The snakemake rule `cmor_tables_mip` maps the MIP variables and the previous
variables:

```bash
snakemake --cores 4 cmor_tables_mip
```

The eras are configured in `config/cmor-tables-eras.json`: the repository of
the CMOR tables of each era, the edition of the eras without versions in the
mapping (`cmip5`) and of the current era, and the current era (`current`):

```json
{
    "eras": [
        {"era": "cmip5", "repo": "https://github.com/PCMDI/cmip5-cmor-tables.git", "edition": "5.0"},
        {"era": "cmip6", "repo": "https://github.com/PCMDI/cmip6-cmor-tables.git"},
        {"era": "cmip6plus", "repo": "https://github.com/PCMDI/mip-cmor-tables.git", "edition": "v6.5.0.4"}
    ],
    "current": "cmip6plus"
}
```

The repositories must be `https://github.com/PCMDI/<source>-cmor-tables`, as
the editions are retrieved by the rules of the other editions
(`data/<source>/<edition>.json`, reused if already there, e.g. after the
analysis).

1. `mip-editions.jq` computes from the configuration and the mapping the
   editions needed: the current one and those with `keep`, `sign_change` or
   `unit_change` entries, e.g.
   `{"current": "mip/v6.5.0.4", "previous": ["cmip5/5.0", "cmip6/6.0.12", ...]}`.
2. The current edition is mapped as any other edition by `variables.jq`
   (`rdf/mip/v6.5.0.4.jsonld`): one variable per `out_name`.
3. Each previous edition is mapped by `mip-previous-variables.jq`
   (`rdf/previous/<source>/<edition>.jsonld`) to the variables matched by
   the entries of that version (with the table, dimensions, standard name and
   units of the table entry for the conditions). They are mapped as the
   others, but with the IRI of a previous variable, a label naming the era
   and version (e.g. "Sea Surface Temperature (tos, CMIP6 6.0.19)") and the
   `new_quantity` of the entry, if any, as quantity. As for the current
   variables, the entries of the same `out_name` in different tables are
   mapped to the same variable.

The previous variables are exactly those the resolution can return.

## Maintenance

When a new edition is considered, the variables that are deleted or changed
in it are added to `keep` (or `sign_change`, `unit_change`) under the last
version in which they had the old definition (with the conditions that
identify the old definition, if the name is still in use), and the safe
renames to `rename`. The analysis in `../analysis` lists the deletions and changes of
the variables across the editions.
