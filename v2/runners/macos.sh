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

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  echo "Homebrew is required. Install from https://brew.sh" >&2
  exit 1
}

parse_manifest() {
  python3 - <<'PY' "$MANIFEST"
import sys, yaml
path = sys.argv[1]
data = yaml.safe_load(open(path))
for name, tool in (data.get("tools") or {}).items():
    spec = tool.get("mac")
    if not spec: continue
    for kind, val in spec.items():
        if not val: continue
        if isinstance(val, list):
            for item in val:
                print(f"{name}\t{kind}\t{item}")
        else:
            print(f"{name}\t{kind}\t{val}")
PY
}

ensure_python_yaml
ensure_brew
if [[ ! -f "$MANIFEST" ]]; then
  echo "Manifest not found at $MANIFEST" >&2
  exit 1
fi

BREW_PKGS=()
BREW_CASKS=()
SCRIPTS=()
while IFS=$'\t' read -r name kind value; do
  case "$kind" in
    brew) BREW_PKGS+=("$value") ;;
    brew_cask) BREW_CASKS+=("$value") ;;
    script) SCRIPTS+=("$value") ;;
    post) SCRIPTS+=("$value") ;;
    *) ;;
  esac
done < <(MANIFEST="$MANIFEST" parse_manifest)

if ((${#BREW_PKGS[@]})); then
  echo "Installing brew packages: ${BREW_PKGS[*]}" >&2
  brew install "${BREW_PKGS[@]}"
fi

if ((${#BREW_CASKS[@]})); then
  echo "Installing brew casks: ${BREW_CASKS[*]}" >&2
  brew install --cask "${BREW_CASKS[@]}"
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
