#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log(){
  printf '%s\n' "$1"
}

required_ansible_version="2.14.0"

current_ansible_version(){
  ansible --version 2>/dev/null | head -n1 | awk '{print $2}'
}

ansible_meets_requirement(){
  current="$1"
  required="$2"
  if [[ -z "$current" ]]; then
    return 1
  fi
  # sort -V compares dotted versions; if required is not greater than current, we are good
  lowest="$(printf '%s\n%s\n' "$required" "$current" | sort -V | head -n1)"
  [[ "$lowest" == "$required" ]]
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
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$($(brew --prefix)/bin/brew shellenv)"' >> "$HOME/.bash_profile"
    eval "$($(brew --prefix)/bin/brew shellenv)"
  fi

  installed_version="$(current_ansible_version)"
  if ansible_meets_requirement "$installed_version" "$required_ansible_version"; then
    log "Ansible $installed_version already installed; skipping macOS install."
    return
  fi

  log "Installing/upgrading Ansible with Homebrew..."
  brew update
  brew install ansible || brew upgrade ansible
}

install_ansible_linux(){
  installed_version="$(current_ansible_version)"

  if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible

    if ansible_meets_requirement "$installed_version" "$required_ansible_version"; then
      log "Ansible $installed_version already installed; upgrading to latest from PPA..."
      sudo apt install -y ansible
      return
    fi

    log "Installing Ansible from PPA..."
    sudo apt update
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
log "Installing required Ansible collections..."
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory main.yml "$@"
