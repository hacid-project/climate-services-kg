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
- **Standard names not in the CF table.** A variable is a specialization of
  the CF variable of its standard name (`data:isSpecializationOfVariable`)
  only if the name is in the CF standard name table of the KG (its entries and
  aliases, `data-sources/cf-standard-names/data/standard-names.json`), so that
  no link points to a CF variable that is not in the KG. The standard names of
  some editions are not in the table; those that are obvious typos or were
  renamed in later editions are corrected (`mapping/cf-standard-name-fixes.json`,
  with a note for each, `cf_standard_name`):

  | Variable | Standard name of the tables | CF standard name |
  | --- | --- | --- |
  | `fg14co2` (up to 6.0.15) | `air_sea_flux_of_14CO2` | `surface_downward_mass_flux_of_14C_dioxide_abiotic_analogue_expressed_as_carbon` |
  | `pod0` (6.2.24) | `integration_wrt_time_of_mole_stomatal_uptake_of_ozone` | `integral_wrt_time_of_mole_stomatal_uptake_of_ozone` |
  | `rootdsl` (6.2.24) | `root_mass_content` | `root_mass_content_of_carbon` |
  | `irrLut` (up to 6.1.23) | `surface_downward_water_flux_due_to_irrigation` | `surface_downward_mass_flux_of_water_due_to_irrigation` |
  | `fLulccAtmLut` (up to 6.1.23) | `..._direct_to_atmosphere_due_to_anthropogenic_land_use_land_cover_change` | `..._due_to_anthropogenic_land_use_or_land_cover_change_excluding_forestry_and_agricultural_products` |
  | `fProductDecompLut` (up to 6.1.23) | `tendency_of_atmospheric_..._from_wood_and_agricultural_product_pool` | `tendency_of_atmosphere_..._from_forestry_and_agricultural_products` |

  The others are not linked to a CF variable: `CO2_total_mass_in_atmos`
  (`co2totalmass`), `depth_of_frozen_soil` (`dfr`), `heat_content_of_ocean_layer`
  (`hcont300`), `integral_wrt_depth_of_product_of_sea_water_density_and_prognostic_temperature`
  (`tomint`), `strat_aerosol_optical_depth` (`od550aerstrat`), never CF names
  (up to version 95), and the placeholder `missing` (`nwdFracLut`). The same
  rule applies to the variables defined locally with `variables_jsonld`.
