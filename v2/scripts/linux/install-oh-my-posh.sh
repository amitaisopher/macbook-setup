#!/usr/bin/env bash
set -euo pipefail

echo "Installing oh-my-posh via official script..."
curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "${HOME}/.local/bin"

echo "oh-my-posh installed to ${HOME}/.local/bin. Configure shells separately as needed."
