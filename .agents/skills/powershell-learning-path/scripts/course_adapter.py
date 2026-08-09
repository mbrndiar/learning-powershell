#!/usr/bin/env python3
"""Validate and project this repository's Learning Mentor curriculum."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

SCRIPT = Path(__file__).resolve()
SKILL_DIR = SCRIPT.parents[1]
ROOT = SKILL_DIR.parents[2]
MANIFEST = SKILL_DIR / "course.json"
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SHELL_OPERATORS = {"&&", "||", ";", "|", ">", ">>", "<", "$(", "`"}
EXIT_INVALID = 3


class ManifestError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ManifestError(message)


def load_manifest(path: Path = MANIFEST) -> dict[str, Any]:
    with path.open(encoding="utf-8") as source:
        value = json.load(source)
    require(isinstance(value, dict), "manifest root must be an object")
    return value


def safe_path(value: object, label: str, root: Path) -> Path:
    require(isinstance(value, str) and value, f"{label} must be a path")
    relative = Path(value)
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    resolved = (root / relative).resolve()
    require(resolved == root.resolve() or root.resolve() in resolved.parents, f"{label} escapes the repository")
    require(resolved.exists(), f"{label} does not exist: {value}")
    return resolved


def validate_learner_selector(language: str, objective: dict[str, Any]) -> None:
    objective_id = objective["id"]
    kind = objective.get("kind")
    require(kind in {"module", "project", "capstone"}, f"{objective_id} has invalid kind")
    command = objective["check"]

    if language == "csharp":
        selector = (
            "-p:CourseImplementation=Starter"
            if kind in {"module", "project"}
            else "-p:ComparativeImplementation=Starter"
            if objective_id == "capstone.comparative"
            else "-p:CapstoneImplementation=Starter"
        )
        require(selector in command, f"{objective_id}.check must select the learner implementation")
    elif language == "scala":
        selector = (
            "-Dcourse.exercise=starter"
            if kind == "module"
            else "-Dcourse.tasks=starter"
            if kind == "project"
            else "-Dcourse.capstone=starter"
        )
        require(selector in command, f"{objective_id}.check must select the learner implementation")
    elif language == "typescript":
        selector = (
            "EXERCISE_IMPLEMENTATION=exercise"
            if kind == "module"
            else "TASKS_IMPLEMENTATION=starter"
            if kind == "project"
            else "CAPSTONE_IMPLEMENTATION=starter"
        )
        require(command[0] == "env" and selector in command, f"{objective_id}.check must select the learner implementation")
    elif language == "powershell" and kind != "module":
        require("-Implementation" in command and "Starter" in command, f"{objective_id}.check must select the learner implementation")
        require("-Tag" in command and "All" in command, f"{objective_id}.check must run the complete learner contract")
        if kind == "capstone":
            expected = "Comparative" if objective_id == "capstone.comparative" else "Idiomatic"
            require("-Capstone" in command and expected in command, f"{objective_id}.check must select its capstone")


def validate_manifest(manifest: dict[str, Any], root: Path = ROOT) -> dict[str, Any]:
    require(manifest.get("manifest_version") == 1, "unsupported manifest_version")
    require(manifest.get("schema_version") == "1.0.0", "unsupported schema_version")
    course = manifest.get("course")
    require(isinstance(course, dict), "course must be an object")
    for field in ("id", "title", "language"):
        require(isinstance(course.get(field), str) and course[field].strip(), f"course.{field} is required")
    if course["language"] == "powershell":
        require(course.get("module_check_policy") == "learner-authored", "PowerShell modules must declare learner-authored checks")
        require(course.get("module_untouched_starter_result") == "passes", "PowerShell module baseline must be declared as passing")

    objectives = manifest.get("objectives")
    require(isinstance(objectives, list) and objectives, "objectives must be a non-empty array")
    ids: list[str] = []
    orders: list[int] = []
    for index, objective in enumerate(objectives):
        require(isinstance(objective, dict), f"objective {index} must be an object")
        objective_id = objective.get("id")
        require(isinstance(objective_id, str) and ID_PATTERN.fullmatch(objective_id) is not None, f"invalid objective id: {objective_id!r}")
        require(not re.search(r"\b[0-9a-f]{7,40}\b", objective_id), f"{objective_id} embeds a commit hash")
        require(isinstance(objective.get("title"), str) and objective["title"].strip(), f"{objective_id} needs a title")
        order = objective.get("order")
        require(isinstance(order, int) and order > 0, f"{objective_id} order must be a positive integer")
        prereqs = objective.get("prerequisites")
        require(isinstance(prereqs, list) and all(isinstance(item, str) and item for item in prereqs), f"{objective_id} prerequisites must be string IDs")
        require(len(prereqs) == len(set(prereqs)) and objective_id not in prereqs, f"{objective_id} has invalid prerequisites")
        outcomes = objective.get("outcomes")
        require(isinstance(outcomes, list) and outcomes and all(isinstance(item, str) and item.strip() for item in outcomes), f"{objective_id} needs outcomes")
        unlock = objective.get("solution_unlock_after")
        require(isinstance(unlock, int) and 1 <= unlock <= 100, f"{objective_id} solution_unlock_after must be 1..100")
        safe_path(objective.get("narrative"), f"{objective_id}.narrative", root)
        safe_path(objective.get("practice"), f"{objective_id}.practice", root)
        solutions = objective.get("solution_paths")
        require(isinstance(solutions, list) and solutions, f"{objective_id} needs solution_paths")
        for solution_index, solution in enumerate(solutions):
            safe_path(solution, f"{objective_id}.solution_paths[{solution_index}]", root)
        command = objective.get("check")
        require(isinstance(command, list) and command and all(isinstance(arg, str) and arg for arg in command), f"{objective_id}.check must be an argv array")
        require(command[0] not in SHELL_OPERATORS and not any(arg in SHELL_OPERATORS for arg in command), f"{objective_id}.check contains a shell operator")
        require("=" not in command[0], f"{objective_id}.check starts with an environment assignment")
        validate_learner_selector(course["language"], objective)
        ids.append(objective_id)
        orders.append(order)

    duplicates = [item for item, count in Counter(ids).items() if count > 1]
    require(not duplicates, f"duplicate objective IDs: {duplicates}")
    require(len(orders) == len(set(orders)), "objective orders must be unique")
    known = set(ids)
    graph = {item["id"]: item["prerequisites"] for item in objectives}
    for objective_id, prereqs in graph.items():
        for prereq in prereqs:
            require(prereq in known, f"{objective_id} has unknown prerequisite {prereq}")

    visiting: set[str] = set()
    visited: set[str] = set()
    def visit(node: str) -> None:
        require(node not in visiting, f"prerequisite cycle at {node}")
        if node in visited:
            return
        visiting.add(node)
        for dependency in graph[node]:
            visit(dependency)
        visiting.remove(node)
        visited.add(node)
    for node in ids:
        visit(node)

    concepts = [
        {
            "id": item["id"],
            "title": item["title"],
            "order": item["order"],
            "prerequisites": item["prerequisites"],
            "solution_unlock_after": item["solution_unlock_after"],
        }
        for item in sorted(objectives, key=lambda value: (value["order"], value["id"]))
    ]
    return {"concepts": concepts}


def compact(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("validate", "state-projection"))
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    arguments = parser.parse_args(argv)
    try:
        manifest = load_manifest(arguments.manifest)
        projection = validate_manifest(manifest)
    except (OSError, json.JSONDecodeError, ManifestError) as error:
        print(f"course manifest invalid: {error}", file=sys.stderr)
        return EXIT_INVALID
    if arguments.operation == "validate":
        print(compact({"adapter_protocol": "1", "manifest_schema": manifest["schema_version"], "objectives": len(projection["concepts"]), "status": "valid"}))
    else:
        print(compact(projection))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
