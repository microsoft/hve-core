---
title: Foundational Coding Guidelines - Extended Rationale
description: Design principle rationale and before/after code examples for the python-foundational skill
author: Microsoft
ms.date: 2026-03-23
ms.topic: reference
keywords:
  - python
  - coding-standards
  - design-principles
estimated_reading_time: 3
---

# Foundational Coding Guidelines: Extended Rationale

Extended guidance for the Design Principles in the `python-foundational` skill. The SKILL.md checklist defines what to check; this file explains why and provides concrete examples.

## DRY

Duplication is the root cause of many maintenance failures. When the same logic appears in two places, a fix applied to one location often misses the other, creating subtle inconsistencies that surface as bugs weeks later.

### Before

```python
def create_user(data: dict) -> User:
    if not data.get("email") or "@" not in data["email"]:
        raise ValueError("Invalid email")
    if not data.get("name") or len(data["name"]) < 2:
        raise ValueError("Invalid name")
    return User(**data)

def update_user(user: User, data: dict) -> User:
    if not data.get("email") or "@" not in data["email"]:
        raise ValueError("Invalid email")
    if not data.get("name") or len(data["name"]) < 2:
        raise ValueError("Invalid name")
    user.email = data["email"]
    user.name = data["name"]
    return user
```

### After

```python
def _validate_user_fields(data: dict) -> None:
    if not data.get("email") or "@" not in data["email"]:
        raise ValueError("Invalid email")
    if not data.get("name") or len(data["name"]) < 2:
        raise ValueError("Invalid name")

def create_user(data: dict) -> User:
    _validate_user_fields(data)
    return User(**data)

def update_user(user: User, data: dict) -> User:
    _validate_user_fields(data)
    user.email = data["email"]
    user.name = data["name"]
    return user
```

The validation rules now live in one place. A future change to email validation propagates automatically.

## Simplicity First

Over-engineering manifests as abstractions, configurability, or generalization that the current requirements do not call for. The cost is immediate (more code to review, test, and maintain) and compounds over time as future contributors must understand the abstraction before modifying behavior.

### Before

```python
class NotificationStrategy(Protocol):
    def send(self, message: str, recipient: str) -> None: ...

class EmailNotifier:
    def __init__(self, strategy: NotificationStrategy) -> None:
        self.strategy = strategy

    def notify(self, message: str, recipient: str) -> None:
        self.strategy.send(message, recipient)

class SmtpStrategy:
    def send(self, message: str, recipient: str) -> None:
        smtp_client.send_email(recipient, message)

# Usage
notifier = EmailNotifier(SmtpStrategy())
notifier.notify("Hello", "user@example.com")
```

### After

```python
def send_email(message: str, recipient: str) -> None:
    smtp_client.send_email(recipient, message)
```

When only one notification channel exists, the strategy pattern adds indirection without benefit. Introduce abstractions when a second implementation actually appears, not before.

## Surgical Changes

Some code appears unused but exists for valid reasons. Protocol implementations, framework hooks, public APIs, and CLI entry points may have no visible in-repo callers because they are invoked externally (by a framework, a consumer package, or the runtime).

Before removing seemingly dead code, check whether it falls into one of these categories. If uncertain, flag it in a review comment rather than deleting it.

### When NOT to Clean Up Adjacent Code

A reviewer encounters a function with a minor style inconsistency adjacent to the lines they are modifying. The inconsistency predates the current change. Cleaning it up would expand the diff, obscure the actual intent of the change, and risk introducing a subtle regression in untested code.

The correct action: leave it alone. If the inconsistency is worth fixing, mention it as a separate finding. Every changed line in a review should trace directly to the stated purpose of the change.

## Approach Proportionality

A proportionate change solves the stated problem at the narrowest reasonable scope. Disproportionate changes introduce coordination overhead or architectural shifts that the problem does not require.

### Example of a Disproportionate Change

A task asks to deduplicate a validation function used in two endpoints.

A disproportionate response: introducing a cross-module event system where endpoints emit validation events, a central dispatcher routes them, and a shared handler processes them. This adds three new modules, an event schema, and a registration mechanism to solve a problem that a single shared function would handle.

A proportionate response: extracting the duplicated validation into a helper function in the same package and calling it from both endpoints.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
