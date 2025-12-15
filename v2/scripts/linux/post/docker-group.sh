#!/usr/bin/env bash
set -euo pipefail
if command -v usermod >/dev/null 2>&1; then
  sudo usermod -aG docker "${SUDO_USER:-$USER}"
fi
