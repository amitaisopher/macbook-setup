from __future__ import annotations

from typing import Dict, List, Set

from rich.table import Table

from .manifest import Task


class TaskGraph:
    def __init__(self, tasks: List[Task]):
        self.tasks = {t.id: t for t in tasks}
        self.graph: Dict[str, List[str]] = {t.id: t.deps for t in tasks}
        self._check_cycles()

    def _check_cycles(self) -> None:
        visited: Set[str] = set()
        stack: Set[str] = set()

        def dfs(node: str):
            if node in stack:
                raise ValueError(f"Cycle detected at task {node}")
            if node in visited:
                return
            stack.add(node)
            for dep in self.graph.get(node, []):
                if dep not in self.tasks:
                    raise ValueError(f"Task {node} depends on missing task {dep}")
                dfs(dep)
            stack.remove(node)
            visited.add(node)

        for node in self.graph:
            dfs(node)

    def topological(self) -> List[str]:
        in_deg = {k: 0 for k in self.graph}
        for deps in self.graph.values():
            for d in deps:
                in_deg[d] = in_deg.get(d, 0) + 1
        queue = [k for k, v in in_deg.items() if v == 0]
        order: List[str] = []
        while queue:
            node = queue.pop(0)
            order.append(node)
            for dep in self.graph.get(node, []):
                in_deg[dep] -= 1
                if in_deg[dep] == 0:
                    queue.append(dep)
        if len(order) != len(self.graph):
            raise ValueError("Cycle detected during topo sort")
        return order

    def render_table(self) -> Table:
        table = Table(title="Dependency Graph")
        table.add_column("Task")
        table.add_column("Depends On")
        for task_id, deps in self.graph.items():
            table.add_row(task_id, ", ".join(deps) if deps else "-")
        return table
