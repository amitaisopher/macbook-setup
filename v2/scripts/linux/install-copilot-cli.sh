#!/usr/bin/env bash
set -euo pipefail

if ! command -v fnm >/dev/null 2>&1; then
  echo "fnm is required to install GitHub Copilot CLI. Install fnm and rerun." >&2
  exit 0
fi

eval "$(fnm env --use-on-cd)"
fnm install --lts
fnm use lts-latest

echo "Installing GitHub Copilot CLI via npm (using fnm-managed Node)..." >&2
npm install -g @githubnext/github-copilot-cli
echo "GitHub Copilot CLI installed. Run 'github-copilot-cli auth' to authenticate." >&2
