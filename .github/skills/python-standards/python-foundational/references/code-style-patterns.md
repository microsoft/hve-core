---
title: Code Style Patterns
description: Concrete before/after examples for Sections 1 through 5 of the python-foundational skill checklist
author: microsoft/hve-core
ms.date: 2026-03-27
ms.topic: reference
keywords:
  - python
  - coding-standards
  - code-patterns
estimated_reading_time: 4
---

# Code Style Patterns

Concrete examples for Sections 1–5 of the `python-foundational` skill checklist. The SKILL.md defines what to check; this file illustrates each rule with before/after code.

## Naming Conventions

Python naming conventions eliminate ambiguity about what an identifier represents.

```python
# Classes: PascalCase
class ModelTrainer:
    pass

# Functions and variables: snake_case
def train_model():
    training_data = []

# Constants: UPPER_SNAKE_CASE
MAX_SEQUENCE_LENGTH = 2048
DEFAULT_LEARNING_RATE = 1e-4

# Private members: leading underscore
def _internal_helper():
    pass

_internal_cache = {}
```

## Import Organization

The three-tier grouping makes dependency boundaries visible at a glance: what comes from the standard library, what comes from third-party packages, and what is local to the project.

```python
# 1. Standard library
import os
import sys
from pathlib import Path

# 2. Third-party
import numpy as np
from anthropic import Anthropic

# 3. Local
from myproject.core.trainer import Trainer
from myproject.utils.config import load_config
```

## Keyword-Only Arguments

The `*` separator forces callers to name optional parameters, preventing silent positional misassignment when a function has multiple options of the same type.

### Before

```python
def train(data: list, learning_rate: float = 1e-4, batch_size: int = 32):
    pass

# Caller can silently swap learning_rate and batch_size
train(data, 32, 1e-4)
```

### After

```python
def train(
    data: list,
    *,
    learning_rate: float = 1e-4,
    batch_size: int = 32,
) -> None:
    pass

# Caller must name each optional parameter
train(data, learning_rate=1e-3, batch_size=64)
```

## Type Hints

Type annotations turn implicit assumptions into machine-checkable contracts, catching mismatched types before runtime and enabling richer IDE support.

### Function Signatures

```python
def fetch_records(
    query: str,
    *,
    limit: int = 100,
    include_deleted: bool = False,
) -> list[dict[str, str]]:
    """Fetch records matching a query."""
    ...


def find_user(user_id: int) -> User | None:
    """Return the user or None if not found."""
    ...
```

### Dataclass with Typed Attributes

```python
from dataclasses import dataclass, field
from typing import ClassVar


@dataclass
class TrainingConfig:
    """Configuration for a training run."""

    model_name: str
    learning_rate: float = 1e-4
    batch_size: int = 32
    tags: list[str] = field(default_factory=list)

    MAX_EPOCHS: ClassVar[int] = 100
```

## Docstrings

Docstrings capture intent and contracts that code alone cannot express: parameter constraints, exception triggers, and return semantics. Consistent docstrings across a project also power IDE tooltips and automated documentation generators.

### Function Docstring

```python
def process_data(
    data: list[dict],
    *,
    batch_size: int = 32,
    validate: bool = True,
) -> ProcessResult:
    """Process data with validation and batching.

    Args:
        data: Input data as list of dicts with 'id' and 'content' keys.
        batch_size: Number of items to process per batch.
        validate: Whether to validate input data.

    Returns:
        ProcessResult containing processed items, errors, and metrics.

    Raises:
        ValueError: If data is empty or has an invalid format.
    """
```

### Class Docstring

```python
class DataProcessor:
    """Data processing orchestrator for batch operations.

    Handles the complete data processing workflow including validation,
    transformation, batching, and error handling.

    Args:
        config: Processing configuration.
        batch_size: Number of items per batch.

    Attributes:
        config: Processing configuration.
        batch_size: Configured batch size.
        metrics: Processing metrics tracker.
    """

    def __init__(self, config: APIConfig, *, batch_size: int = 32) -> None:
        self.config = config
        self.batch_size = batch_size
        self.metrics = MetricsTracker()
```

## Error Messages

Generic error messages force the caller to reproduce the failure, attach a debugger, and walk the call stack just to understand what went wrong. A specific message surfaces the root cause immediately and cuts debugging time.

### Before

```python
def load_config(path):
    if not path.exists():
        raise FileNotFoundError("File not found")
```

### After

```python
def load_config(path: Path) -> dict:
    """Load configuration file."""
    if not path.exists():
        raise FileNotFoundError(
            f"Config file not found: {path}\n"
            f"Expected YAML file with keys: model, data, training\n"
            f"See example: docs/examples/config.yaml"
        )

    try:
        with open(path) as f:
            return yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise ValueError(
            f"Invalid YAML in config file: {path}\n"
            f"Error: {e}"
        ) from e
```

## Custom Exception Hierarchies

In applications with multiple error categories, a base application exception enables callers to catch broad or narrow as needed. Derive specific exceptions from it rather than raising bare `Exception` or `ValueError` for domain-specific errors.

```python
class AppError(Exception):
    """Base exception for the application."""

class ConfigError(AppError):
    """Configuration error."""

class ValidationError(AppError):
    """Validation error."""

def validate_config(config: dict) -> None:
    """Validate configuration."""
    required = ["database", "api_key", "settings"]
    missing = [k for k in required if k not in config]
    if missing:
        raise ConfigError(
            f"Missing required config keys: {missing}\n"
            f"Required: {required}"
        )
```

## Class Member Organization

A suggested ordering convention that improves scanability. Follow the codebase's established convention when one exists.

```python
class Model:
    """Model class."""

    # 1. Class variables
    DEFAULT_LR = 1e-4

    # 2. __init__
    def __init__(self, name: str) -> None:
        self.name = name

    # 3. Public methods
    def train(self, data: list) -> None:
        """Public training method."""
        pass

    # 4. Private methods
    def _prepare_data(self, data: list) -> list:
        """Private helper method."""
        pass

    # 5. Properties
    @property
    def num_parameters(self) -> int:
        """Number of trainable parameters."""
        return sum(p.size for p in self.parameters())
```

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
