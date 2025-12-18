#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO_ROOT/.venv"
PYPROJECT="$REPO_ROOT/pyproject.toml"

ensure_uv(){
  if command -v uv >/dev/null 2>&1; then
    return
  fi
  echo "Installing uv (Python package manager)..." >&2
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
}

create_venv(){
  if [[ -d "$VENV" ]]; then
    return
  fi
  uv venv "$VENV" >/dev/null 2>&1
}

install_deps(){
  "$VENV/bin/uv" pip install -e "$REPO_ROOT" >/dev/null 2>&1
}

run_app(){
  (cd "$REPO_ROOT" && "$VENV/bin/python" -m app.main "$@")
}

if [[ ! -f "$PYPROJECT" ]]; then
  echo "pyproject.toml not found at $PYPROJECT" >&2
  exit 1
fi

export PATH="$HOME/.local/bin:$PATH"
ensure_uv
create_venv
install_deps
run_app "$@"
