#!/usr/bin/env bash
#
# Extracts the CMOR tables of one edition (git ref) of a repository clone and
# writes them to stdout as a single JSON document:
#   {
#     "source": ..., "edition": ..., "repository": ..., "ref": ..., "commit": ...,
#     "tables": [{"file": "Tables/...", "Header": {...}, "variable_entry": {...}, ...}, ...]
#   }
# Only tables having some "*_entry" section are kept (so e.g. the CV is skipped).
#
# Usage: extract-cmor-tables.sh REPO_DIR REF FORMAT TABLES_GLOB CMOR2_PARSER SOURCE EDITION REPO_URL
#   FORMAT is "json" (CMOR 3) or "cmor2" (legacy plain text, parsed with CMOR2_PARSER)

set -euo pipefail

repo_dir=$1
ref=$2
format=$3
tables_glob=$4
cmor2_parser=$5
source_id=$6
edition=$7
repo_url=$8

commit=$(git -C "$repo_dir" rev-parse --verify --quiet "$ref^{commit}") || {
    echo "Ref '$ref' not found in $repo_url (fetched in $repo_dir)" >&2
    exit 1
}

table_to_json() {
    case "$format" in
        json) jq -c . ;;
        cmor2) jq -R -s -c -f "$cmor2_parser" ;;
        *) echo "Unknown table format: $format" >&2; exit 1 ;;
    esac
}

git -C "$repo_dir" ls-tree -r --name-only "$commit" -- "$(dirname "$tables_glob")" |
    while IFS= read -r file; do
        # shellcheck disable=SC2053 # glob matching is intended
        [[ $file == $tables_glob ]] || continue
        git -C "$repo_dir" show "$commit:$file" |
            table_to_json |
            jq -c --arg file "$file" 'select(keys | any(endswith("_entry"))) | {file: $file} + .'
    done |
    jq -s \
        --arg source "$source_id" \
        --arg edition "$edition" \
        --arg repository "$repo_url" \
        --arg ref "$ref" \
        --arg commit "$commit" \
        '{source: $source, edition: $edition, repository: $repository, ref: $ref, commit: $commit, tables: .}'
