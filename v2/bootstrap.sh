#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin)
    exec "${REPO_ROOT}/runners/macos.sh" "$@"
    ;;
  Linux)
    exec "${REPO_ROOT}/runners/linux.sh" "$@"
    ;;
  *)
    echo "This entrypoint is for macOS/Linux. Use bootstrap.ps1 on Windows." >&2
    exit 1
    ;;
esac
