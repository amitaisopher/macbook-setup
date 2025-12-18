from __future__ import annotations

import sys
from pathlib import Path


def current_os_key() -> str:
    platform = sys.platform
    if platform.startswith("win"):
        return "win"
    if platform == "darwin":
        return "mac"
    return "linux"


def repo_root_from_manifest(manifest_path: Path) -> Path:
    return manifest_path.parent
