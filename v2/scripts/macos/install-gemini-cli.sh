#!/usr/bin/env bash
set -euo pipefail

if ! command -v fnm >/dev/null 2>&1; then
  echo "fnm is required to install Gemini CLI. Install fnm and rerun." >&2
  exit 0
fi

eval "$(fnm env --use-on-cmd)"
fnm install --lts
fnm use lts-latest

echo "Installing Gemini CLI via npm (using fnm-managed Node)..." >&2
npm install -g @google/gemini-cli
echo "Gemini CLI installed." >&2
