from __future__ import annotations

import os
import signal
import sys
import time
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.table import Table

from .graph import TaskGraph
from .logging import setup_logging, get_logger
from .manifest import Manifest
from .runner import TaskStatus, execute_tasks

app = typer.Typer(help="Manifest-driven installer")
console = Console()


@app.callback()
def main_callback():
    """Entry point for Typer."""


@app.command()
def install(
    manifest_file: str = typer.Option(
        "manifest.yaml",
        help="Path to manifest YAML",
        show_default=True,
    ),
    dry_run: bool = typer.Option(False, help="Do not actually install"),
    log_file: Optional[Path] = typer.Option(None, help="Path for log file"),
    show_dependency_graph: bool = typer.Option(False, help="Print dependency graph and exit"),
):
    start_time = time.time()
    manifest_file = Path(manifest_file).resolve()
    log_path = log_file or (Path.cwd() / "logs" / f"run-{int(start_time)}.log")
    setup_logging(log_path)
    logger = get_logger()
    logger.info("Using manifest {}", manifest_file)

    # Detect OS key
    platform = sys.platform
    if platform.startswith("win"):
        os_key = "win"
    elif platform == "darwin":
        os_key = "mac"
    else:
        os_key = "linux"

    try:
        manifest = Manifest.load(manifest_file)
    except Exception as exc:  # noqa: BLE001
        console.print(f"[red]Failed to load manifest:[/red] {exc}")
        logger.exception("Manifest load failed")
        raise typer.Exit(code=1)

    tasks = manifest.for_os(os_key)
    if not tasks:
        console.print("[yellow]No tasks for this OS in manifest.[/yellow]")
        raise typer.Exit(code=0)

    graph = TaskGraph(tasks)
    if show_dependency_graph:
        console.print(graph.render_table())
        raise typer.Exit(code=0)

    independents = [t for t in tasks if not t.deps]
    dependents = [t for t in tasks if t.deps]

    analysis = Table(title="Analysis", title_justify="center")
    analysis.add_column("Item")
    analysis.add_column("Value")
    analysis.add_row("Manifest", str(manifest_file))
    analysis.add_row("OS", os_key)
    analysis.add_row("Tasks", str(len(tasks)))
    analysis.add_row("Independent", str(len(independents)))
    analysis.add_row("Dependent", str(len(dependents)))
    analysis.add_row("Log file", str(log_path))
    console.print(analysis)

    # SIGINT handler to break out gracefully
    interrupted = False

    def handle_sigint(sig, frame):  # noqa: ANN001
        nonlocal interrupted
        interrupted = True
        console.print("[yellow]\nInterrupted. Finishing current task and summarizing...[/yellow]")

    signal.signal(signal.SIGINT, handle_sigint)

    execution_title = "Execution Details"
    results = execute_tasks(tasks, os_key, manifest_file.parent, dry_run)

    # Summary
    summary = Table(title=execution_title, title_justify="center")
    summary.add_column("Task")
    summary.add_column("Status")
    summary.add_column("Elapsed (s)")
    for tid, res in results.items():
        status = res.status.value
        elapsed = f"{res.elapsed:.2f}" if res.elapsed else "-"
        color = {
            TaskStatus.SUCCESS: "green",
            TaskStatus.FAILED: "red",
            TaskStatus.SKIPPED: "yellow",
            TaskStatus.RUNNING: "cyan",
            TaskStatus.PENDING: "white",
        }[res.status]
        summary.add_row(res.task.name, f"[{color}]{status}[/{color}]", elapsed)
    console.print(summary)

    totals = Table(show_header=False, title="Summary", title_justify="center")
    total_success = sum(1 for r in results.values() if r.status == TaskStatus.SUCCESS)
    total_failed = sum(1 for r in results.values() if r.status == TaskStatus.FAILED)
    total_skipped = sum(1 for r in results.values() if r.status == TaskStatus.SKIPPED)
    totals.add_row("Success", str(total_success))
    totals.add_row("Failed", str(total_failed))
    totals.add_row("Skipped", str(total_skipped))
    totals.add_row("Duration (s)", f"{time.time() - start_time:.2f}")
    console.print(totals)

    if total_failed:
        raise typer.Exit(code=1)


if __name__ == "__main__":
    app()
