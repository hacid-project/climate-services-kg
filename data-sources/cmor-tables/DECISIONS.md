# CMOR tables: decisions on issues and conflicting versions

Decisions taken in mapping the variable definitions of the CMOR tables to the
KG, with the place where each one is applied.

## Conflicting versions of the variables

The editions of the CMOR tables (CMIP5, CMIP6, CMIP6Plus) define variables
with the same name differently (other units, sign, quantity, dimensions), and
the same variable with different names. The interpretation is documented in
detail in `mapping/mip-mapping.md`:

- the KG has one **MIP variable** per `out_name` of the current edition (the
  last release of mip-cmor-tables, CMIP6Plus);
- a variable of a previous edition that is not the same as the MIP variable
  with its name keeps a separate identity as a **previous variable**,
  `.../variables/mip/<era>/<version>/<out_name>` (`keep`, `sign_change`,
  `unit_change` in `mapping/mip-mapping.json`), linked to the variables that
  follow it by `data:hasOppositeValueOf` (sign change) or
  `data:isLinearTransformationOf` (unit change; the factor and offset are not
  represented);
- the renames of the eras identify variables with different names
  (`rename`);
- the variables of the datasets of all the sources are resolved with these
  rules (`mapping/mip-variables.jq`).

The evolution of the definitions across all the editions is analysed in
`analysis/` (see its README).

## Editions

- Only the editions needed by the KG are retrieved and mapped: the current
  one and those of the previous variables (`mapping/mip-editions.jq`); the
  analysis uses all the editions in `config/config.yaml`.
- The editions are identified as `<era>/<version>` (e.g. `cmip6/6.0.19`), also
  in the paths and IRIs, not by the repositories of the tables.
- The legacy plain-text CMOR 2 tables of CMIP5 are converted to JSON
  (`mapping/cmor2-tables.jq`).

## Variables (`mapping/variables-jsonld.jq`)

- The variables are `data:DeterministicVariable`s.
- A variable in several realms (e.g. `atmos atmosChem`) is a member of each of
  them, instead of a single realm named after the whole string (as in the
  former RML mapping).
- The dimensions are mapped to the dimensional spaces of
  `data-sources/common-spacetime.ttl` (`_dimension_map`), including the rotated
  longitude `rlon` of the CORDEX tables (as `longitude`).
- The same mapping (`variables_jsonld`, with the collection as parameter) is
  used for the variables defined locally from tables in the same format (the
  CORDEX standard output, see `data-sources/cordex-cmip5/DECISIONS.md`).
