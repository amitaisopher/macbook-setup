#!/usr/bin/env bash
set -euo pipefail

echo "Installing uv (Python package manager) via official script..." >&2
curl -LsSf https://astral.sh/uv/install.sh | sh
echo "uv installation completed." >&2
