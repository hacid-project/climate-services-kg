# The models of the Met Office Hadley Centre used by the UKCP18 datasets, as
# JSON-LD (no input)

import "./mapping/context" as CONTEXT;

{
    "@context": CONTEXT::context,
    "@graph": [
        {
            label: "HadGEM3-GC3.05",
            "@type": "ccso:GlobalClimateModel"
        },
        # HadREM3-GA705 in the UKCP18 metadata: the model of CORDEX-CMIP5
        # (MOHC-HadREM3-GA7-05), under its CORDEX name (the synonym in
        # data/cmip5-model-synonyms.json)
        {
            label: "HadREM3-GA7-05",
            comment: "Met Office Hadley Centre regional climate model HadREM3 with the Global Atmosphere 7.05 configuration (HadREM3-GA705 in UKCP18)",
            "@type": "ccso:RegionalClimateModel"
        },
        {
            label: "HadREM3-RA11M",
            "@type": "ccso:ConvectionPermittingClimateModel"
        } |
        ."@id" = @uri "https://w3id.org/hacid/data/cs/models/\(.label)" |
        .maintained_by =  "https://w3id.org/hacid/data/cs/organizations/MOHC"
    ]
}
