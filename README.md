# macbook-setup

![macbook-setup logo](assets/logo.svg)

Automate the full bootstrap of a development workstation with a single Ansible playbook. The repository provisions macOS, Linux, and Windows hosts with the same core toolchain, copies opinionated configuration files (VS Code settings, oh-my-posh prompt), and installs all daily-driver apps with the native package managers for each platform.

## Goals
- **Max autonomy** – one `bootstrap` command installs Ansible (if needed) and runs the playbook locally.
- **Cross-platform parity** – common tooling lives in `roles/common`, OS-specific package management lives in `roles/{macos,linux,windows}`.
- **Idempotency & resiliency** – re-running the playbook is safe; missing apps are retried, and failures on optional casks/packages are reported without halting the run.
- **Easy maintenance** – software lists and configuration artifacts sit in predictable paths so you can edit them without reading Ansible internals.

## Toolchain Overview
- **Ansible** orchestrates everything in pull/local mode (`inventory` targets `localhost`).
- **Homebrew (macOS), apt + Snap (Linux), Chocolatey (Windows)** handle software installation.
- **VS Code** receives customized settings plus extension installs via CLI.
- **oh-my-posh** aligns shell prompts across PowerShell, bash, and zsh with `roles/common/files/oh-my-posh/theme.json`.

## Repository Layout
```
bootstrap.sh / bootstrap.ps1   # one-click entry points for macOS/Linux or Windows
main.yml                       # central play defining role order
inventory                      # local-only inventory
roles/
  common/                      # cross-OS config (directories, VS Code, shell theme)
  macos/                       # Homebrew formulas + casks + Nerd Fonts
  linux/                       # apt + Snap installs, CLI bootstrappers (uv, nvm, bun)
  windows/                     # Chocolatey installs + Nerd Font deployment
roles/common/files/vscode/*    # VS Code settings JSON
roles/common/files/oh-my-posh  # prompt theme
requirements.yml               # Ansible collections (community.general, community.windows, chocolatey)
```

## Included Software
All platforms aim to install the following (method varies by OS):
- Developer tooling: Git, AWS CLI/CDK, Docker Desktop/CLI, lazydocker, btop, uv, nvm, Bun, oh-my-posh.
- IDEs & editors: VS Code (with extensions), Cursor, WindSurf.
- Browsers: Google Chrome, Firefox, Zen Browser.
- Communication: Slack, WhatsApp, Discord, Rambox, Bitwarden, Claude Code, Google AntiGravity (placeholder), Google Antigravity is attempted via best-effort cask/Chocolatey install and may require manual handling.
- Desktop Apps: Github Desktop.
- Fonts: `MartianMono Nerd Font Mono` and `Droid Sans Mono`.

Some titles (e.g., Google AntiGravity or bleeding-edge IDEs) do not yet have stable packages in every ecosystem. The roles attempt installation and log any failures so you can patch the package source once official formulas/casks/packages appear.

## VS Code Profile
`roles/common/files/vscode/settings.json` contains opinionated defaults (format-on-save, Nerd Font usage, Ruff/Biome formatters, telemetry opt-out). Extensions installed via CLI include:
`biomejs.biome`, `charliermarsh.ruff`, `pyre-check.pyre-check` (PyreFly), `oderwat.indent-rainbow`, `prisma.prisma`, `shd101wyy.markdown-preview-enhanced`, `dsznajder.es7-react-js-snippets`, `ms-vscode-remote.remote-containers`, `ms-vscode.remote-explorer`, `ms-vscode.remote-server`, `github.copilot`, `github.copilot-chat`, `openai.openai-codex`, `figma.figma-vscode`, `bradlc.vscode-tailwindcss`, `amazonwebservices.aws-toolkit-vscode`, `ms-vscode.powershell`, `dbaeumer.vscode-eslint`, `astral-sh.pyright`, `ms-azuretools.vscode-docker`, `anthropic.claude-dev`, `shyykoserhiy.aws-cdk-tools`, `ms-toolsai.datawrangler`, `esbenp.prettier-vscode`.

## Chrome Extensions
The playbook automatically installs and enforces the following Chrome extensions via policy:
- **Session Buddy**
- **Bitwarden**
- **AdBlock**

## Automatic Updates
The system is configured to run automatic updates every **Saturday at 20:00**:
- **macOS**: Updates Homebrew packages and runs `softwareupdate -ia` for system updates.
- **Linux**: Updates `apt` and `snap` packages.
- **Windows**: Updates Chocolatey packages and triggers Windows Update via `UsoClient`.

If the `code` CLI is not yet on `PATH`, the playbook prints a reminder to run “Shell Command: Install 'code' command in PATH” inside VS Code and rerun the play.

## Customization Guide
1. **Software lists**
   - macOS: edit `roles/macos/vars/main.yml` (`homebrew_packages`, `homebrew_casks`, `nerd_fonts`).
   - Linux: edit `roles/linux/vars/main.yml` (`apt_packages`) or extend `roles/linux/tasks/apt.yml` for other package managers.
   - Windows: edit `roles/windows/vars/main.yml` to adjust Chocolatey packages and Nerd Font archives.
2. **Config files**
   - VS Code settings live in `roles/common/files/vscode/settings.json`.
   - Shell prompt theme lives in `roles/common/files/oh-my-posh/theme.json` (shared by bash/zsh/PowerShell).
3. **Extensions & plugins** – tweak the `vscode_extensions` list in `roles/common/vars/main.yml`.
4. **Secret material** – store tokens/SSH keys outside the repo or encrypt them with `ansible-vault` before referencing them from tasks.

## Running the Playbook
### macOS / Linux
```bash
./bootstrap.sh --ask-become-pass
```
The script installs Homebrew/Ansible if missing, installs the required Ansible collections, and runs `ansible-playbook -i inventory main.yml`. Use `-t macos` / `-t common` tags if you want to scope a rerun.

### Windows (PowerShell)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
./bootstrap.ps1 -ExtraArgs "--tags" "windows,common"
```
`bootstrap.ps1` ensures Chocolatey + Ansible are available, installs the collections, and invokes the same playbook.

## Troubleshooting
- Optional/beta apps without official packages (e.g., Google AntiGravity, WindSurf) are installed in a best-effort block. Check the Ansible output for the warning list and update the cask/package names as soon as upstreams publish them.
- VS Code extensions require the CLI. If skipped, enable the `code` command (macOS: VS Code menu → Install 'code' command in PATH; Windows: reinstall with CLI option) and rerun the `common` role.
- For Docker on Linux, log out or run `newgrp docker` after the play so group membership takes effect.

## Next Steps
- Add more OS-specific roles (`roles/linux/tasks/yum.yml`, etc.) if you need Fedora/Arch support.
- Expand `roles/common` with additional dotfiles (gitconfig, tmux.conf, etc.).
- Wire Ansible Vault for API keys or connect to a password manager CLI (1Password, Bitwarden CLI) for secret material.
