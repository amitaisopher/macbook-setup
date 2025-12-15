#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${REPO_ROOT}/manifest.yaml"

ensure_python_yaml() {
  if python3 -c "import yaml" >/dev/null 2>&1; then
    return
  fi
  echo "Installing PyYAML for manifest parsing..." >&2
  python3 -m pip install --user pyyaml
}

parse_manifest() {
  python3 - <<'PY' "$MANIFEST"
import sys, yaml
path = sys.argv[1]
data = yaml.safe_load(open(path))
for name, tool in (data.get("tools") or {}).items():
    spec = tool.get("linux")
    if not spec: continue
    for kind, val in spec.items():
        if not val: continue
        # kind in {apt, script, post}
        if isinstance(val, list):
            for item in val:
                print(f"{name}\t{kind}\t{item}")
        else:
            print(f"{name}\t{kind}\t{val}")
PY
}

ensure_python_yaml
if [[ ! -f "$MANIFEST" ]]; then
  echo "Manifest not found at $MANIFEST" >&2
  exit 1
fi

APT_PACKAGES=()
SCRIPTS=()
while IFS=$'\t' read -r name kind value; do
  case "$kind" in
    apt) APT_PACKAGES+=("$value") ;;
    script) SCRIPTS+=("$value") ;;
    post) SCRIPTS+=("$value") ;;
    *) ;;
  esac
done < <(MANIFEST="$MANIFEST" parse_manifest)

if ((${#APT_PACKAGES[@]})); then
  echo "Updating apt cache and installing: ${APT_PACKAGES[*]}" >&2
  sudo apt-get update
  sudo apt-get install -y "${APT_PACKAGES[@]}"
fi

for script in "${SCRIPTS[@]:-}"; do
  script_path="${REPO_ROOT}/${script}"
  if [[ ! -f "$script_path" ]]; then
    echo "Script not found: $script_path" >&2
    continue
  fi
  echo "Running script: $script_path" >&2
  bash "$script_path"
done
