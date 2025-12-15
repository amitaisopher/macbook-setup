#!/usr/bin/env bash
set -euo pipefail

echo "Installing Zoom (Linux) via vendor .deb..."
tmp="$(mktemp)"
cleanup(){ rm -f "$tmp"; }
trap cleanup EXIT

curl -fsSL "https://zoom.us/client/latest/zoom_amd64.deb" -o "$tmp"
sudo apt install -y "$tmp"

echo "Zoom installation complete."
