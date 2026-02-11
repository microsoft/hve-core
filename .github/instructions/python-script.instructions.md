---
applyTo: '**/*.py'
description: 'Instructions for Python scripting implementation - Brought to you by microsoft/hve-core'
maturity: stable
---

# Python Script Instructions

Conventions for Python 3.11+ scripts used in automation, tooling, and CLI applications.

## Entry Points and Exit Codes

```python
import sys

EXIT_SUCCESS = 0  # Successful execution
EXIT_FAILURE = 1  # General failure
EXIT_ERROR = 2    # Arguments or configuration error


def main() -> int:
    """Main entry point for the script."""
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
```

Standard exit codes: 0 success, 1 failure, 2 configuration error, 130 user interrupt (SIGINT).

## CLI Argument Parsing

### argparse

Extract parser creation into a separate function for testability.

```python
import argparse
from pathlib import Path


def create_parser() -> argparse.ArgumentParser:
    """Create and configure argument parser."""
    parser = argparse.ArgumentParser(description="Process files")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-o", "--output", type=Path, default=Path("output.txt"))
    parser.add_argument("input_file", type=Path)
    return parser
```

Use `type=Path` for file arguments and `action="store_true"` for boolean flags.

### click

For complex CLIs with subcommands or interactive prompts, use the *click* framework.

```python
import click


@click.command()
@click.option("-v", "--verbose", is_flag=True)
@click.argument("input_file", type=click.Path(exists=True))
@click.pass_context
def main(ctx: click.Context, verbose: bool, input_file: str) -> None:
    """Process input files."""
    ctx.exit(0)  # Explicit exit code
```

Use `@click.group()` for subcommands, `ctx.exit(code)` for exit codes, and `ctx.fail(message)` for errors.

## Logging Configuration

```python
import logging

logger = logging.getLogger(__name__)


def configure_logging(verbose: bool = False) -> None:
    """Configure logging based on verbosity level."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(level=level, format="%(levelname)s: %(message)s")
```

Create module-level logger, configure early in main. For file logging, add *FileHandler* to the root logger.

## Path Handling

Use *pathlib.Path* exclusively; avoid *os.path*.

```python
from pathlib import Path


def process_file(path: Path) -> None:
    """Read, process, and write file content."""
    content = path.read_text(encoding="utf-8")
    processed = transform_content(content)
    output_path = path.with_suffix(".out")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(processed, encoding="utf-8")
```

Common patterns: `cwd()`, `resolve()`, `exists()`, `is_dir()`, `is_file()`, `iterdir()`, `glob()`, `rglob()`, `read_text()`, `write_text()`, `mkdir(parents=True, exist_ok=True)`, `parent`, `name`, `stem`, `suffix`.

## Subprocess Execution

Use *subprocess.run()* with error handling.

```python
import subprocess
import os
from pathlib import Path


def run_command(cmd: list[str], cwd: Path | None = None, extra_env: dict[str, str] | None = None) -> str:
    """Run command and return stdout, raising on failure."""
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, cwd=cwd, env=env)
        return result.stdout
    except subprocess.CalledProcessError as e:
        logger.error("Command failed: %s\nstderr: %s", e.returncode, e.stderr)
        raise
    except FileNotFoundError:
        logger.error("Command not found: %s", cmd[0])
        raise
```

Use `capture_output=True` and `text=True` for string output. Use `check=True` to raise on non-zero exit.

## Type Hints

Use Python 3.11+ syntax with built-in generics.

```python
from pathlib import Path
from typing import Literal, Self


def process_items(items: list[str]) -> dict[str, int]:  # Built-in generics
    return {item: len(item) for item in items}


def read_file(path: str | Path) -> str:  # Union with pipe
    return Path(path).read_text(encoding="utf-8")


def find_config(name: str) -> Path | None:  # Optional with pipe
    config = Path(name)
    return config if config.exists() else None


def set_level(level: Literal["debug", "info", "warning"]) -> None:  # Constrained values
    pass


class Builder:
    def add(self, item: str) -> Self:  # Fluent interface
        self.items.append(item)
        return self
```

Use `list[str]` not `typing.List[str]`, `str | None` not `Optional[str]`, `Literal` for constrained values, `Self` for chained methods.

## Error Handling

Handle interrupts and pipe errors at the top level.

```python
import sys


def main() -> int:
    """Main entry point with error handling."""
    try:
        return run()
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        return 130
    except BrokenPipeError:
        sys.stderr.close()
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
```

Custom exceptions can carry exit codes:

```python
class ScriptError(Exception):
    def __init__(self, message: str, exit_code: int = 1) -> None:
        super().__init__(message)
        self.exit_code = exit_code
```

## Documentation

Use Google-style docstrings with Args, Returns, Raises, and Example sections.

```python
def process_data(data: list[str], *, normalize: bool = False) -> dict[str, int]:
    """Process input data and return statistics.

    Args:
        data: List of strings to process.
        normalize: If True, normalize values before processing.

    Returns:
        Dictionary mapping processed items to their counts.

    Raises:
        ValueError: If data is empty.

    Example:
        >>> process_data(["a", "b", "a"])
        {'a': 2, 'b': 1}
    """
```

Include module docstrings with description, usage, and examples.

## Script Organization

Organize scripts in this order:

1. Shebang: `#!/usr/bin/env python3`
2. Future imports: `from __future__ import annotations`
3. Imports: standard library, third-party, local (separated by blank lines)
4. Constants and exit codes
5. Module-level logger
6. Helper functions
7. Parser creation function
8. Logging configuration function
9. Run logic function
10. Main entry point
11. Module guard: `if __name__ == "__main__": sys.exit(main())`

## Inline Script Metadata

PEP 723 inline metadata enables automatic dependency installation with *uv*.

```python
#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "click>=8.0",
#     "rich>=13.0",
# ]
# ///
```

Place after shebang, before module docstring. Run with `uv run script.py`.
