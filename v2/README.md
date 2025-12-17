# v2 Bootstrap (Manifest-Driven)

This v2 scaffold separates **what** to install from **how** to install it. A single manifest defines the toolset; thin OS runners translate the manifest into native installs.

## Core Principles
- **Single source of truth**: `manifest.yaml` lists all tools, versions, and per-OS mappings.
- **OS-specific runners**: PowerShell on Windows, shell on macOS/Linux. They read the same manifest.
- **Native installers**: winget/choco/scripts on Windows; (future) brew/apt/scripts on macOS/Linux.
- **Minimal duplication**: Add/remove/change tools in one place (the manifest).

## Layout
```
v2/
  manifest.yaml          # tools + per-OS install mapping
  bootstrap.ps1          # Windows entrypoint (delegates to runners/windows.ps1)
  bootstrap.sh           # macOS/Linux entrypoint (delegates to runners/{macos,linux}.sh)
  runners/
    windows.ps1          # parses manifest, installs via winget/choco/scripts
    macos.sh             # placeholder (currently delegates to root Ansible)
    linux.sh             # placeholder (currently delegates to root Ansible)
  scripts/
    windows/
      install-nerd-fonts.ps1
    linux/
      install-nerd-fonts.sh
      post/docker-group.sh
```

## Manifest (`manifest.yaml`)
Example (truncated):
```yaml
tools:
  git:
    version: latest
    win:   { winget: "Git.Git" }
    mac:   { brew: "git" }
    linux: { apt: "git" }

  nerd_fonts:
    version: latest
    win:   { script: "scripts/windows/install-nerd-fonts.ps1" }
    mac:   { brew: "font-hack-nerd-font" }
    linux: { script: "scripts/linux/install-nerd-fonts.sh" }
```

Keys per OS:
- `winget`, `choco`, `brew`, `brew_cask`, `apt`, `script`
- Optional `post`: array of scripts to run after install (e.g., docker group).

## Windows Flow
### Prereqs
- Run PowerShell **as Administrator**.
- Allow script execution: `Set-ExecutionPolicy Bypass -Scope Process -Force`.
- A reboot may be required if Chocolatey or other components request it.

### What runs (Windows)
- `bootstrap.ps1` parses `manifest.yaml` and installs each `win` tool via Chocolatey (preferred), winget, or script, plus any `post` hooks.
- Examples of installed software (per manifest at time of writing): git, VS Code, Docker Desktop, nerd fonts (DroidSansMono), Chrome, Zoom, uv, fnm, Cursor, Bitwarden, oh-my-posh, Ollama, Gemini CLI, Claude Code CLI, Copilot CLI, Chrome extensions (Session Buddy, Bitwarden, AdBlock), terminal appearance, fnm profile init, etc.
- Windows font install and terminal appearance are separate steps: `nerd_fonts` installs the font; `terminal_appearance` and `configure-fnm-profile` scripts adjust Windows Terminal/PowerShell as defined.

### Run
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd v2
./bootstrap.ps1
# If prompted for reboot by Chocolatey/Windows, reboot and rerun ./bootstrap.ps1
```

## How macOS/Linux Runners Work (current state)
The macOS/Linux runners are placeholders that delegate to the existing root `./bootstrap.sh` (Ansible-based). Future work: make them read `manifest.yaml` and install via brew/apt/scripts directly.

Run on macOS/Linux (current):
```bash
cd v2
./bootstrap.sh
```

## Extending (add your own software)
- Edit `manifest.yaml`: add a tool entry with per-OS mappings (`choco`/`winget`/`brew`/`apt`/`script`, optional `post`).
- If using `script`, add the script under `scripts/<os>/...` and reference it in the manifest.
- Keep Windows-only behaviors (terminal appearance, fnm profile) in dedicated scripts to avoid mixing concerns.

## Notes
- Windows control plane is native PowerShell/winget (no Ansible on Windows).
- Ansible can still be used on macOS/Linux; the manifest remains the shared source of truth.
