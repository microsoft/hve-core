# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Tests for `scripts.update_lineage`.

Covers the lineage operations defined in `adr-byo-template.instructions.md` and
`adr-standards.instructions.md`:

* `allocate` increments `last_decision_id` in `.adr-config.yml`
* `supersede` performs an atomic two-file update
* GP-06 single-parent rule (HARD-FAIL on double supersession)
* Validation failure rolls back atomically
* Slug must satisfy `^[a-z0-9][a-z0-9-]{0,62}$`
"""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent

import pytest

update_lineage = pytest.importorskip("scripts.update_lineage")


_SUPERSEDED_FRONTMATTER = """\
---
id: '0001'
title: Old Decision
status: accepted
date: 2026-04-01
deciders: [alice]
supersedes: null
superseded-by: null
---

# Old Decision
"""

_SUPERSEDER_FRONTMATTER = """\
---
id: '0002'
title: New Decision
status: proposed
date: 2026-05-03
deciders: [alice]
supersedes: null
superseded-by: null
---

# New Decision
"""


def _invoke(args: list[str], capsys: pytest.CaptureFixture[str]) -> int:
    try:
        return int(update_lineage.main(args) or 0)
    except SystemExit as exc:
        return int(exc.code or 0)


def _project(tmp_skill_root: Path, name: str = "demo", last_id: int = 0) -> Path:
    project_dir = tmp_skill_root / "docs" / "planning" / "adrs" / name
    project_dir.mkdir(parents=True, exist_ok=True)
    config = project_dir / ".adr-config.yml"
    config.write_text(
        dedent(
            f"""\
            project_slug: {name}
            template_source: madr-v4
            last_decision_id: '{last_id:04d}'
            """
        ),
        encoding="utf-8",
    )
    return project_dir


class TestUpdateLineageAllocate:
    def test_given_allocate_when_invoked_then_increments_last_decision_id(
        self, tmp_skill_root: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange
        project_dir = _project(tmp_skill_root, last_id=4)

        # Act
        exit_code = _invoke(
            ["allocate", "--project-dir", str(project_dir), "--slug", "pick-cache"],
            capsys,
        )

        # Assert
        assert exit_code == 0, capsys.readouterr().err
        config_text = (project_dir / ".adr-config.yml").read_text(encoding="utf-8")
        assert "last_decision_id: '0005'" in config_text


class TestUpdateLineageAllocatePathSafety:
    def test_given_project_dir_with_traversal_when_allocate_then_rejected(
        self, tmp_skill_root: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange
        project_dir = _project(tmp_skill_root, last_id=0)
        traversal_dir = project_dir / ".." / project_dir.name
        config_before = (project_dir / ".adr-config.yml").read_text(encoding="utf-8")

        # Act
        exit_code = _invoke(
            ["allocate", "--project-dir", str(traversal_dir), "--slug", "demo"],
            capsys,
        )

        # Assert — guard refuses and leaves config untouched.
        assert exit_code != 0
        assert (project_dir / ".adr-config.yml").read_text(encoding="utf-8") == config_before


class TestUpdateLineageSupersede:
    def test_given_valid_supersession_when_invoked_then_atomic_update(
        self, tmp_skill_root: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange
        project_dir = _project(tmp_skill_root, last_id=2)
        old = project_dir / "0001-old-decision.md"
        new = project_dir / "0002-new-decision.md"
        old.write_text(_SUPERSEDED_FRONTMATTER, encoding="utf-8")
        new.write_text(_SUPERSEDER_FRONTMATTER, encoding="utf-8")

        # Act
        exit_code = _invoke(
            [
                "supersede",
                "--superseded",
                str(old),
                "--superseder",
                str(new),
            ],
            capsys,
        )

        # Assert
        assert exit_code == 0, capsys.readouterr().err
        old_text = old.read_text(encoding="utf-8")
        new_text = new.read_text(encoding="utf-8")
        assert "superseded-by: '0002'" in old_text or 'superseded-by: "0002"' in old_text
        assert "supersedes: '0001'" in new_text or 'supersedes: "0001"' in new_text
        assert "status: superseded" in old_text


class TestUpdateLineageSupersedePathSafety:
    def test_given_allow_root_containing_adrs_when_supersede_then_succeeds(
        self, tmp_skill_root: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange — override default parent-based roots with an enclosing root.
        project_dir = _project(tmp_skill_root, last_id=2)
        old = project_dir / "0001-old-decision.md"
        new = project_dir / "0002-new-decision.md"
        old.write_text(_SUPERSEDED_FRONTMATTER, encoding="utf-8")
        new.write_text(_SUPERSEDER_FRONTMATTER, encoding="utf-8")

        # Act
        exit_code = _invoke(
            [
                "supersede",
                "--superseded",
                str(old),
                "--superseder",
                str(new),
                "--allow-root",
                str(tmp_skill_root),
            ],
            capsys,
        )

        # Assert
        assert exit_code == 0, capsys.readouterr().err
        assert "status: superseded" in old.read_text(encoding="utf-8")

    def test_given_allow_root_excluding_adrs_when_supersede_then_rejected(
        self, tmp_skill_root: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange — allow-root points away from where the ADRs live.
        project_dir = _project(tmp_skill_root, last_id=2)
        old = project_dir / "0001-old-decision.md"
        new = project_dir / "0002-new-decision.md"
        old.write_text(_SUPERSEDED_FRONTMATTER, encoding="utf-8")
        new.write_text(_SUPERSEDER_FRONTMATTER, encoding="utf-8")
        unrelated_root = tmp_skill_root / "schemas"
        old_before = old.read_text(encoding="utf-8")

        # Act
        exit_code = _invoke(
            [
                "supersede",
                "--superseded",
                str(old),
                "--superseder",
                str(new),
                "--allow-root",
                str(unrelated_root),
            ],
            capsys,
        )

        # Assert — containment refused; files untouched.
        assert exit_code != 0
        assert old.read_text(encoding="utf-8") == old_before

    def test_given_superseded_path_with_traversal_when_supersede_then_rejected(
        self, tmp_skill_root: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange
        project_dir = _project(tmp_skill_root, last_id=2)
        old = project_dir / "0001-old-decision.md"
        new = project_dir / "0002-new-decision.md"
        old.write_text(_SUPERSEDED_FRONTMATTER, encoding="utf-8")
        new.write_text(_SUPERSEDER_FRONTMATTER, encoding="utf-8")
        traversal_old = project_dir / ".." / project_dir.name / "0001-old-decision.md"
        old_before = old.read_text(encoding="utf-8")

        # Act
        exit_code = _invoke(
            [
                "supersede",
                "--superseded",
                str(traversal_old),
                "--superseder",
                str(new),
            ],
            capsys,
        )

        # Assert
        assert exit_code != 0
        assert old.read_text(encoding="utf-8") == old_before


class TestUpdateLineageGuardRails:
    def test_given_double_supersession_when_invoked_then_hard_fails_per_gp06(
        self, tmp_skill_root: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange — old already has a superseder pointing somewhere else.
        project_dir = _project(tmp_skill_root, last_id=2)
        old = project_dir / "0001-old-decision.md"
        new = project_dir / "0002-new-decision.md"
        old.write_text(
            _SUPERSEDED_FRONTMATTER.replace("superseded-by: null", "superseded-by: '9999'"),
            encoding="utf-8",
        )
        new.write_text(_SUPERSEDER_FRONTMATTER, encoding="utf-8")

        # Act
        exit_code = _invoke(
            ["supersede", "--superseded", str(old), "--superseder", str(new)],
            capsys,
        )

        # Assert
        assert exit_code != 0
        # Old must remain unchanged (rollback / refusal).
        assert "superseded-by: '9999'" in old.read_text(encoding="utf-8")


class TestUpdateLineageRollback:
    def test_given_validation_failure_when_supersede_then_rolls_back(
        self, tmp_skill_root: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange
        project_dir = _project(tmp_skill_root, last_id=2)
        old = project_dir / "0001-old-decision.md"
        new = project_dir / "0002-new-decision.md"
        old.write_text(_SUPERSEDED_FRONTMATTER, encoding="utf-8")
        new.write_text(_SUPERSEDER_FRONTMATTER, encoding="utf-8")
        old_before = old.read_text(encoding="utf-8")
        new_before = new.read_text(encoding="utf-8")

        # Force validation to raise post-write so the script must roll back.
        def _raise(*_args: object, **_kwargs: object) -> None:
            raise RuntimeError("validation failed")

        monkeypatch.setattr(update_lineage, "validate_lineage", _raise)

        # Act
        exit_code = _invoke(
            ["supersede", "--superseded", str(old), "--superseder", str(new)],
            capsys,
        )

        # Assert — both files restored to their pre-operation contents.
        assert exit_code != 0
        assert old.read_text(encoding="utf-8") == old_before
        assert new.read_text(encoding="utf-8") == new_before


class TestUpdateLineageSlugRegex:
    @pytest.mark.parametrize(
        "bad_slug",
        [
            "-leading-dash",
            "Pick_Cache",
            "pick cache",
            "x" * 64,
            "",
            "café",
        ],
    )
    def test_given_invalid_slug_when_allocate_then_rejected(
        self, tmp_skill_root: Path, bad_slug: str, capsys: pytest.CaptureFixture[str]
    ) -> None:
        # Arrange
        project_dir = _project(tmp_skill_root, last_id=0)
        config_before = (project_dir / ".adr-config.yml").read_text(encoding="utf-8")

        # Act
        exit_code = _invoke(
            ["allocate", "--project-dir", str(project_dir), "--slug", bad_slug],
            capsys,
        )

        # Assert
        assert exit_code != 0
        config_text = (project_dir / ".adr-config.yml").read_text(encoding="utf-8")
        assert config_text == config_before
