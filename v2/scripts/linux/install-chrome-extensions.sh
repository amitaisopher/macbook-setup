#!/usr/bin/env bash
set -euo pipefail

extensions=(
  "edacconmaakjimmfgnblocblbcdcpbko" # Session Buddy
  "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
  "gighmmpiobklfepjocnamgkkbiglidom" # AdBlock
)

policy_dir="/etc/opt/chrome/policies/managed"
policy_file="${policy_dir}/extensions.json"

sudo mkdir -p "$policy_dir"
sudo tee "$policy_file" >/dev/null <<EOF
{
  "ExtensionInstallForcelist": $(printf '%s\n' "${extensions[@]}" | jq -R . | jq -s .)
}
EOF

echo "Chrome extensions policy written to ${policy_file} (Session Buddy, Bitwarden, AdBlock)." >&2
