"""Conversion of the CF standard name table from XML to JSON.

The elements become objects with a key for each child element (an array if
repeated, as entry and alias) followed by a key for each attribute (as id),
and the elements without children or attributes become their text (empty if
none), e.g.

    {"standard_name_table": {"version_number": "86", ...,
        "entry": [{"canonical_units": "1", "grib": "", "amip": "",
                   "description": "...", "id": "..."}, ...],
        "alias": [{"entry_id": "...", "id": "..."}, ...]}}

The attributes of the namespaces (xmlns, xsi) are left out.

Run by snakemake (rule cf_standard_names_json).
"""

import json
import xml.etree.ElementTree as ET


def element_json(element):
    attributes = {k: v for k, v in element.attrib.items() if not k.startswith("{")}
    if len(element) == 0 and not attributes:
        return element.text or ""
    children = {}
    for child in element:
        children.setdefault(child.tag, []).append(element_json(child))
    result = {tag: values[0] if len(values) == 1 else values for tag, values in children.items()}
    result.update(attributes)
    return result


def main(xml_path, json_path):
    root = ET.parse(xml_path).getroot()
    with open(json_path, "w") as f:
        json.dump({root.tag: element_json(root)}, f, ensure_ascii=False, indent="\t")
        f.write("\n")


if __name__ == "__main__":
    main(snakemake.input.xml, snakemake.output.json)  # noqa: F821
