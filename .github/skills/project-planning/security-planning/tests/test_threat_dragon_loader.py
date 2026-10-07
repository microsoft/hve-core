# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Opt-in check that golden models load in pinned OWASP Threat Dragon v2.6.2.

The test needs Git, Node.js, npm, and network access, so it runs only when
``THREAT_DRAGON_LOADER=1``. It checks out the pinned upstream commit into a
temporary directory, installs ``td.vue`` with ``npm ci``, and runs
``tests/harness/threat-dragon-v2.6.2-loader.spec.js`` with that checkout's Jest.

Set ``THREAT_DRAGON_CHECKOUT`` to an existing checkout of the pinned commit with
``td.vue/node_modules`` installed to skip the clone and install. The harness
directory it adds to that checkout is removed afterwards.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from collections.abc import Iterator
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
HARNESS_SPEC = ROOT / "tests" / "harness" / "threat-dragon-v2.6.2-loader.spec.js"
GOLDEN_DIR = ROOT / "tests" / "fixtures" / "threat-dragon" / "expected"
PINNED_COMMIT = "8c0edb2295a1587684324646c8507fd56ba9a197"
UPSTREAM = "https://github.com/OWASP/threat-dragon.git"
HARNESS_SUBDIR = Path("td.vue") / "tests" / "unit" / "hve-core-export"

pytestmark = pytest.mark.skipif(
    os.environ.get("THREAT_DRAGON_LOADER") != "1",
    reason="set THREAT_DRAGON_LOADER=1 to run the pinned Threat Dragon loader check",
)


def _tool(name: str) -> str:
    path = shutil.which(name)
    if not path:
        pytest.skip(f"{name} is not available on PATH")
    return path


def _run(command: list[str], cwd: Path) -> None:
    result = subprocess.run(
        command, cwd=cwd, capture_output=True, text=True, check=False
    )
    assert result.returncode == 0, (
        f"{' '.join(command)} failed\n{result.stdout[-4000:]}\n{result.stderr[-4000:]}"
    )


@pytest.fixture(scope="module")
def threat_dragon_checkout() -> Iterator[Path]:
    git = _tool("git")
    _tool("node")
    npm = _tool("npm")
    supplied = os.environ.get("THREAT_DRAGON_CHECKOUT")
    if supplied:
        yield Path(supplied)
        return
    with tempfile.TemporaryDirectory(
        prefix="hve-threat-dragon-", ignore_cleanup_errors=True
    ) as temp_dir:
        checkout = Path(temp_dir)
        _run([git, "init", "--quiet"], checkout)
        _run([git, "remote", "add", "origin", UPSTREAM], checkout)
        _run([git, "fetch", "--depth", "1", "origin", PINNED_COMMIT], checkout)
        _run([git, "checkout", "--detach", "--quiet", "FETCH_HEAD"], checkout)
        _run([npm, "ci"], checkout / "td.vue")
        yield checkout


def test_given_golden_models_when_loaded_by_pinned_threat_dragon_then_they_render(
    threat_dragon_checkout: Path,
) -> None:
    # Arrange
    head = subprocess.run(
        [_tool("git"), "rev-parse", "HEAD"],
        cwd=threat_dragon_checkout,
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    assert head == PINNED_COMMIT
    harness_dir = threat_dragon_checkout / HARNESS_SUBDIR
    fixture_dir = harness_dir / "fixtures"
    fixture_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(HARNESS_SPEC, harness_dir / HARNESS_SPEC.name)
    goldens = sorted(GOLDEN_DIR.glob("*.json"))
    assert goldens
    for golden in goldens:
        shutil.copy2(golden, fixture_dir / golden.name)

    # Act
    try:
        jest = threat_dragon_checkout / "td.vue" / "node_modules" / "jest" / "bin"
        result = subprocess.run(
            [
                _tool("node"),
                str(jest / "jest.js"),
                "--runTestsByPath",
                (HARNESS_SUBDIR.relative_to("td.vue") / HARNESS_SPEC.name).as_posix(),
                "--runInBand",
                "--collectCoverage=false",
            ],
            cwd=threat_dragon_checkout / "td.vue",
            capture_output=True,
            text=True,
            check=False,
        )
    finally:
        shutil.rmtree(harness_dir, ignore_errors=True)

    # Assert
    assert result.returncode == 0, f"{result.stdout[-6000:]}\n{result.stderr[-6000:]}"
