#!/usr/bin/env bash
set -euo pipefail

release="v3.1.1"
fonts=(
  MartianMono
  DroidSansMono
)

tmpdir="$(mktemp -d)"
cleanup(){ rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "Installing Nerd Fonts (${fonts[*]}) from release ${release}..."

for font in "${fonts[@]}"; do
  zip="${font}.zip"
  url="https://github.com/ryanoasis/nerd-fonts/releases/download/${release}/${zip}"
  dest="${tmpdir}/${zip}"

  echo "Downloading ${font}..."
  curl -fsSL "$url" -o "$dest"

  echo "Extracting ${font}..."
  unzip -qq "$dest" -d "${tmpdir}/${font}"

  echo "Copying ${font} to /usr/local/share/fonts/nerd-fonts..."
  sudo mkdir -p /usr/local/share/fonts/nerd-fonts
  sudo find "${tmpdir}/${font}" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} /usr/local/share/fonts/nerd-fonts/ \;
done

echo "Refreshing font cache..."
sudo fc-cache -f

echo "Nerd Fonts installation complete."
