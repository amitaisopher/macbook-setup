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

## How Windows Runner Works
1) Requires admin PowerShell, winget, and powershell-yaml (auto-installs powershell-yaml; choco as fallback).
2) Parses `manifest.yaml`.
3) For each tool with a `win` mapping:
   - Prefer `winget install --id ... --silent`  
   - Else `choco install -y ...`  
   - Else run a script (path relative to repo root)
   - Run any `post` scripts if provided
4) Continues past individual failures; reports via console.

Run on Windows:
```powershell
# In an elevated PowerShell
cd v2
./bootstrap.ps1
```

## How macOS/Linux Runners Work (current state)
The macOS/Linux runners are placeholders that delegate to the existing root `./bootstrap.sh` (Ansible-based). Future work: make them read `manifest.yaml` and install via brew/apt/scripts directly.

Run on macOS/Linux (current):
```bash
cd v2
./bootstrap.sh
```

## Extending
- Add tools / change versions: edit `manifest.yaml`.
- Add OS-specific scripts: place under `scripts/<os>/...` and reference in the manifest.
- Improve macOS/Linux runners: parse manifest and call brew/apt/scripts instead of delegating to Ansible.

## Notes
- Windows control plane is native PowerShell/winget (no Ansible on Windows).
- Ansible can still be used on macOS/Linux; the manifest remains the shared source of truth.
