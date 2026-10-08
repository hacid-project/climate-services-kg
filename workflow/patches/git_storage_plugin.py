# Workarounds for snakemake-storage-plugin-git 0.1.0:
# - it clones (or fetches) a repository only in inventory(), which snakemake
#   runs just for the inputs of the target jobs, so a repository used deeper in
#   the DAG is reported as missing: clone (or fetch) it when its existence is
#   checked instead, as the plugin itself does in its unit tests (once per run,
#   see _clone_or_pull);
# - it checks out the custom head (setting custom_heads) only after a fetch,
#   not after the first clone: check it out in both cases.
import os

import pygit2
from snakemake_storage_plugin_git import StorageObject as GitStorageObject

_git_storage_object_exists = GitStorageObject.exists
_git_checked_out = set()


def _git_storage_object_clone_and_exists(self):
    self._clone_or_pull()
    local_path = str(self.local_path())
    if local_path not in _git_checked_out and os.path.exists(local_path):
        self._checkout_custom_head(pygit2.Repository(local_path))
        _git_checked_out.add(local_path)
    return _git_storage_object_exists(self)


GitStorageObject.exists = _git_storage_object_clone_and_exists
