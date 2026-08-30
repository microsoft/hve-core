# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""Canonical artifact-bundle layout for accessibility coverage evidence."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from runtime_a11y.matrix._catalog import catalog_provenance
from runtime_a11y.matrix._model import Matrix
from runtime_a11y.matrix._provenance import ArtifactMetadata, build_artifact_metadata
from runtime_a11y.matrix._render_earl import render_earl
from runtime_a11y.matrix._render_json import render_json
from runtime_a11y.matrix._render_md import render_markdown
from runtime_a11y.matrix._render_test_plan import (
    render_manual_test_plan_markdown,
    render_manual_test_plan_yaml,
)


def _slug_token(repo_slug: str) -> str:
    token = re.sub(r"[^a-zA-Z0-9._-]+", "-", repo_slug).strip("-.").lower()
    return token or "repository"


@dataclass(frozen=True, slots=True)
class ArtifactPaths:
    coverage_json: Path
    coverage_markdown: Path
    earl_jsonld: Path
    manual_plan_markdown: Path
    manual_plan_yaml: Path
    manifest_json: Path

    def relative_manifest(self, root: Path) -> dict[str, str]:
        """Return stable bundle-relative artifact paths."""
        return {
            "coverageJson": self.coverage_json.relative_to(root).as_posix(),
            "coverageMarkdown": self.coverage_markdown.relative_to(root).as_posix(),
            "earlJsonLd": self.earl_jsonld.relative_to(root).as_posix(),
            "manualTestPlanMarkdown": self.manual_plan_markdown.relative_to(
                root
            ).as_posix(),
            "manualTestPlanYaml": self.manual_plan_yaml.relative_to(root).as_posix(),
        }


def artifact_paths(output_dir: Path, repo_slug: str) -> ArtifactPaths:
    """Resolve deterministic artifact paths for a repository scope."""
    token = _slug_token(repo_slug)
    return ArtifactPaths(
        coverage_json=output_dir / f"coverage-matrix-{token}.json",
        coverage_markdown=output_dir / f"coverage-matrix-{token}.md",
        earl_jsonld=output_dir / f"accessibility-results-{token}.earl.jsonld",
        manual_plan_markdown=output_dir / f"manual-at-testplan-{token}.md",
        manual_plan_yaml=output_dir / f"manual-at-testplan-{token}.yaml",
        manifest_json=output_dir / f"accessibility-artifacts-{token}.json",
    )


def render_artifact_bundle(
    matrix: Matrix,
    coverage: dict[str, Any],
    output_dir: Path,
    repo_slug: str,
    runtime_config: dict[str, Any] | None = None,
    metadata: ArtifactMetadata | None = None,
) -> ArtifactPaths:
    """Render the canonical coverage, EARL, and manual-plan artifact bundle.

    Metadata is built once and serialized by every export so a consumer reading
    one artifact alone still sees its provenance and review state.
    """
    paths = artifact_paths(output_dir, repo_slug)
    if metadata is None:
        metadata = build_artifact_metadata(
            repository=repo_slug, catalog=catalog_provenance()
        )
    render_json(matrix, coverage, paths.coverage_json, metadata)
    render_markdown(matrix, coverage, paths.coverage_markdown, repo_slug, metadata)
    render_earl(matrix, coverage, paths.earl_jsonld, metadata)
    render_manual_test_plan_markdown(
        matrix, paths.manual_plan_markdown, repo_slug, runtime_config
    )
    render_manual_test_plan_yaml(
        matrix, paths.manual_plan_yaml, repo_slug, runtime_config, metadata
    )

    manifest = {
        "version": 2,
        "repository": repo_slug,
        "assessment": metadata.to_dict(),
        "artifacts": paths.relative_manifest(output_dir),
    }
    paths.manifest_json.parent.mkdir(parents=True, exist_ok=True)
    paths.manifest_json.write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return paths
