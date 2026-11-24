# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Exercise uv restore behavior using synthetic wheels and loopback-only indexes."""

import argparse
import hashlib
import io
import json
import os
import shutil
import subprocess
import tempfile
import threading
import zipfile
from functools import partial
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def make_wheel(name: str, *, value: int = 1) -> bytes:
    """Build a minimal, dependency-free wheel without a build backend."""
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr(f"{name}/__init__.py", f"VALUE = {value}\n")
        archive.writestr(
            f"{name}-1.0.dist-info/METADATA",
            f"Metadata-Version: 2.1\nName: {name}\nVersion: 1.0\n",
        )
        archive.writestr(
            f"{name}-1.0.dist-info/WHEEL",
            "Wheel-Version: 1.0\nGenerator: fixture\nRoot-Is-Purelib: true\nTag: py3-none-any\n",
        )
        archive.writestr(f"{name}-1.0.dist-info/RECORD", "")
    return buffer.getvalue()


class IndexHandler(BaseHTTPRequestHandler):
    """Serve isolated default and explicit package namespaces and record requests."""

    def __init__(self, *args: object, state: dict, **kwargs: object) -> None:
        self.state = state
        super().__init__(*args, **kwargs)

    def do_GET(self) -> None:
        """Return simple-index pages or synthetic wheel bytes."""
        self.state["requests"].append(self.path)
        parts = self.path.strip("/").split("/")
        namespace = parts[0]
        name = parts[-1].replace("-", "_")
        allowed = (
            "mirror_bound" if namespace.startswith("explicit") else "mirror_default"
        )
        if name.endswith(".whl"):
            content = self.state["wheels"][allowed]
            if self.state["corrupt"] and namespace == "mirror":
                content = make_wheel(allowed, value=2)
        elif len(parts) == 3 and name == allowed:
            wheel = f"{allowed}-1.0-py3-none-any.whl"
            digest = hashlib.sha256(self.state["wheels"][allowed]).hexdigest()
            content = (
                f'<a href="/{namespace}/{wheel}#sha256={digest}">{wheel}</a>'.encode()
            )
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header(
            "Content-Type",
            "application/octet-stream" if name.endswith(".whl") else "text/html",
        )
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(content)

    def do_HEAD(self) -> None:
        """Expose wheel metadata without a response body."""
        self.do_GET()

    def log_message(self, format: str, *args: object) -> None:
        """Keep HTTP diagnostics in the structured request record."""


def run(
    command: list[str], project: Path, environment: dict[str, str]
) -> subprocess.CompletedProcess:
    """Run a bounded fixture command with complete captured diagnostics."""
    return subprocess.run(
        command,
        cwd=project,
        env=environment,
        capture_output=True,
        text=True,
        timeout=90,
        check=False,
    )


def require(result: subprocess.CompletedProcess, *, success: bool = True) -> None:
    """Assert command status, retaining diagnostics on unexpected results."""
    if (result.returncode == 0) != success:
        raise AssertionError(
            f"Unexpected exit {result.returncode}: {result.stdout}\n{result.stderr}"
        )


def create_project(
    root: Path, base: str, environment: dict[str, str], *, explicit: bool
) -> Path:
    """Generate a project and canonical stand-in lock against the local upstream."""
    project = root / ("explicit-project" if explicit else "default-project")
    project.mkdir(exist_ok=True)
    dependencies = (
        '["mirror-default==1.0", "mirror-bound==1.0"]'
        if explicit
        else '["mirror-default==1.0"]'
    )
    content = (
        '[project]\nname = "fixture"\nversion = "1.0"\nrequires-python = ">=3.11"\n'
        f"dependencies = {dependencies}\n"
    )
    if explicit:
        content += (
            '\n[[tool.uv.index]]\nname = "bound"\n'
            f'url = "{base}/explicit/simple"\nexplicit = true\n'
            '\n[tool.uv.sources]\nmirror-bound = { index = "bound" }\n'
        )
    (project / "pyproject.toml").write_text(content, encoding="utf-8")
    require(
        run(
            ["uv", "lock", "--default-index", f"{base}/public/simple"],
            project,
            environment,
        )
    )
    return project


def exercise(root: Path, base: str, state: dict, arguments: argparse.Namespace) -> dict:
    """Probe candidates or exercise the real Bash/PowerShell provisioning path."""
    environment = {
        key: value for key, value in os.environ.items() if not key.startswith("UV_")
    }
    environment.update(UV_PYTHON_DOWNLOADS="never", UV_CACHE_DIR=str(root / "cache"))
    version = run(["uv", "--version"], root, environment).stdout.strip()
    project = create_project(
        root, base, environment, explicit=arguments.mode == "probe"
    )
    lock = project / "uv.lock"
    if arguments.mode == "probe":
        results = []
        for override in (False, True):
            shutil.rmtree(root / "cache", ignore_errors=True)
            shutil.rmtree(project / ".venv", ignore_errors=True)
            state["requests"].clear()
            environment["UV_DEFAULT_INDEX"] = f"{base}/mirror/simple"
            if override:
                environment["UV_INDEX"] = f"bound={base}/explicit-mirror/simple"
            result = run(["uv", "sync", "--frozen"], project, environment)
            results.append(
                {
                    "named_override": override,
                    "exit": result.returncode,
                    "requests": state["requests"][:],
                }
            )
        return {"version": version, "candidates": results}

    lock.write_text(
        lock.read_text(encoding="utf-8").replace(f"{base}/public", "https://pypi.org"),
        encoding="utf-8",
    )
    original_lock = lock.read_bytes()
    environment["UV_DEFAULT_INDEX"] = f"{base}/mirror/simple"
    repo = Path(__file__).resolve().parents[4]
    if arguments.mode == "bash":
        command = [
            "bash",
            "-c",
            'source "$1"; if ! sync_python_project "$2"; then exit 1; fi',
            "fixture",
            str(repo / ".devcontainer/scripts/on-create.sh"),
            str(project),
        ]
    else:
        script = repo / "scripts/linting/Invoke-PythonTests.ps1"
        command = [
            "pwsh",
            "-NoProfile",
            "-Command",
            (
                f". '{script}'; $result = Invoke-UvEnvironmentSync -Locked $true; "
                "$result.output | Out-Host; exit $result.exitCode"
            ),
        ]
    state["requests"].clear()
    shutil.rmtree(root / "cache", ignore_errors=True)
    require(run(command, project, environment))
    success_requests = state["requests"][:]
    if not success_requests or any(
        not request.startswith("/mirror/") for request in success_requests
    ):
        raise AssertionError(f"Restore did not use only the mirror: {success_requests}")
    require(
        run(
            [
                "uv",
                "run",
                "--offline",
                "--no-sync",
                "python",
                "-c",
                "import mirror_default",
            ],
            project,
            environment,
        )
    )
    if lock.read_bytes() != original_lock:
        raise AssertionError("Provisioning modified the canonical lock")

    shutil.rmtree(root / "cache", ignore_errors=True)
    shutil.rmtree(project / ".venv")
    state["corrupt"] = True
    mismatch = run(command, project, environment)
    require(mismatch, success=False)
    if "hash" not in (mismatch.stdout + mismatch.stderr).lower():
        raise AssertionError("Expected hash mismatch diagnostics")
    state["corrupt"] = False

    explicit_project = create_project(root, base, environment, explicit=True)
    state["requests"].clear()
    explicit_command = [
        argument.replace(str(project), str(explicit_project)) for argument in command
    ]
    require(run(explicit_command, explicit_project, environment), success=False)
    if state["requests"]:
        raise AssertionError(
            f"Unsupported explicit source leaked requests: {state['requests']}"
        )
    return {
        "version": version,
        "mode": arguments.mode,
        "mirror_requests": success_requests,
        "clean_environment": True,
        "hash_rejected": True,
        "explicit_requests": state["requests"],
    }


def create_parser() -> argparse.ArgumentParser:
    """Define the single harness entry point."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--mode", choices=("probe", "bash", "powershell"), required=True
    )
    return parser


def main() -> int:
    """Run the fixture and emit a JSON evidence summary."""
    arguments = create_parser().parse_args()
    state = {
        "requests": [],
        "corrupt": False,
        "wheels": {
            name: make_wheel(name) for name in ("mirror_default", "mirror_bound")
        },
    }
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(IndexHandler, state=state))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory(prefix="uv-controlled-") as directory:
            result = exercise(
                Path(directory),
                f"http://127.0.0.1:{server.server_port}",
                state,
                arguments,
            )
        print(json.dumps(result))
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
