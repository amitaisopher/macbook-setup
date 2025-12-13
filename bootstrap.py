#!/usr/bin/env python3
"""
Bootstrap CLI for setting up this workstation using Ansible.

The CLI is implemented with Typer for a consistent developer experience:
  - `--help` shows detailed usage.
  - Commands print section headers for each stage so progress is obvious.
  - A final summary highlights which steps succeeded, were skipped, or failed.
"""

from __future__ import annotations

import json
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile
import traceback
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import List, Optional

try:
    import typer
except ModuleNotFoundError as exc:  # pragma: no cover - defensive
    sys.stderr.write(
        "This bootstrap CLI requires the 'typer' package. Install it with 'pip install typer'.\n"
    )
    raise SystemExit(1) from exc

REPO_ROOT = Path(__file__).resolve().parent
REQUIRED_ANSIBLE_VERSION = "2.14.0"
USER_BIN = Path.home() / ".local" / "bin"
MAC_PYTHON_USER_BIN = Path.home() / "Library/Python/3.9/bin"
LOCAL_TMP_BASENAME = "macbook-setup-ansible"

app = typer.Typer(
    add_completion=False,
    context_settings={"allow_extra_args": True, "ignore_unknown_options": True},
    help="Provision this machine using the local Ansible playbook.",
)


@dataclass
class StageResult:
    stage: str
    success: bool
    detail: str
    error: Optional[str] = None


stage_log: List[StageResult] = []
DRY_RUN = False


def ansible_temp_dir() -> Path:
    """Ensure a writable temporary directory for Ansible CLI commands."""
    base = Path(tempfile.gettempdir()) / LOCAL_TMP_BASENAME
    base.mkdir(parents=True, exist_ok=True)
    return base


def ansible_env() -> dict:
    env = os.environ.copy()
    tmp = ansible_temp_dir()
    env["ANSIBLE_LOCAL_TEMP"] = str(tmp)
    env["TMPDIR"] = str(tmp)
    return env


def record_stage(stage: str, success: bool, detail: str, error: Optional[str] = None) -> None:
    """Record a stage outcome for the final summary/log."""
    stage_log.append(StageResult(stage=stage, success=success, detail=detail, error=error))


def dry_run_skip(stage: str, detail: str) -> None:
    """Record that a stage was skipped because of --dry-run."""
    message = f"[dry-run] {detail}"
    typer.secho(message, fg=typer.colors.YELLOW)
    record_stage(stage, True, message)


def heading(title: str) -> None:
    typer.secho(f"\n=== {title} ===", fg=typer.colors.CYAN, bold=True)


def run_command(
    stage: str,
    command: List[str],
    description: str,
    *,
    stream: bool = False,
    env: Optional[dict] = None,
    cwd: Optional[Path] = None,
) -> None:
    """Execute a shell command and record its result."""
    heading(description)
    typer.secho("$ " + " ".join(shlex.quote(arg) for arg in command), fg=typer.colors.BLUE)
    try:
        if stream:
            subprocess.run(command, cwd=cwd or REPO_ROOT, env=env, check=True)
        else:
            result = subprocess.run(
                command,
                cwd=cwd or REPO_ROOT,
                env=env,
                check=True,
                text=True,
                capture_output=True,
            )
            if result.stdout:
                typer.echo(result.stdout)
            if result.stderr:
                typer.echo(result.stderr)
        record_stage(stage, True, description)
    except FileNotFoundError as exc:
        msg = f"Command not found: {command[0]}"
        record_stage(stage, False, description, error=msg)
        raise typer.Exit(1) from exc
    except subprocess.CalledProcessError as exc:
        if not stream:
            if exc.stdout:
                typer.echo(exc.stdout)
            if exc.stderr:
                typer.secho(exc.stderr, fg=typer.colors.RED)
        record_stage(stage, False, description, error=exc.stderr or str(exc))
        raise typer.Exit(exc.returncode)


def ensure_path(path: Path) -> None:
    """Ensure a given bin directory is on PATH for the current process."""
    if path.exists() and str(path) not in os.environ.get("PATH", ""):
        os.environ["PATH"] = f"{path}{os.pathsep}{os.environ.get('PATH', '')}"


def get_ansible_version() -> Optional[str]:
    if shutil.which("ansible") is None:
        return None
    try:
        result = subprocess.run(
            ["ansible", "--version"],
            capture_output=True,
            text=True,
            check=True,
            env=ansible_env(),
        )
    except subprocess.CalledProcessError:
        return None
    line = result.stdout.splitlines()[0] if result.stdout else ""
    parts = line.split()
    return parts[1] if len(parts) > 1 else None


def version_tuple(version: str) -> List[int]:
    return [int(part) for part in version.split(".") if part.isdigit()]


def ansible_meets_requirement(current: Optional[str]) -> bool:
    if not current:
        return False
    try:
        return tuple(version_tuple(current)) >= tuple(version_tuple(REQUIRED_ANSIBLE_VERSION))
    except ValueError:
        return False


def ensure_homebrew() -> None:
    if shutil.which("brew"):
        record_stage("Homebrew", True, "Already installed; skipping.")
        return
    run_command(
        "Homebrew",
        [
            "/bin/bash",
            "-c",
            "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh",
        ],
        "Installing Homebrew...",
    )
    for candidate in (Path("/opt/homebrew/bin"), Path("/usr/local/bin")):
        ensure_path(candidate)
        if (candidate / "brew").exists():
            break
    shellenv_line = 'eval "$($(brew --prefix)/bin/brew shellenv)"'
    profile = Path.home() / ".bash_profile"
    if not profile.exists() or shellenv_line not in profile.read_text():
        with profile.open("a", encoding="utf-8") as handle:
            handle.write(f"\n{shellenv_line}\n")
    # Refresh PATH for the current process so the newly installed brew is discoverable.
    ensure_path(Path("/opt/homebrew/bin"))
    ensure_path(Path("/usr/local/bin"))


def install_ansible_macos() -> None:
    if shutil.which("python3") is None:
        record_stage("Python 3", False, "Python 3 is required on macOS.", error="python3 unavailable")
        raise typer.Exit(1)
    ensure_homebrew()

    user_base = subprocess.run(
        ["python3", "-m", "site", "--user-base"], capture_output=True, text=True, check=True
    ).stdout.strip()
    if user_base:
        user_bin = Path(user_base) / "bin"
        user_bin.mkdir(parents=True, exist_ok=True)
        ensure_path(user_bin)
        legacy_bin = Path.home() / "Library/Python/3.9/bin"
        legacy_bin.mkdir(parents=True, exist_ok=True)
        ensure_path(legacy_bin)

    run_command(
        "pip3 upgrade",
        ["python3", "-m", "pip", "install", "--upgrade", "pip"],
        "Upgrading pip for Python 3...",
    )
    run_command(
        "Ansible (pip)",
        ["python3", "-m", "pip", "install", "--user", "--upgrade", "ansible"],
        "Installing or upgrading Ansible via pip...",
    )


def install_ansible_linux() -> None:
    if shutil.which("apt"):
        commands = [
            ("apt update", ["sudo", "apt", "update"], "Updating apt cache..."),
            (
                "apt install software-properties-common",
                ["sudo", "apt", "install", "-y", "software-properties-common"],
                "Installing software-properties-common...",
            ),
            (
                "apt add-repository",
                ["sudo", "apt-add-repository", "--yes", "--update", "ppa:ansible/ansible"],
                "Adding Ansible PPA...",
            ),
            (
                "apt install ansible",
                ["sudo", "apt", "install", "-y", "ansible"],
                "Installing Ansible from apt...",
            ),
        ]
        for stage_label, cmd, desc in commands:
            run_command(stage_label, cmd, desc, stream=True)
    elif shutil.which("dnf"):
        run_command(
            "dnf install ansible",
            ["sudo", "dnf", "install", "-y", "ansible"],
            "Installing Ansible via dnf...",
            stream=True,
        )
    else:
        record_stage(
            "Ansible (linux)",
            False,
            "Unsupported package manager; install Ansible manually.",
            error="Neither apt nor dnf detected.",
        )
        raise typer.Exit(1)


def ensure_ansible() -> None:
    current_version = get_ansible_version()
    if ansible_meets_requirement(current_version):
        record_stage("Ansible", True, f"Already installed (version {current_version}).")
        return
    system = platform.system()
    if DRY_RUN:
        record_stage(
            "Ansible prerequisites",
            True,
            "Dry-run still installs prerequisites when missing.",
        )
    if system == "Darwin":
        install_ansible_macos()
    elif system == "Linux":
        install_ansible_linux()
    else:
        record_stage("Ansible", False, f"Unsupported platform: {system}")
        raise typer.Exit(1)
    new_version = get_ansible_version()
    if new_version:
        record_stage("Ansible", True, f"Installed version {new_version}.")
    else:
        record_stage("Ansible", False, "Failed to verify Ansible installation.")
        raise typer.Exit(1)


def install_collections() -> None:
    run_command(
        "Ansible collections",
        ["ansible-galaxy", "collection", "install", "-r", "requirements.yml"],
        "Ensuring required Ansible collections...",
        stream=True,
        env=ansible_env(),
    )


def maybe_add_linux_become(ansible_args: List[str]) -> List[str]:
    if platform.system() != "Linux":
        return ansible_args
    try:
        need_sudo = os.geteuid() != 0  # type: ignore[attr-defined]
    except AttributeError:
        return ansible_args
    if not need_sudo:
        return ansible_args
    provided = any(
        arg in ("--ask-become-pass", "-K") or arg.startswith("--become-password-file=")
        for arg in ansible_args
    )
    if provided:
        return ansible_args
    typer.secho("Adding --ask-become-pass for sudo operations.", fg=typer.colors.YELLOW)
    record_stage("Privilege escalation", True, "Added --ask-become-pass for Linux.")
    return ansible_args + ["--ask-become-pass"]


def run_playbook(ansible_args: List[str]) -> None:
    final_args = list(ansible_args)
    if DRY_RUN and "--check" not in final_args:
        final_args.append("--check")
    command = ["ansible-playbook", "-i", "inventory", "main.yml"] + final_args
    run_command(
        "Ansible playbook",
        command,
        "Running primary Ansible playbook (dry-run mode)" if DRY_RUN else "Running primary Ansible playbook...",
        stream=True,
        env=ansible_env(),
    )


def print_summary() -> None:
    typer.secho("\nExecution summary", fg=typer.colors.MAGENTA, bold=True)
    for entry in stage_log:
        icon = "✓" if entry.success else "✗"
        color = typer.colors.GREEN if entry.success else typer.colors.RED
        typer.secho(f"{icon} {entry.stage}: {entry.detail}", fg=color)
        if entry.error:
            typer.secho("    " + entry.error.strip(), fg=typer.colors.RED)


def write_log_file(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = [asdict(entry) for entry in stage_log]
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    typer.secho(f"\nLog written to {path}", fg=typer.colors.BLUE)


@app.command()
def main(
    ctx: typer.Context,
    log_file: Optional[Path] = typer.Option(
        None,
        "--log-file",
        "-l",
        help="Optional path to write the JSON execution log.",
    ),
    dry_run: bool = typer.Option(
        False,
        "--dry-run",
        help="Preview actions without making changes (adds ansible-playbook --check automatically).",
    ),
) -> None:
    global DRY_RUN
    DRY_RUN = dry_run
    typer.secho("MacBook Setup Bootstrap", fg=typer.colors.GREEN, bold=True)
    typer.echo("This CLI installs prerequisites and runs the Ansible playbook for this repository.")
    record_stage("Working directory", True, f"Repository root: {REPO_ROOT}")

    system = platform.system()
    record_stage("Platform detection", True, f"Detected platform: {system}")
    if DRY_RUN:
        record_stage(
            "Dry-run mode",
            True,
            "Prerequisite installers may still run; ansible-playbook executes with --check.",
        )

    try:
        ensure_path(USER_BIN)
        ensure_path(MAC_PYTHON_USER_BIN)
        ensure_ansible()
        install_collections()
        ansible_args = list(ctx.args)
        ansible_args = maybe_add_linux_become(ansible_args)
        run_playbook(ansible_args)
    except typer.Exit:
        raise
    except Exception as exc:  # pragma: no cover - defensive catch
        record_stage("Unexpected error", False, "Unhandled exception.", error=traceback.format_exc())
        raise typer.Exit(1) from exc
    finally:
        print_summary()
        if log_file:
            log_path = log_file if log_file.is_absolute() else REPO_ROOT / log_file
            write_log_file(log_path)


if __name__ == "__main__":
    app()
