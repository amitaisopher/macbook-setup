#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log(){
  printf '%s\n' "$1"
}

install_ansible_macos(){
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$($(brew --prefix)/bin/brew shellenv)"' >> "$HOME/.bash_profile"
    eval "$($(brew --prefix)/bin/brew shellenv)"
  fi
  brew update
  brew install ansible
}

install_ansible_linux(){
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
