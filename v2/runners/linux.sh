#!/usr/bin/env bash
set -euo pipefail

# Placeholder runner: integrate with manifest.yaml and call native package manager.
# For now, just delegate to existing Ansible flow if present.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v ansible-playbook >/dev/null 2>&1; then
  cd "$REPO_ROOT/.."
  exec ./bootstrap.sh "$@"
else
  echo "TODO: Implement manifest-driven Linux runner. For now, install Ansible and run the root bootstrap.sh." >&2
  exit 1
fi
