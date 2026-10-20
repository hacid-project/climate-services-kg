"""Load of the graphs of the KG into a new TDB2 dataset.

The files of each graph are listed in graph_names.csv (path or glob pattern,
graph name, skip), relative to the root of the repository; those with skip
"y" are left out. The dataset (at its location) is recreated, and the files
of each graph are loaded with tdb2.tdbloader. A pattern that matches no file
is an error.

Writes a report of the graphs and their files (JSON). Run by snakemake (rule
consolidate_load).
"""

import csv
import glob
import json
import os
import shutil
import subprocess


def graph_files(graph_names):
    """{graph: [file, ...]} from graph_names.csv, in the order of the file."""
    graphs = {}
    with open(graph_names, newline="") as f:
        for row in csv.DictReader(f):
            if row["skip"].strip() == "y":
                continue
            files = sorted(glob.glob(row["path"]))
            if not files:
                raise ValueError(f"No file for {row['path']} (graph {row['graph-name']})")
            graphs.setdefault(row["graph-name"], []).extend(files)
    return graphs


def main(graph_names, location, jvm_args, report, log):
    graphs = graph_files(graph_names)
    shutil.rmtree(location, ignore_errors=True)
    env = dict(os.environ, JVM_ARGS=jvm_args)
    with open(log, "w") as log_file:
        for graph, files in graphs.items():
            print(f"Loading into {graph} files {' '.join(files)}", file=log_file, flush=True)
            subprocess.run(
                ["tdb2.tdbloader", "--loc", location, f"--graph={graph}", *files],
                check=True, env=env, stdout=log_file, stderr=subprocess.STDOUT,
            )
    with open(report, "w") as f:
        json.dump(graphs, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main(
        snakemake.input.graph_names,  # noqa: F821
        snakemake.params.location,  # noqa: F821
        snakemake.params.jvm_args,  # noqa: F821
        snakemake.output.report,  # noqa: F821
        snakemake.log[0],  # noqa: F821
    )
