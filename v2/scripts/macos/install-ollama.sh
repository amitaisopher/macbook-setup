#!/usr/bin/env bash
set -euo pipefail

echo "Installing Ollama on macOS via official installer..." >&2
if command -v brew >/dev/null 2>&1; then
  brew install --cask ollama
else
  echo "Homebrew not found; install from https://ollama.com/download/mac" >&2
  exit 1
fi
echo "Ollama installation completed." >&2
