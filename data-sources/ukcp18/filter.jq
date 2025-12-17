{
    exceptions: [
        .[] |
        select(.id) |
        (.id | split("_")) as $id_comps |
        select(
            $id_comps[0] != .variable
            and .variable != "ensemble_member"
            and .variable != "var__"
            and (.variable != "subsurface_runoff_flux" or $id_comps[0] != "mrrob") # (CF vs MIP)
            and (.variable != "air_pressure_at_sea_level" or $id_comps[0] != "psl") # (CF vs MIP)
            and (.variable != "air_temperature" or $id_comps[0] != "tasAnom") # (CF vs MIP)
            and (.variable != "vas" or $id_comps[0] != "uas") # !!!

            or $id_comps[1] != .scenario and $id_comps[1] != .collection
#            or $id_comps[2] != .collection

        )
    ] | .[0:100],
    example: {
        "id": "pr_rcp85_land-cpm_uk_5km_25_mon_198012-200011.nc",
        "variable": "pr",
        "variable_long_name": "Precipitation rate",
        "units": "mm/day",
        "collection": "land-cpm",
        "contact": "enquiries@metoffice.gov.uk",
        "creation_date": "2024-04-23-T00:00:00",
        "domain": "uk",
        "frequency": "mon",
        "institution": "Met Office Hadley Centre (MOHC), FitzRoy Road, Exeter, Devon, EX1 3PB, UK.",
        "institution_id": "MOHC",
        "project": "UKCP18",
        "references": "https://ukclimateprojections.metoffice.gov.uk",
        "resolution": "5km",
        "scenario": "rcp85",
        "source": "UKCP18 realisation from a set of 4 convection-permitting models (HadREM3-RA11M) driven by the Met Office Unified Model Global Atmosphere GA7 model (HadREM3-GA705) at 12km resolution.  The HadREM3-GA705 models were driven by global models from CMIP5.",
        "title": "UKCP18 land projections - Regridded 2.2km convection-permitting climate model results on 5km British National Grid from Ordnance Survey (OSGB), Precipitation rate over the UK for the RCP8.5 scenario",
        "version": "v20240423",
        "Conventions": "CF-1.7",
        "description": "Precipitation rate",
        "label_units": "mm/day",
        "plot_label": "Precipitation rate (mm/day)"
    }
}