# Patches to snakemake-storage-plugin-git 0.1.0:
# - support for a git ref (tag, branch or commit) as URL fragment, e.g.
#   https://github.com/PCMDI/cmip6-cmor-tables.git#6.9.33: each ref gets its
#   own checkout (in <host>+<path>@<ref>) of that ref (detached HEAD), while
#   the plugin alone would ignore the fragment;
# - the plugin clones (or fetches) a repository only in inventory(), which
#   snakemake runs just for the inputs of the target jobs, so a repository used
#   deeper in the DAG is reported as missing: clone (or fetch) it when its
#   existence is checked instead, as the plugin itself does in its unit tests
#   (once per run, see _clone_or_pull);
# - the plugin fetches each repository at every run (once per checkout, i.e.
#   per ref), even when nothing changed: a checkout whose ref is already there
#   as a tag or a commit id, which cannot move, is not fetched (a branch still
#   is, as is a ref not there yet).
import os
import re
from urllib.parse import urlparse

import pygit2
from snakemake_interface_common.exceptions import WorkflowError
from snakemake_storage_plugin_git import StorageObject as GitStorageObject

_git_local_suffix = GitStorageObject.local_suffix
_git_exists = GitStorageObject.exists
_git_clone_or_pull = GitStorageObject._clone_or_pull
_git_checked_out = set()


def _git_ref(storage_object):
    return urlparse(storage_object.query).fragment


def _git_local_suffix_with_ref(self):
    ref = _git_ref(self)
    return f"{_git_local_suffix(self)}@{ref}" if ref else _git_local_suffix(self)


def _git_checkout_ref(repo, ref):
    for revision in (f"refs/tags/{ref}", f"refs/remotes/origin/{ref}", ref):
        try:
            commit = repo.revparse_single(revision).peel(pygit2.Commit)
            break
        except (KeyError, ValueError, pygit2.GitError):
            continue
    else:
        raise WorkflowError(f"Git ref {ref} not found in {repo.path}")
    repo.checkout_tree(commit, strategy=pygit2.GIT_CHECKOUT_FORCE)
    repo.set_head(commit.id)


def _git_has_fixed_ref(local_path, ref):
    """Whether a checkout has a ref as a tag or a commit id (not a branch)."""
    try:
        repo = pygit2.Repository(local_path)
    except pygit2.GitError:
        return False
    if f"refs/tags/{ref}" in repo.references:
        return True
    if re.fullmatch(r"[0-9a-f]{7,40}", ref) and f"refs/remotes/origin/{ref}" not in repo.references:
        try:
            repo.revparse_single(ref).peel(pygit2.Commit)
            return True
        except (KeyError, ValueError, pygit2.GitError):
            return False
    return False


def _git_clone_or_pull_unless_fixed(self):
    ref = _git_ref(self)
    local_path = str(self.local_path())
    if (
        self.query not in self.provider.done_queries
        and ref
        and os.path.exists(local_path)
        and _git_has_fixed_ref(local_path, ref)
    ):
        self.provider.done_queries.add(self.query)
    _git_clone_or_pull(self)


def _git_clone_and_exists(self):
    self._clone_or_pull()
    local_path = str(self.local_path())
    ref = _git_ref(self)
    if ref and local_path not in _git_checked_out and os.path.exists(local_path):
        _git_checkout_ref(pygit2.Repository(local_path), ref)
        _git_checked_out.add(local_path)
    return _git_exists(self)


GitStorageObject.local_suffix = _git_local_suffix_with_ref
GitStorageObject.exists = _git_clone_and_exists
GitStorageObject._clone_or_pull = _git_clone_or_pull_unless_fixed
