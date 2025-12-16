#!/usr/bin/env bash
set -euo pipefail

echo "Installing fnm via official install script..." >&2
curl -fsSL https://fnm.vercel.app/install | bash
echo "fnm installation completed." >&2
