# w3id.org redirects

The KG moved from `https://w3id.org/hacid/data/cs/` to its own namespace, `https://w3id.org/climate-change-kg/`:

| | Old | New |
|:--|:--|:--|
| Resources and named graphs | `https://w3id.org/hacid/data/cs/...` | `https://w3id.org/climate-change-kg/data/...` |
| Root named graph | `https://w3id.org/hacid/data/cs` | `https://w3id.org/climate-change-kg/data` |
| Dataset (and metadata graph) | `https://w3id.org/hacid/data/cs/kg` | `https://w3id.org/climate-change-kg/data/kg` |
| SPARQL endpoint | `https://w3id.org/hacid/cs/sparql` | `https://w3id.org/climate-change-kg/sparql` |
| Website | `https://hacid-project.github.io/cckg/` | `https://w3id.org/climate-change-kg` |

The ontologies stay at `https://w3id.org/hacid/onto/{top-level,data,ccso}`.

The new identifier, `ids/climate-change-kg/` (resources to the linked data front end, the endpoint, anything else to
the website), is merged in [perma-id/w3id.org](https://github.com/perma-id/w3id.org). The redirect rules still to
submit are prepared in branches of the fork [miguel76/w3id.org](https://github.com/miguel76/w3id.org), one per pull
request:

1. `hacid-climate-services-to-climate-change-kg`: `/hacid/data/cs/...` redirects to `/climate-change-kg/data/...`; the
   other HACID redirects, `/hacid/cs/sparql` included, are unchanged (this branch has to be rebased on the updated
   `master` of the fork);
2. `climate-change-kg-shapes-redirects`: the redirects of the shapes, below.

The linked data front end and the SPARQL endpoint have to serve a build of the KG with the new IRIs for the new IRIs
to be described.

## Shapes

The SHACL shapes of the KG (`shapes/`) are published at `https://w3id.org/climate-change-kg/shapes` (the shapes are in
the namespace `https://w3id.org/climate-change-kg/shapes/`). The website workflow (`website/collect-shapes.sh`) copies
them, with the combined `shapes.ttl`, to the `shapes/` folder of the GitHub Pages site, next to the landing page
(`website/shapes.md`). The redirect rules, content negotiation between the Turtle file and the landing page, are in
the branch `climate-change-kg-shapes-redirects` of the fork (`ids/climate-change-kg/.htaccess`).
