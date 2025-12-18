from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional

from loguru import logger


def setup_logging(log_file: Path, verbose: bool = True) -> None:
    """Configure loguru to write to file only (no console spam)."""
    log_file.parent.mkdir(parents=True, exist_ok=True)
    logger.remove()
    level = "DEBUG" if verbose else "INFO"
    logger.add(log_file, level=level, backtrace=True, diagnose=False, encoding="utf-8")
    logger.debug("Logging initialized. File={file}", file=log_file)


def get_logger():
    return logger
