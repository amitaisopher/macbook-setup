from __future__ import annotations

import shutil
import subprocess
import sys
import time
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional

from loguru import logger

from .manifest import OSMappings, Task


class TaskStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    SKIPPED = "skipped"


class TaskResult:
    def __init__(self, task: Task):
        self.task = task
        self.status: TaskStatus = TaskStatus.PENDING
        self.started: Optional[float] = None
        self.finished: Optional[float] = None
        self.error: Optional[str] = None

    @property
    def elapsed(self) -> Optional[float]:
        if self.started is None or self.finished is None:
            return None
        return self.finished - self.started


def build_command(mapping: OSMappings, os_key: str, repo_root: Path) -> List[List[str]]:
    cmds: List[List[str]] = []
    if mapping.choco:
        cmds.append(["choco", "install", "-y", mapping.choco])
    elif mapping.winget:
        cmds.append(["winget", "install", "--id", mapping.winget, "--accept-package-agreements", "--accept-source-agreements", "--silent"])
    elif mapping.brew:
        cmds.append(["brew", "install", mapping.brew])
    elif mapping.brew_cask:
        cmds.append(["brew", "install", "--cask", mapping.brew_cask])
    elif mapping.apt:
        cmds.append(["sudo", "apt-get", "install", "-y", mapping.apt])
    if mapping.script:
        script_path = repo_root / mapping.script
        if os_key == "win":
            pwsh = shutil.which("pwsh") or shutil.which("powershell.exe") or "pwsh"
            cmds.append([pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script_path)])
        else:
            cmds.append(["bash", str(script_path)])
    for post in mapping.post:
        post_path = repo_root / post
        if os_key == "win":
            pwsh = shutil.which("pwsh") or shutil.which("powershell.exe") or "pwsh"
            cmds.append([pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(post_path)])
        else:
            cmds.append(["bash", str(post_path)])
    return cmds


def run_cmd(cmd: List[str]) -> subprocess.CompletedProcess:
    logger.debug("Executing command: {}", " ".join(cmd))
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def execute_tasks(tasks: List[Task], os_key: str, repo_root: Path, dry_run: bool) -> Dict[str, TaskResult]:
    results: Dict[str, TaskResult] = {t.id: TaskResult(t) for t in tasks}
    # Build a quick lookup for deps
    dep_map = {t.id: t.deps for t in tasks}

    # Topological-ish execution: repeatedly pick tasks whose deps are successful
    pending = set(results.keys())
    while pending:
        ready = [tid for tid in list(pending) if all(results[d].status == TaskStatus.SUCCESS for d in dep_map[tid])]
        if not ready:
            # break potential deadlock due to failed deps
            for tid in pending:
                if any(results[d].status == TaskStatus.FAILED for d in dep_map[tid]):
                    results[tid].status = TaskStatus.SKIPPED
            break
        for tid in ready:
            pending.remove(tid)
            res = results[tid]
            res.status = TaskStatus.RUNNING
            res.started = time.time()
            mapping = getattr(res.task, os_key)
            if mapping is None:
                res.status = TaskStatus.SKIPPED
                res.finished = time.time()
                continue
            try:
                if dry_run:
                    res.status = TaskStatus.SUCCESS
                    continue
                cmds = build_command(mapping, os_key, repo_root)
                ok = True
                for cmd in cmds:
                    cp = run_cmd(cmd)
                    logger.debug(cp.stdout)
                    if cp.returncode != 0:
                        ok = False
                        res.error = cp.stderr.strip()
                        logger.error("Task {} failed: {}", tid, res.error)
                        break
                res.status = TaskStatus.SUCCESS if ok else TaskStatus.FAILED
            except Exception as exc:  # noqa: BLE001
                res.status = TaskStatus.FAILED
                res.error = str(exc)
                logger.exception("Task {} raised exception", tid)
            finally:
                res.finished = time.time()
            if res.status == TaskStatus.FAILED and res.task.exit_on_failure:
                # Mark remaining pending as skipped
                for pid in pending:
                    results[pid].status = TaskStatus.SKIPPED
                pending.clear()
                break
    return results
