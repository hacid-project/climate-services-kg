"""Analysis of the evolution of the variable definitions in the CMOR tables.

Compares each edition with its predecessor (the latest of the configured
editions it descends from in git), the repositories with each other, and
looks for names used for different quantities. Outputs (see
data-sources/cmor-tables/analysis/README.md):

- release-steps.csv: added/deleted/modified entries for each edition
- deletions.csv: each deleted entry and what happened to it
- standard-name-changes.csv: each change of standard_name, classified
- same-name-different-quantity.csv: names used with different standard_names
- same-name-different-units.csv: names used with different units
- repository-transitions.csv: comparison between consecutive repositories
- summary.json: all the counts

An entry is a variable of a table (e.g. Amon.tas). Standard names are
compared through the CF standard name table (aliases resolved).

Run by snakemake (rule cmor_tables_analysis).
"""

import collections
import csv
import json
import os
import re
import xml.etree.ElementTree as ET

SEMANTIC = ["standard_name", "units", "dimensions", "cell_methods", "positive", "type", "frequency", "modeling_realm"]
DESCRIPTIVE = ["long_name", "comment"]
OTHER = ["cell_measures", "valid_min", "valid_max", "ok_min_mean_abs", "ok_max_mean_abs", "out_name"]
ATTRS = SEMANTIC + DESCRIPTIVE + OTHER


# --- Input


def norm(value):
    if value is None:
        return ""
    if isinstance(value, list):
        value = " ".join(str(x) for x in value)
    return re.sub(r"\s+", " ", str(value)).strip()


def load_tables(path):
    """{(table, key): {attr: value}} for the variable entries of an edition."""
    with open(path) as f:
        tables = json.load(f)
    entries = {}
    for t in tables:
        # (the formula terms of cmip6 6.0.11 are in a table without header)
        if "variable_entry" not in t or "Header" not in t:
            continue
        table = norm(t["Header"].get("table_id")).removeprefix("Table ").strip()
        # grid coordinates (latitude, vertices...), not data variables
        if table == "grids":
            continue
        for key, v in t["variable_entry"].items():
            e = {a: norm(v.get(a)) for a in ATTRS}
            e["frequency"] = e["frequency"] or norm(t["Header"].get("frequency"))
            e["out_name"] = e["out_name"] or key
            entries[(table, key)] = e
    return entries


class CF:
    """CF standard name table, with aliases."""

    def __init__(self, path):
        root = ET.parse(path).getroot()
        self.version = root.findtext("version_number")
        self.entries = {e.get("id") for e in root.iter("entry")}
        self.aliases = {a.get("id"): a.findtext("entry_id").strip() for a in root.iter("alias")}

    def canon(self, name):
        seen = set()
        while name in self.aliases and name not in seen:
            seen.add(name)
            name = self.aliases[name]
        return name

    def valid(self, name):
        return name in self.entries or name in self.aliases

    def classify_change(self, old, new):
        if not old or not new:
            return "set" if new else "unset"
        if self.canon(old) == self.canon(new):
            return "same quantity (CF alias)"
        if not self.valid(old):
            return "fix of name not in CF table"
        if not self.valid(new):
            return "to name not in CF table"
        if old.removeprefix("minus_") == new.removeprefix("minus_"):
            return "sign convention (minus_)"
        return "different CF quantity"

    def classify_names(self, names):
        """Classify a set of standard names used for the same variable name."""
        valid = {self.canon(n) for n in names if self.valid(n)}
        if len(valid) <= 1:
            return "naming fix only (name not in CF table replaced)"
        if len({v.removeprefix("minus_") for v in valid}) == 1:
            return "sign convention (minus_)"
        return "different CF quantities"


# --- Comparison


class Analysis:
    def __init__(self, editions, tables, infos, cf):
        self.editions = editions
        self.cf = cf
        self.data = {e: load_tables(p) for e, p in zip(editions, tables)}
        self.info = {}
        for e, p in zip(editions, infos):
            with open(p) as f:
                self.info[e] = json.load(f)
                self.info[e]["ancestors"] = set(self.info[e]["ancestors"])
        self.sources = list(dict.fromkeys(e.split("/")[0] for e in editions))
        self.by_source = {s: [e for e in editions if e.split("/")[0] == s] for s in self.sources}

    def descends(self, e, p):
        """Whether edition e descends from (or is the same commit of) edition p."""
        return self.info[p]["commit"] in self.info[e]["ancestors"]

    def predecessor(self, e):
        """Latest configured edition of the same source that e descends from."""
        eds = self.by_source[e.split("/")[0]]
        candidates = [
            p for p in eds
            if p != e and self.descends(e, p)
            and not (self.info[p]["commit"] == self.info[e]["commit"] and eds.index(p) > eds.index(e))
        ]
        return max(candidates, key=lambda p: (self.info[p]["date"], eds.index(p)), default=None)

    def trivial(self, attr, old, new):
        """Changes of conventions only, not of meaning."""
        if attr == "type" and {old, new} <= {"", "float", "real"}:
            return True
        if attr == "units" and {old, new} == {"1.0", "1"}:
            return True
        if attr in ("modeling_realm", "long_name") and old.lower() == new.lower():
            return True
        if attr == "standard_name" and self.cf.classify_change(old, new) == "same quantity (CF alias)":
            return True
        return False

    def changes(self, a, b):
        return {x: (a[x], b[x]) for x in ATTRS if a[x] != b[x] and not self.trivial(x, a[x], b[x])}

    def signature(self, e):
        return (self.cf.canon(e["standard_name"]), e["dimensions"], e["cell_methods"], e["frequency"])

    def deletion_fate(self, k, prev, cur):
        table, key = k
        a, b = self.data[prev], self.data[cur]
        elsewhere = [f"{t}.{kk}" for t, kk in b if kk == key]
        if elsewhere:
            return "still in other tables (same key)", elsewhere
        added = set(b) - set(a)
        same = [kk for kk in added if self.signature(b[kk]) == self.signature(a[k])]
        if [kk for kk in same if kk[0] == table]:
            return "renamed (same table, same definition)", [f"{t}.{kk}" for t, kk in same if t == table]
        if same:
            return "renamed and moved (same definition)", [f"{t}.{kk}" for t, kk in same]
        later = [e for e in self.by_source[cur.split("/")[0]] if e != cur and self.descends(e, cur) and k in self.data[e]]
        if later:
            return "removed, re-added later", sorted(later, key=lambda e: self.info[e]["date"])[:1]
        return "removed", []

    def steps(self):
        steps, deletions, sn_changes = [], [], []
        for cur in self.editions:
            prev = self.predecessor(cur)
            if prev is None:
                continue
            a, b = self.data[prev], self.data[cur]
            added, deleted, common = set(b) - set(a), set(a) - set(b), set(a) & set(b)
            raw = sum(1 for k in common if any(a[k][x] != b[k][x] for x in ATTRS))
            mods = {k: c for k in common if (c := self.changes(a[k], b[k]))}
            fates = collections.Counter()
            for k in sorted(deleted):
                fate, where = self.deletion_fate(k, prev, cur)
                fates[fate] += 1
                deletions.append(dict(previous=prev, edition=cur, entry=".".join(k), fate=fate,
                                      replaced_by_or_back_in=" ".join(where), standard_name=a[k]["standard_name"]))
            for k, c in sorted(mods.items()):
                if "standard_name" in c:
                    old, new = c["standard_name"]
                    sn_changes.append(dict(previous=prev, edition=cur, entry=".".join(k), old=old, new=new,
                                           kind=self.cf.classify_change(old, new)))
            keys_a, keys_b = {k for _, k in a}, {k for _, k in b}
            steps.append(dict(
                previous=prev, edition=cur, date=self.info[cur]["date"], commit=self.info[cur]["commit"][:10],
                entries=len(b), added=len(added), deleted=len(deleted),
                deleted_still_in_other_tables=fates["still in other tables (same key)"],
                deleted_renamed=fates["renamed (same table, same definition)"] + fates["renamed and moved (same definition)"],
                deleted_readded_later=fates["removed, re-added later"], deleted_removed=fates["removed"],
                modified_raw=raw, modified=len(mods),
                modified_semantic=sum(1 for c in mods.values() if set(c) & set(SEMANTIC)),
                names_added=len(keys_b - keys_a), names_deleted=len(keys_a - keys_b),
                modified_attributes="; ".join(f"{x}:{n}" for x, n in collections.Counter(
                    x for c in mods.values() for x in c).most_common()),
            ))
        return steps, deletions, sn_changes

    def last(self, source):
        """Latest edition of a source that no other edition descends from."""
        eds = self.by_source[source]
        tips = [e for e in eds if not any(o != e and self.descends(o, e) for o in eds)]
        return max(tips, key=lambda e: self.info[e]["date"])

    def first(self, source):
        return min(self.by_source[source], key=lambda e: self.info[e]["date"])

    def by_name(self, entries):
        out = collections.defaultdict(list)
        for (t, k), v in entries.items():
            out[k].append(v)
        return out

    def compare_names(self, a, b):
        na, nb = self.by_name(self.data[a]), self.by_name(self.data[b])
        common = set(na) & set(nb)
        quantities = lambda vs: {self.cf.canon(v["standard_name"]) for v in vs}
        units = lambda vs: {v["units"] for v in vs}
        return dict(
            entries_from=len(self.data[a]), entries_to=len(self.data[b]),
            names_from=len(na), names_to=len(nb), names_common=len(common),
            names_dropped=len(set(na) - set(nb)), names_new=len(set(nb) - set(na)),
            same_table_and_key=len(set(self.data[a]) & set(self.data[b])),
            common_names_no_shared_quantity=sorted(n for n in common if quantities(na[n]).isdisjoint(quantities(nb[n]))),
            common_names_no_shared_units=sorted(n for n in common if units(na[n]).isdisjoint(units(nb[n]))),
        )

    def compare_provenance(self, a, b):
        """Compare through the provenance of the entries of b (MIP_variables.json)."""
        prov = {(t, k): (pt, pk) for t, k, pt, pk in self.info[b]["provenance"]}
        da, db = self.data[a], self.data[b]
        mapped = {m: c for m, c in prov.items() if m in db and c in da}
        carried = set(mapped.values())
        changes = {m: self.changes(da[c], db[m]) for m, c in mapped.items()}
        not_carried = sorted(set(da) - carried)
        return dict(
            entries_from=len(da), entries_to=len(db), mapped=len(mapped),
            entries_to_without_provenance=sorted(f"{t}.{k}" for t, k in db if (t, k) not in prov),
            entries_from_not_carried=[
                dict(entry=f"{t}.{k}", same_key_in=sorted(f"{mt}.{mk}" for (mt, mk) in db if mk == k))
                for t, k in not_carried
            ],
            renamed_keys=sorted(f"{c[0]}.{c[1]} -> {m[0]}.{m[1]}" for m, c in mapped.items() if m[1] != c[1]),
            modified=sum(1 for c in changes.values() if c),
            modified_attributes=dict(collections.Counter(x for c in changes.values() for x in c).most_common()),
            standard_name_changes=dict(collections.Counter(
                self.cf.classify_change(*c["standard_name"]) for c in changes.values() if "standard_name" in c)),
        )

    def transitions(self):
        out = []
        for sa, sb in zip(self.sources, self.sources[1:]):
            a, first, last = self.last(sa), self.first(sb), self.last(sb)
            t = dict(source_from=sa, source_to=sb, edition_from=a, edition_to=first, by_name=self.compare_names(a, first))
            if last != first:
                t["by_name_to_last"] = dict(edition=last, **self.compare_names(a, last))
            if self.info[first]["provenance"] is not None:
                t["by_provenance"] = self.compare_provenance(a, first)
            out.append(t)
        return out

    def history(self):
        out = {}
        for source, eds in self.by_source.items():
            first, last = self.first(source), self.last(source)
            union = set().union(*(self.data[e] for e in eds))
            keys = lambda es: {k for e in es for _, k in self.data[e]}
            outs = lambda es: {v["out_name"] for e in es for v in self.data[e].values()}
            changed = set()
            by_attr = collections.Counter()
            for e in eds:
                p = self.predecessor(e)
                if p is None:
                    continue
                for k in set(self.data[p]) & set(self.data[e]):
                    for x in self.changes(self.data[p][k], self.data[e][k]):
                        if x in SEMANTIC:
                            changed.add(k)
                            by_attr[x] += 1
            out[source] = dict(
                first=first, last=last, editions=len(eds),
                entries_first=len(self.data[first]), entries_last=len(self.data[last]),
                entries_ever=len(union), entries_ever_not_in_last=len(union - set(self.data[last])),
                entries_first_not_in_last=len(set(self.data[first]) - set(self.data[last])),
                names_ever=len(keys(eds)), names_ever_not_in_last=sorted(keys(eds) - keys([last])),
                out_names_ever=len(outs(eds)), out_names_ever_not_in_last=len(outs(eds) - outs([last])),
                last_entries_with_semantic_change=len(changed & set(self.data[last])),
                semantic_changes_by_attribute=dict(by_attr.most_common()),
            )
        return out

    def homonyms(self, editions):
        """{out_name: {standard_name: [edition:table, ...]}} with more than one quantity."""
        q = collections.defaultdict(lambda: collections.defaultdict(set))
        for e in editions:
            for (t, k), v in self.data[e].items():
                q[v["out_name"]][v["standard_name"]].add((e, t))
        return {n: d for n, d in q.items() if len({self.cf.canon(s) for s in d}) > 1}

    def multiple_units(self, editions):
        u = collections.defaultdict(lambda: collections.defaultdict(set))
        for e in editions:
            for (t, k), v in self.data[e].items():
                u[v["out_name"]][v["units"]].add((e, t))
        return {n: d for n, d in u.items() if len(d) > 1 and set(d) != {"1", "1.0"}}

    def homonym_counts(self):
        per_edition = {e: len(self.homonyms([e])) for e in self.editions}
        scopes = {f"{s} (all editions)": eds for s, eds in self.by_source.items()}
        scopes["all repositories"] = self.editions
        per_scope = {
            name: dict(collections.Counter(self.cf.classify_names(d) for d in self.homonyms(eds).values()))
            for name, eds in scopes.items()
        }
        return per_edition, per_scope


# --- Output


def where(pairs, order):
    eds = sorted({e for e, _ in pairs}, key=order.index)
    tables = sorted({t for _, t in pairs})
    return f"{eds[0]} .. {eds[-1]}", len(eds), " ".join(tables)


def write_csv(path, rows, fields=None):
    fields = fields or (list(rows[0]) if rows else [])
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def main(editions, tables, infos, cf_table, out):
    cf = CF(cf_table)
    an = Analysis(editions, tables, infos, cf)
    steps, deletions, sn_changes = an.steps()
    transitions = an.transitions()
    history = an.history()
    per_edition, per_scope = an.homonym_counts()

    homonym_rows = []
    for n, d in sorted(an.homonyms(editions).items()):
        kind = cf.classify_names(d)
        for sn, pairs in sorted(d.items()):
            span, count, tabs = where(pairs, editions)
            homonym_rows.append(dict(out_name=n, kind=kind, standard_name=sn, in_cf_table=cf.valid(sn),
                                     editions=span, n_editions=count, tables=tabs))
    units_rows = []
    for n, d in sorted(an.multiple_units(editions).items()):
        for u, pairs in sorted(d.items()):
            span, count, tabs = where(pairs, editions)
            units_rows.append(dict(out_name=n, units=u, editions=span, n_editions=count, tables=tabs))
    transition_rows = []
    for t in transitions:
        for scope in ("by_name", "by_name_to_last", "by_provenance"):
            for metric, value in t.get(scope, {}).items():
                if isinstance(value, (list, dict)):
                    value = json.dumps(value)
                transition_rows.append(dict(source_from=t["source_from"], source_to=t["source_to"],
                                            edition_from=t["edition_from"],
                                            edition_to=t.get(scope, {}).get("edition", t["edition_to"]),
                                            comparison=scope, metric=metric, value=value))

    write_csv(out["steps"], steps)
    write_csv(out["deletions"], deletions, ["previous", "edition", "entry", "fate", "replaced_by_or_back_in", "standard_name"])
    write_csv(out["standard_name_changes"], sn_changes, ["previous", "edition", "entry", "old", "new", "kind"])
    write_csv(out["same_name_different_quantity"], homonym_rows,
              ["out_name", "kind", "standard_name", "in_cf_table", "editions", "n_editions", "tables"])
    write_csv(out["same_name_different_units"], units_rows, ["out_name", "units", "editions", "n_editions", "tables"])
    write_csv(out["repository_transitions"], transition_rows,
              ["source_from", "source_to", "edition_from", "edition_to", "comparison", "metric", "value"])
    summary = dict(
        cf_standard_name_table_version=cf.version,
        editions={e: dict(date=an.info[e]["date"], commit=an.info[e]["commit"], previous=an.predecessor(e))
                  for e in editions},
        deletion_fates=dict(collections.Counter(d["fate"] for d in deletions)),
        standard_name_change_kinds=dict(collections.Counter(c["kind"] for c in sn_changes)),
        history=history,
        transitions=transitions,
        homonyms_per_edition=per_edition,
        homonyms_by_kind=per_scope,
        names_with_multiple_units=len({r["out_name"] for r in units_rows}),
    )
    with open(out["summary"], "w") as f:
        json.dump(summary, f, indent=1)


if "snakemake" in globals():
    main(
        snakemake.params.editions,  # noqa: F821
        snakemake.input.tables,  # noqa: F821
        snakemake.input.info,  # noqa: F821
        snakemake.input.cf_table,  # noqa: F821
        snakemake.output,  # noqa: F821
    )
