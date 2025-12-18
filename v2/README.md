# v2 — Manifest‑Driven, Typer‑Powered Bootstrap

This version builds a single, OS‑agnostic installer that reads **one manifest** and executes it with native package managers. A Typer CLI gives consistent UX across Windows, macOS, and Linux.

## What’s Inside
- **Single source of truth:** `manifest.yaml` lists every tool, its version, dependencies, per‑OS install method, and whether failure should abort.
- **Typer CLI:** `app/main.py` (`python -m app.main install …`) with rich tables, dependency graph, dry‑run, and logging.
- **Runners:** Thin launchers per OS that bootstrap Python/uv/venv, then delegate to the Typer app.
  - Windows: `bootstrap.ps1` → `runners/windows.ps1`
  - macOS/Linux: `bootstrap.sh` → `runners/{macos,linux}.sh`
- **Scripts:** Any custom install/post steps live under `scripts/<os>/…`.

## Quick Start
```powershell
# Windows (PowerShell as Administrator)
Set-ExecutionPolicy Bypass -Scope Process -Force
cd v2
.\bootstrap.ps1 -- --help
```
```bash
# macOS / Linux
cd v2
./bootstrap.sh -- --help
```

Pass any Typer flags after `--` so the runner forwards them to the app.

## Typer CLI (core flags)
- `--manifest-file PATH` – use a different manifest (default: `manifest.yaml`)
- `--dry-run` – print the plan without installing
- `--log-file PATH` – write logs to a custom path (default: `logs/run-<ts>.log`)
- `--show-dependency-graph` – render the dependency graph and exit

## How the Runners Work
### Windows runner (`bootstrap.ps1` → `runners/windows.ps1`)
1. Ensure Chocolatey exists; install if missing.
2. Ensure **uv** (Python manager) via Chocolatey.
3. Create `.venv` with `uv venv` if missing.
4. Install project deps with `uv pip install -e .` using `pyproject.toml`.
5. Launch the Typer app with any CLI args.

> If Chocolatey requests a reboot, reboot and rerun `.\bootstrap.ps1`.

### macOS/Linux runner (`bootstrap.sh` → `runners/{macos,linux}.sh`)
1. Ensure **uv** (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
2. Create `.venv` with `uv venv` if missing.
3. Install deps with `uv pip install -e .`.
4. Launch the Typer app with any CLI args.

## Manifest Schema (excerpt)
```yaml
tasks:
  - id: git
    name: Git
    type: package
    deps: []
    exit_on_failure: false
    win:   { choco: "git" }
    mac:   { brew: "git" }
    linux: { apt: "git" }

  - id: nerd_fonts
    name: Nerd Fonts (DroidSansMono)
    deps: []
    win:   { script: "scripts/windows/install-nerd-fonts.ps1" }
    mac:   { script: "scripts/macos/install-nerd-fonts.sh" }
    linux: { script: "scripts/linux/install-nerd-fonts.sh" }
```
Per‑OS keys: `choco`, `winget`, `brew`, `brew_cask`, `apt`, `script`, optional `post` (list of scripts).

## Current Tooling (from `manifest.yaml`)
Git, VS Code, Docker, Nerd Fonts (DroidSansMono), Terminal appearance (Windows), Cursor, oh‑my‑posh, Bitwarden, Google Chrome, Chrome extensions (Session Buddy, Bitwarden, AdBlock), Zoom, uv, fnm, Gemini CLI, Claude Code CLI, GitHub Copilot CLI, AntiGravity (placeholder), Ollama, fnm profile init (Windows), Windows Terminal configuration.

## Output & Logging
- **Analysis table:** manifest path, OS, total tasks, independent vs dependent counts, log file path.
- **Execution table:** each task shows status transitions with elapsed time; honors `exit_on_failure` by skipping the remainder.
- **Summary:** totals for success/failed/skipped plus wall time.
- **Logs:** everything printed plus stack traces is written to the chosen log file (`logs/` by default) via loguru.

## Extending the Tool
1. **Add a task** to `manifest.yaml` with `id`, `name`, optional `deps`, and per‑OS install keys.
2. **Add scripts** under `scripts/<os>/...` if using `script` or `post`.
3. Run with `--show-dependency-graph` to verify ordering.
4. Use `--dry-run` to validate wiring before installing.

## Windows Notes
- Run PowerShell as Administrator and set execution policy per session:  
  `Set-ExecutionPolicy Bypass -Scope Process -Force`
- If WSL/virtualization are needed for other workflows, enable them separately; this tool runs natively on Windows with Chocolatey/winget.
- After font/theme/profile steps, restart Windows Terminal to apply settings.

## macOS/Linux Notes
- The runner installs uv locally under `~/.local/bin` if absent; ensure it’s on `PATH` in custom shells.
- All installs are driven by the manifest; apt/brew/script actions are taken from the per‑OS mapping.

## Troubleshooting
- Add `--log-file /tmp/dev-bootstrap.log` for a fixed log path.
- Use `--dry-run` and `--show-dependency-graph` to check wiring.
- If installs fail due to missing package managers, add a preceding task to install them or supply a `script` installer.
