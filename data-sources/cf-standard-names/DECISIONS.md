# CF standard names: decisions on issues and inconsistencies

Decisions taken in mapping the CF standard name table (version 86,
`data/cf-standard-name-table.xml`) to the KG, with the place where each one is
applied.

## Source data

- **Table.** The XML of the table is downloaded from cfconventions.org, in the
  version of `config/config.yaml`. The site is published from the GitHub
  repository `cf-convention/cf-convention.github.io`, which has the same file
  (checked for version 86): its URL can be configured instead
  (`cf_standard_names.url`), e.g. where cfconventions.org is not reachable.
- **Conversion to JSON.** The XML is converted by `xq` (of the Python package
  `yq`), a standard tool, with the conventions of xmltodict: attributes as keys
  prefixed by `@` (e.g. `@id`), the text of the elements without attributes as
  strings, empty elements as `null`, repeated elements as arrays (always for
  `entry` and `alias`, `--xml-force-list`). The JSON previously kept in the
  repository was made with a tool not recorded, with other conventions
  (attributes as plain keys, empty elements as empty strings).

## Variables (`mapping/standard-names.jq`)

- **Entries that are also aliases.** In version 86, two names are both an entry
  and an alias of another entry:

  | Name | Units | Alias of | Units |
  | --- | --- | --- | --- |
  | `convective_precipitation_rate` | `m s-1` | `lwe_convective_precipitation_rate` | `m s-1` |
  | `ocean_volume` | `m3` | `sea_water_volume` | `m3` |

  The entries are left out and the names kept only as aliases (mapped as the
  same as the entry they are aliases of), as done by hand in the previous JSON
  (commit 0b585c8): mapping both would make the same IRI a variable of its own
  and the same as (`owl:sameAs`) another one. The rule applies to any name that
  is both, in any version.
- **Missing values.** The entries without units (17, mostly of string-valued
  quantities, e.g. `region`, `platform_name`) have no units of measure, and those
  without a description (15) no comment, as in the former RML mapping. One of
  them, `volume_fraction_of_oxygen_in_sea_floor_sediment_pore_water`, is a
  volume fraction, so presumably `1`: left as in the table.
- **Class.** The variables are `data:DeterministicVariable`s, as those of the
  CMOR tables.

## Validation of the port from RML

The jq mapping reproduces the triples of the former RML mapping
(`rml/cf-standard-names.ttl`, on the CSV of the entries made by
`ws-data-rml.py`) as committed (`rdf/data.ttl`, 29,510 triples) and of the
former jq mapping of the aliases (`mapping/aliases.jq`, `rdf/aliases.jsonld`,
1,144 triples), now merged in the same mapping, but for the class of the variables, then
`data:Variable` (the RML mapping had been changed to
`data:DeterministicVariable` without regenerating the output).
