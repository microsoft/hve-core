# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Estimate a static token footprint for an agent's resolved repository artifacts."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2


class CostEstimatorError(Exception):
    """Raised when the estimator cannot resolve a requested agent."""

    def __init__(self, message: str, exit_code: int = EXIT_ERROR) -> None:
        super().__init__(message)
        self.exit_code = exit_code


@dataclass(frozen=True)
class ArtifactRecord:
    """Represents a single resolved artifact used in the footprint."""

    path: str
    bytes: int
    content: str


@dataclass(frozen=True)
class EstimatorResult:
    """Structured result for a cost estimate."""

    agent: str
    phase: str | None
    model: str | None
    estimator: str
    approximate: bool
    encoding: str | None
    fallback_reason: str | None
    total_bytes: int
    estimated_tokens: int
    artifacts: list[ArtifactRecord]
    unresolved: list[str]
    limitations: list[str]


class Tokenizer:
    """Tokenizer abstraction with model-aware tiktoken and heuristic fallback."""

    def __init__(self, encoding: str | None = None, model: str | None = None) -> None:
        self.encoding = encoding
        self.model = model
        self.resolved_encoding: str | None = None
        self._tiktoken = None
        if encoding or model:
            try:
                import tiktoken  # type: ignore
            except ImportError:
                self._tiktoken = None
            else:
                self._tiktoken = tiktoken

    def estimate(self, text: str) -> tuple[int, str, bool, str | None]:
        """Return token count, estimator metadata, and an optional fallback reason."""
        self.resolved_encoding = None
        if self._tiktoken is not None and self.encoding:
            try:
                encoding = self._tiktoken.get_encoding(self.encoding)
            except (KeyError, ValueError):
                reason = (
                    f"Encoding '{self.encoding}' is unavailable in tiktoken; "
                    "used the heuristic estimator."
                )
                return self._heuristic_estimate(text), "heuristic", True, reason
            token_count = len(encoding.encode(text))
            self.resolved_encoding = self.encoding
            return token_count, self.encoding, False, None
        if self._tiktoken is not None and self.model:
            try:
                encoding = self._tiktoken.encoding_for_model(self.model)
            except (KeyError, ValueError):
                reason = (
                    f"Model '{self.model}' is unavailable in tiktoken; "
                    "used the heuristic estimator."
                )
                return self._heuristic_estimate(text), "heuristic", True, reason
            self.resolved_encoding = encoding.name
            token_count = len(encoding.encode(text))
            return token_count, self.resolved_encoding, False, None
        fallback_reason = None
        if self.encoding:
            fallback_reason = "tiktoken is not installed; used the heuristic estimator."
        elif self.model:
            fallback_reason = (
                f"tiktoken is not installed; cannot resolve model '{self.model}'; "
                "used the heuristic estimator."
            )
        return self._heuristic_estimate(text), "heuristic", True, fallback_reason

    def _heuristic_estimate(self, text: str) -> int:
        """Estimate tokens using deterministic stdlib heuristics."""
        if not text:
            return 0
        word_count = len(re.findall(r"\S+", text))
        char_count = len(text)
        token_floor = max(1, word_count)
        approximate_chars = max(char_count // 4, token_floor)
        return max(token_floor, approximate_chars)


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the CLI parser."""
    parser = argparse.ArgumentParser(description="Estimate static agent footprint cost")
    parser.add_argument("--agent", required=True, help="Agent name to resolve")
    parser.add_argument("--phase", default=None, help="Optional phase label")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument(
        "--model",
        default=None,
        help="Optional tiktoken model name used to resolve an encoding",
    )
    parser.add_argument(
        "--encoding",
        default=None,
        help="Optional tiktoken encoding that overrides --model",
    )
    parser.add_argument("--repo-root", type=Path, default=None, help="Repository root path")
    return parser


def normalize_text(text: str) -> str:
    """Normalize line endings and surrounding whitespace for deterministic analysis."""
    return text.replace("\r\n", "\n").replace("\r", "\n")


def normalize_name(value: str) -> str:
    """Convert a display name or path stem into a deterministic search key."""
    stripped = value.strip().lower()
    stripped = stripped.replace(".agent.md", "")
    stripped = stripped.replace(".md", "")
    stripped = re.sub(r"[^a-z0-9]+", "-", stripped)
    return stripped.strip("-")


def sanitize_filename(value: str) -> str:
    """Sanitize a label so it can be used safely in an output filename."""
    normalized = re.sub(r"[^a-z0-9._-]+", "-", value.lower()).strip("-._")
    return normalized or "artifact"


def resolve_agent_path(repo_root: Path, agent_name: str) -> Path:
    """Resolve the target agent markdown file from .github/agents/**."""
    normalized_target = normalize_name(agent_name)
    candidate_paths = sorted(
        path
        for path in repo_root.glob(".github/agents/**/*.agent.md")
        if normalize_name(path.name) == normalized_target
    )
    if not candidate_paths:
        candidate_paths = sorted(
            path
            for path in repo_root.glob(".github/agents/**/*.agent.md")
            if normalize_name(path.stem) == normalized_target
        )
    if not candidate_paths:
        raise CostEstimatorError(f"Unable to resolve agent '{agent_name}'")
    if len(candidate_paths) > 1:
        matches = ", ".join(to_workspace_relative(repo_root, path) for path in candidate_paths)
        raise CostEstimatorError(f"Ambiguous agent match for '{agent_name}': {matches}")
    return candidate_paths[0]


def parse_frontmatter(path: Path) -> dict[str, Any]:
    """Parse a simple YAML frontmatter block for the agent metadata."""
    raw_text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\s*\r?\n(.*?)\r?\n---(?:\s*\r?\n|$)", raw_text, re.DOTALL)
    if not match:
        return {}

    frontmatter_text = match.group(1)
    values: dict[str, Any] = {}
    lines = frontmatter_text.splitlines()
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        if ":" not in line:
            index += 1
            continue

        key, raw_value = line.split(":", 1)
        key = key.strip()
        value = raw_value.strip()
        if not value:
            value_list: list[str] = []
            index += 1
            while index < len(lines):
                next_line = lines[index]
                if not next_line.strip():
                    index += 1
                    continue
                if not next_line.startswith("  ") and not next_line.startswith("\t"):
                    break
                item = next_line.lstrip()
                if item.startswith("- "):
                    value_list.append(item[2:].strip().strip("\"'"))
                    index += 1
                    continue
                break
            values[key] = value_list
            continue

        values[key] = parse_scalar(value)
        index += 1

    return values


def parse_scalar(value: str) -> str | list[str]:
    """Parse a simple frontmatter scalar or list entry."""
    stripped = value.strip()
    if not stripped:
        return ""
    if stripped == "[]":
        return []
    if stripped.startswith("[") and stripped.endswith("]"):
        inner = stripped[1:-1].strip()
        if not inner:
            return []
        parsed_items = [parse_scalar(item) for item in inner.split(",")]
        return [item[0] if isinstance(item, list) else item for item in parsed_items]
    if (stripped.startswith('"') and stripped.endswith('"')) or (
        stripped.startswith("'") and stripped.endswith("'")
    ):
        return stripped[1:-1]
    return stripped


def collect_agent_artifacts(
    repo_root: Path, agent_path: Path, phase: str | None = None
) -> tuple[list[ArtifactRecord], list[str]]:
    """Collect the agent, subagent, skill, and optional phase-section artifacts."""
    artifacts: list[ArtifactRecord] = []
    unresolved: list[str] = []
    seen_paths: set[str] = set()

    def add_artifact(path: Path, content: str, fragment: str | None = None) -> None:
        workspace_relative = to_workspace_relative(repo_root, path)
        if fragment:
            workspace_relative = f"{workspace_relative}#{normalize_name(fragment)}"
        if workspace_relative in seen_paths:
            return
        seen_paths.add(workspace_relative)
        normalized_content = normalize_text(content)
        artifacts.append(
            ArtifactRecord(
                path=workspace_relative,
                bytes=len(normalized_content.encode("utf-8")),
                content=normalized_content,
            )
        )

    agent_text = agent_path.read_text(encoding="utf-8")
    add_artifact(agent_path, agent_text)

    frontmatter = parse_frontmatter(agent_path)
    declared_subagents = frontmatter.get("agents", [])
    if isinstance(declared_subagents, str):
        declared_subagents = [declared_subagents]
    if isinstance(declared_subagents, list):
        for name in declared_subagents:
            subagent_path = resolve_subagent_path(repo_root, str(name))
            if subagent_path is None:
                unresolved.append(str(name))
                continue
            add_artifact(subagent_path, subagent_path.read_text(encoding="utf-8"))

    agent_body = agent_text.split("---\n", 2)[-1] if agent_text.startswith("---\n") else agent_text
    skill_candidates, unresolved_skills = resolve_referenced_skill_paths(repo_root, agent_body)
    unresolved.extend(unresolved_skills)
    for resolved_path in skill_candidates:
        if phase:
            phase_section = extract_phase_section(resolved_path, phase)
            if phase_section is not None:
                add_artifact(resolved_path, phase_section, fragment=phase)
            elif skill_has_phase_sections(resolved_path):
                skill_label = to_workspace_relative(repo_root, resolved_path)
                unresolved.append(f"phase section:{phase}:{skill_label}")
            else:
                add_artifact(resolved_path, resolved_path.read_text(encoding="utf-8"))
        else:
            add_artifact(resolved_path, resolved_path.read_text(encoding="utf-8"))

    read_file_targets = re.findall(r"read_file\s*\(([^)]+)\)", agent_body)
    for target in read_file_targets:
        target = target.strip().strip("\"'")
        if target.startswith("#file:"):
            target = target[6:]
        if target.startswith("../"):
            candidate = (agent_path.parent / target).resolve()
        else:
            candidate = (repo_root / target).resolve()
        if not is_within_repo(repo_root, candidate):
            unresolved.append(f"external read_file target omitted:{candidate.name}")
            continue
        if candidate.exists() and candidate.is_file() and candidate.name == "SKILL.md":
            add_artifact(candidate, candidate.read_text(encoding="utf-8"))
        else:
            unresolved.append(to_workspace_relative(repo_root, candidate))

    artifacts.sort(key=lambda item: item.path)
    return artifacts, unresolved


def resolve_referenced_skill_paths(
    repo_root: Path, agent_body: str
) -> tuple[list[Path], list[str]]:
    """Resolve explicit paths and backticked skill names from agent instructions."""
    resolved: set[Path] = set()
    unresolved: list[str] = []
    explicit_references = set(
        re.findall(r"(?<![\w./-])(?:\.github/skills/[^\s'\")]+/SKILL\.md)", agent_body)
    )
    for reference in explicit_references:
        candidate = (repo_root / reference).resolve()
        if not is_within_repo(repo_root, candidate):
            unresolved.append(f"external skill path omitted:{candidate.name}")
        elif candidate.is_file():
            resolved.add(candidate)
        else:
            unresolved.append(reference)

    skill_index = build_skill_index(repo_root)
    named_references = set(
        re.findall(r"`([^`\n]+)`\s+(?:shared\s+)?skill\b", agent_body, re.IGNORECASE)
    )
    for reference in named_references:
        matches = skill_index.get(normalize_name(reference), [])
        if len(matches) == 1:
            resolved.add(matches[0])
        elif not matches:
            unresolved.append(f"skill:{reference}")
        else:
            unresolved.append(f"skill:{reference} (ambiguous)")

    return sorted(resolved, key=lambda path: path.as_posix()), sorted(set(unresolved))


def build_skill_index(repo_root: Path) -> dict[str, list[Path]]:
    """Index repository skills by folder and declared frontmatter name."""
    skill_index: dict[str, list[Path]] = {}
    for path in sorted(repo_root.glob(".github/skills/*/*/SKILL.md")):
        if not is_within_repo(repo_root, path):
            continue
        names = {normalize_name(path.parent.name)}
        declared_name = parse_frontmatter(path).get("name")
        if isinstance(declared_name, str):
            names.add(normalize_name(declared_name))
        for name in names:
            skill_index.setdefault(name, []).append(path.resolve())
    return skill_index


def extract_phase_section(skill_path: Path, phase: str) -> str | None:
    """Extract the matching phase section from a skill markdown file, if present."""
    skill_text = skill_path.read_text(encoding="utf-8")
    anchors = {
        normalize_name(phase),
        normalize_name(f"prd-{phase}"),
        normalize_name(f"brd-{phase}"),
    }
    lines = skill_text.splitlines()
    pattern = re.compile(r"^(#{1,6})\s+(.*?)\s*\{#([a-z0-9-]+)\}\s*$")
    for index, line in enumerate(lines):
        match = pattern.match(line)
        if not match:
            continue
        anchor = normalize_name(match.group(3))
        if anchor not in anchors:
            continue
        level = len(match.group(1))
        section_lines: list[str] = []
        for next_line in lines[index + 1 :]:
            nested_match = pattern.match(next_line)
            if nested_match and len(nested_match.group(1)) <= level:
                break
            section_lines.append(next_line)
        return "\n".join(section_lines).strip()

    if phase in {"discover", "define", "govern"}:
        header = f"## {phase.title()}"
        if header in skill_text:
            start = skill_text.index(header)
            next_header = re.search(r"\n## ", skill_text[start + len(header) :])
            remaining_text = skill_text[start + len(header) :]
            end = start + len(header) + (
                next_header.start() if next_header else len(remaining_text)
            )
            return skill_text[start:end].strip()

    return None


def skill_has_phase_sections(skill_path: Path) -> bool:
    """Return whether a skill declares BRD or PRD phase-section anchors."""
    skill_text = skill_path.read_text(encoding="utf-8")
    anchors = re.findall(r"\{#([a-z0-9-]+)\}", skill_text)
    phase_names = {"discover", "define", "govern"}
    return any(anchor in phase_names or anchor.startswith(("brd-", "prd-")) for anchor in anchors)


def resolve_subagent_path(repo_root: Path, subagent_name: str) -> Path | None:
    """Resolve a subagent by display name or filename stem."""
    normalized_target = normalize_name(subagent_name)
    candidate_paths = [
        path
        for path in repo_root.glob(".github/agents/**/*.agent.md")
        if normalize_name(path.name) == normalized_target
    ]
    if not candidate_paths:
        candidate_paths = [
            path
            for path in repo_root.glob(".github/agents/**/*.agent.md")
            if normalize_name(path.stem) == normalized_target
        ]
    if not candidate_paths:
        return None
    if len(candidate_paths) > 1:
        return None
    return candidate_paths[0]


def to_workspace_relative(repo_root: Path, path: Path) -> str:
    """Return a plain-text workspace-relative path for output."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as error:
        raise CostEstimatorError(
            f"Artifact path is outside the repository root: {path.name}"
        ) from error


def is_within_repo(repo_root: Path, path: Path) -> bool:
    """Return whether a path resolves inside the repository root."""
    try:
        path.resolve().relative_to(repo_root.resolve())
    except ValueError:
        return False
    return True


def build_result(
    agent_name: str,
    phase: str | None,
    repo_root: Path,
    encoding: str | None,
    model: str | None = None,
) -> EstimatorResult:
    """Build the estimator result object for the chosen agent and phase."""
    agent_path = resolve_agent_path(repo_root, agent_name)
    artifacts, unresolved = collect_agent_artifacts(repo_root, agent_path, phase=phase)
    normalized_parts = [normalize_text(item.content) for item in artifacts]
    joined_text = "\n\n".join(normalized_parts)

    tokenizer = Tokenizer(encoding=encoding, model=model)
    token_count, estimator_name, approximate, fallback_reason = tokenizer.estimate(joined_text)
    limitations = [
        "Measures repository artifact bytes, not the host-composed prompt.",
        "applyTo instruction matching is not included in the MVP.",
    ]

    return EstimatorResult(
        agent=agent_name,
        phase=phase,
        model=model,
        estimator=estimator_name,
        approximate=approximate,
        encoding=encoding or tokenizer.resolved_encoding,
        fallback_reason=fallback_reason,
        total_bytes=sum(item.bytes for item in artifacts),
        estimated_tokens=token_count,
        artifacts=[
            ArtifactRecord(path=item.path, bytes=item.bytes, content="") for item in artifacts
        ],
        unresolved=sorted(set(unresolved)),
        limitations=limitations,
    )


def to_serializable(result: EstimatorResult) -> dict[str, Any]:
    """Convert the result to a deterministic JSON-serializable object."""
    return {
        "agent": result.agent,
        "phase": result.phase,
        "model": result.model,
        "estimator": result.estimator,
        "approximate": result.approximate,
        "encoding": result.encoding,
        "fallback_reason": result.fallback_reason,
        "total_bytes": result.total_bytes,
        "estimated_tokens": result.estimated_tokens,
        "artifacts": [
            {"path": artifact.path, "bytes": artifact.bytes} for artifact in result.artifacts
        ],
        "unresolved": result.unresolved,
        "limitations": result.limitations,
    }


def write_output(
    result: EstimatorResult, repo_root: Path, output_path: Path, output_format: str
) -> None:
    """Write the output JSON to logs/cost and print a concise summary."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    payload = to_serializable(result)
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    if output_format == "json":
        print(json.dumps(payload, indent=2))
        return

    summary_lines = [
        f"Agent: {result.agent}",
        f"Phase: {result.phase or 'n/a'}",
        f"Model: {result.model or 'n/a'}",
        f"Estimator: {result.estimator}",
        f"Approximate: {str(result.approximate).lower()}",
        f"Fallback: {result.fallback_reason or 'n/a'}",
        f"Artifacts: {len(result.artifacts)}",
        f"Total bytes: {result.total_bytes}",
        f"Estimated tokens: {result.estimated_tokens}",
    ]
    print("\n".join(summary_lines))


def main(argv: list[str] | None = None) -> int:
    """Entry point for the CLI."""
    parser = create_parser()
    args = parser.parse_args(argv)

    try:
        repo_root = args.repo_root.resolve() if args.repo_root else Path.cwd().resolve()
        result = build_result(args.agent, args.phase, repo_root, args.encoding, args.model)
        phase_suffix = f"-{sanitize_filename(args.phase)}" if args.phase else ""
        output_name = f"{sanitize_filename(args.agent)}{phase_suffix}.json"
        output_file = repo_root / "logs" / "cost" / output_name
        write_output(result, repo_root, output_file, args.format)
    except CostEstimatorError as error:
        print(f"Error: {error}", file=sys.stderr)
        return error.exit_code
    except Exception as error:  # pragma: no cover - defensive boundary
        print(f"Error: {error}", file=sys.stderr)
        return EXIT_FAILURE

    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
