#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
MIN_PYTHON_VERSION="3.9.0"

log(){
  printf '%s\n' "$1"
}

version_ge(){
  # Returns 0 if $1 >= $2 using natural sort
  local v1="$1" v2="$2"
  [[ "$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -n1)" == "$v2" ]]
}

ensure_user_bin_on_path(){
  local user_base="$("$PYTHON_BIN" -m site --user-base 2>/dev/null || true)"
  if [[ -n "$user_base" ]]; then
    export PATH="$user_base/bin:$PATH"
  fi
  # macOS default pip path
  export PATH="$HOME/Library/Python/3.9/bin:$PATH"
  export PATH="$HOME/.local/bin:$PATH"
}

install_homebrew(){
  if command -v brew >/dev/null 2>&1; then
    return
  fi
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
}

install_python_macos(){
  install_homebrew
  log "Installing python via Homebrew..."
  brew update
  brew install python@3.11 || brew upgrade python@3.11
  PYTHON_BIN="$(command -v python3)"
}

install_python_linux(){
  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y python3 python3-pip
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3 python3-pip
  else
    log "Unable to install Python automatically on this distribution. Please install Python $MIN_PYTHON_VERSION+ and rerun."
    exit 1
  fi
  PYTHON_BIN="$(command -v python3)"
}

ensure_python(){
  if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    local version
    version="$("$PYTHON_BIN" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null || echo "")"
    if [[ -z "$version" ]] || ! version_ge "$version" "$MIN_PYTHON_VERSION"; then
      log "Python $MIN_PYTHON_VERSION+ required; attempting to install/upgrade."
      case "$(uname -s)" in
        Darwin) install_python_macos ;;
        Linux) install_python_linux ;;
        *)
          log "Unsupported platform for automatic Python installation. Install Python $MIN_PYTHON_VERSION+ manually and rerun."
          exit 1
          ;;
      esac
    fi
  else
    log "python3 is not available; attempting to install."
    case "$(uname -s)" in
      Darwin) install_python_macos ;;
      Linux) install_python_linux ;;
      *)
        log "Unsupported platform for automatic Python installation. Install Python $MIN_PYTHON_VERSION+ manually and rerun."
        exit 1
        ;;
    esac
  fi
}

ensure_typer(){
  ensure_user_bin_on_path
  if "$PYTHON_BIN" -c "import typer" >/dev/null 2>&1; then
    return
  fi
  log "Installing 'typer' Python package..."
  if ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    log "pip not detected; bootstrapping with ensurepip..."
    "$PYTHON_BIN" -m ensurepip --upgrade
  fi
  "$PYTHON_BIN" -m pip install --user --upgrade pip
  "$PYTHON_BIN" -m pip install --user --upgrade typer
  hash -r 2>/dev/null || true
  if ! "$PYTHON_BIN" -c "import typer" >/dev/null 2>&1; then
    log "Failed to install typer. Please install it manually (pip install typer) and rerun."
    exit 1
  fi
}

ensure_python
ensure_typer

exec "$PYTHON_BIN" "${REPO_ROOT}/bootstrap.py" "$@"
