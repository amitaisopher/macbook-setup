from __future__ import annotations

from pathlib import Path
from typing import List, Optional

import yaml
from pydantic import BaseModel, Field, model_validator


class OSMappings(BaseModel):
    choco: Optional[str] = None
    winget: Optional[str] = None
    brew: Optional[str] = None
    brew_cask: Optional[str] = None
    apt: Optional[str] = None
    script: Optional[str] = None
    post: List[str] = Field(default_factory=list)
    version: Optional[str] = None

    def has_action(self) -> bool:
        return any([self.choco, self.winget, self.brew, self.brew_cask, self.apt, self.script])


class Task(BaseModel):
    id: str
    name: str
    type: str = "package"
    deps: List[str] = Field(default_factory=list)
    exit_on_failure: bool = False
    win: Optional[OSMappings] = None
    mac: Optional[OSMappings] = None
    linux: Optional[OSMappings] = None

    @model_validator(mode="after")
    def validate_action(self):
        if not any([self.win, self.mac, self.linux]):
            raise ValueError(f"Task {self.id} must define at least one OS mapping")
        return self


class Manifest(BaseModel):
    tasks: List[Task]

    @classmethod
    def load(cls, path: Path) -> "Manifest":
        data = yaml.safe_load(path.read_text())
        if not isinstance(data, dict) or "tasks" not in data:
            raise ValueError("Manifest is missing 'tasks' section")
        return cls.model_validate(data)

    def for_os(self, os_key: str) -> List[Task]:
        filtered: List[Task] = []
        for task in self.tasks:
            mapping = getattr(task, os_key)
            if mapping and mapping.has_action():
                filtered.append(task)
        return filtered
