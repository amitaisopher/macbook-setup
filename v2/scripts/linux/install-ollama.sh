#!/usr/bin/env bash
set -euo pipefail

echo "Installing Ollama on Linux via official script..." >&2
curl -fsSL https://ollama.com/install.sh | sh
echo "Ollama installation completed." >&2
