#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log(){
  printf '%s\n' "$1"
}

print_intro(){
  cat <<'EOF'
MacBook setup bootstrap
-----------------------
This script installs Ansible (if missing) and then runs the local playbook to
configure your machine. It is safe to rerun; installed dependencies will be
skipped.

What will happen:
- Detect your platform (macOS or Linux)
- Install prerequisites for Ansible only if they are not already present
- Run ansible-galaxy to make sure required collections are available
- Execute the main playbook (main.yml)

Usage:
  ./bootstrap.sh [ansible-playbook args...]

Examples:
  ./bootstrap.sh --check   # dry-run
  ./bootstrap.sh --tags homebrew
EOF
}

install_ansible_macos(){
  if command -v ansible >/dev/null 2>&1; then
    log "Ansible already installed; skipping macOS install."
    return
  fi

  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$($(brew --prefix)/bin/brew shellenv)"' >> "$HOME/.bash_profile"
    eval "$($(brew --prefix)/bin/brew shellenv)"
  fi

  log "Installing Ansible with Homebrew..."
  brew update
  brew install ansible
}

install_ansible_linux(){
  if command -v ansible >/dev/null 2>&1; then
    log "Ansible already installed; skipping Linux install."
    return
  fi

  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt install -y ansible
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y ansible
  else
    log "Please install Ansible manually for this distribution."
    exit 1
  fi
}

print_intro

case "$(uname -s)" in
  Darwin) install_ansible_macos ;;
  Linux) install_ansible_linux ;;
  *)
    log "bootstrap.sh is intended for macOS or Linux. Use bootstrap.ps1 on Windows."
    exit 1
    ;;
esac

cd "$REPO_ROOT"
ansible-galaxy collection install -r requirements.yml >/dev/null 2>&1 || true
ansible-playbook -i inventory main.yml "$@"
