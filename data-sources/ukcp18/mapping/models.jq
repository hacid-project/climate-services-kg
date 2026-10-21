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
        {
            label: "HadREM3-GA705",
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
