# Mapping of the CORDEX-CMIP5 domains and grids (data/CORDEX-CMIP5.json, the
# rotated and regular grids of the domain tables of WCRP-CORDEX, merged) to
# JSON-LD: for each grid (CORDEX_domain, e.g. EUR-11 or EUR-44i) its
# dimensional space, part of the domain (area_id, e.g. EUR), with its
# discretization (the resolution), its bounding region and its specialization
# (to the region), and the rotated dimensional spaces (by their pole) of the
# rotated grids.

def cs: "https://w3id.org/hacid/data/cs/";
def geodetic: cs + "dimensions/geodetic";
def wgs84: geodetic + "/reference-frames/WGS84";
def float: {"@value": ., "@type": "xsd:float"};
def wkt: {"@value": ., "@type": "geo:wktLiteral"};

def rotated_space: "\(geodetic)/reference-frames/rotated-WGS84/\(.pollon),\(.pollat)";
def pole: "\(wgs84)/points/\(.pollon),\(.pollat)";
def rectangle: "\(.ll_lon),\(.ll_lat):\(.ur_lon),\(.ur_lat)";
def polygon: "POLYGON((\(.ll_lon) \(.ll_lat),\(.ll_lon) \(.ur_lat),\(.ur_lon) \(.ur_lat),\(.ur_lon) \(.ll_lat)))";
def coordinates: "\(.ll_lon)° \(.ll_lat)°";
def region:
    if .type == "rotated"
    then "\(rotated_space)/regions/rectangle/\(rectangle)"
    else "\(wgs84)/regions/rectangle/\(rectangle)"
    end;
def quantization: "\(geodetic)/quantizations/regular-angle/\(.dlon)";
def grid: "\(cs)cordex/grids/\(.CORDEX_domain)";
def domain: "\(cs)cordex/domains/\(.area_id)";

. as $grids |
{
    "@context": {
        rdfs: "http://www.w3.org/2000/01/rdf-schema#",
        xsd: "http://www.w3.org/2001/XMLSchema#",
        geo: "http://www.opengis.net/ont/geosparql#",
        top: "https://w3id.org/hacid/onto/top-level/",
        data: "https://w3id.org/hacid/onto/data/",
        label: {"@id": "rdfs:label", "@language": "en"},
        comment: {"@id": "rdfs:comment", "@language": "en"},
        asWKT: "geo:asWKT",
        isMemberOf: {"@id": "top:isMemberOf", "@type": "@id"},
        isConstituentOf: {"@id": "top:isConstituentOf", "@type": "@id"},
        basedOnDimensionalSpace: {"@id": "data:basedOnDimensionalSpace", "@type": "@id"},
        adoptsQuantization: {"@id": "data:adoptsQuantization", "@type": "@id"},
        hasExactBoundingRegion: {"@id": "data:hasExactBoundingRegion", "@type": "@id"},
        hasSelectedRegion: {"@id": "data:hasSelectedRegion", "@type": "@id"},
        isSpecializationOn: {"@id": "data:isSpecializationOn", "@type": "@id"},
        hasReferencePoint: {"@id": "data:hasReferencePoint", "@type": "@id"},
        isPointOf: {"@id": "data:isPointOf", "@type": "@id"},
        isRegionOf: {"@id": "data:isRegionOf", "@type": "@id"},
        hasResolutionValue: "data:hasResolutionValue"
    },
    "@graph": ([
        $grids[] |
        # Domain
        {
            "@id": domain,
            "@type": "top:Concept",
            isMemberOf: "\(cs)cordex/domains",
            label: "CORDEX:\(.area_id)",
            comment: "CORDEX geographic domain for \(.domain) (\(.area_id))."
        },
        # Grid
        {
            "@id": "\(grid)/ds",
            "@type": "data:DimensionalSpace",
            isConstituentOf: domain,
            label: "CORDEX:\(.CORDEX_domain)",
            comment: "CORDEX geographic grid for \(.area_id), with \(.type) coordinates and a resolution of \(.dlon)° degrees (\(.CORDEX_domain)).",
            basedOnDimensionalSpace: (if .type == "rotated" then rotated_space else wgs84 end),
            adoptsQuantization: quantization,
            hasExactBoundingRegion: region
        },
        {
            "@id": "\(grid)/specialization",
            "@type": "data:VariableSpecialization",
            isSpecializationOn: geodetic,
            hasSelectedRegion: region
        },
        # Discretization
        {
            "@id": quantization,
            "@type": "data:SimpleRegularBinning",
            basedOnDimensionalSpace: geodetic,
            hasResolutionValue: (.dlon | float),
            label: "\(.dlon)° geodetic grid",
            comment: "Geodetic grid composed of regions encompassing \(.dlon) degrees on both angular axes."
        },
        # Bounding region
        if .type == "rotated" then
            {
                "@id": region,
                "@type": "data:GeodeticRegion",
                isRegionOf: rotated_space,
                label: "Rectangular geodetic region \(coordinates) : \(.ur_lon)° \(.ur_lat)° on rotated coordinates (pole: \(.pollon)° \(.pollat)°)",
                comment: "Rectangular geodetic region comprised between lower left coordinates \(coordinates) and upper right coordinates \(.ur_lon)° \(.ur_lat)°, based on rotated coordinates from WGS84 (pole has coordinates \(.pollon)° \(.pollat)°).",
                asWKT: ("SRID=ROTATED_POLAR:\(.pollon) \(.pollat);\(polygon)" | wkt)
            },
            # Rotated dimensional space
            {
                "@id": rotated_space,
                "@type": "data:Continuum",
                basedOnDimensionalSpace: wgs84,
                hasReferencePoint: pole,
                label: "Rotated geodetic: pole \(.pollon)° \(.pollat)°",
                comment: "Rotated geodetic dimensional space, with polar coordinates \(.pollon)° \(.pollat)°, in reference to the World Geodetic System 1984 (WGS84)."
            },
            {
                "@id": pole,
                "@type": "data:GeodeticPoint",
                isPointOf: wgs84,
                label: "Geodetic point \(.pollon)° \(.pollat)°",
                comment: "Geodetic point with longitude \(.pollon)° and latitude \(.pollat)°, in reference to the World Geodetic System 1984 (WGS84).",
                asWKT: ("POINT(\(.pollon) \(.pollat))" | wkt)
            }
        else
            {
                "@id": region,
                "@type": "data:GeodeticRegion",
                isRegionOf: wgs84,
                label: "Rectangular geodetic region \(coordinates) : \(.ur_lon)° \(.ur_lat)°",
                comment: "Rectangular geodetic region comprised between lower left coordinates \(coordinates) and upper right coordinates \(.ur_lon)° \(.ur_lat)°, based on WGS84.",
                asWKT: (polygon | wkt)
            }
        end
    ] | unique)
}
