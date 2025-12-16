#!/usr/bin/env bash
set -euo pipefail

echo "Installing Google Chrome (Linux) via vendor .deb..." >&2
tmp="$(mktemp)"
cleanup(){ rm -f "$tmp"; }
trap cleanup EXIT

curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$tmp"
sudo apt-get install -y "$tmp"

echo "Google Chrome installation complete." >&2
