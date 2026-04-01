---
title: Design Principles
description: Design principle rationale and examples for Section 9 of the python-foundational skill
author: microsoft/hve-core
ms.date: 2026-03-27
ms.topic: reference
keywords:
  - python
  - coding-standards
  - design-principles
estimated_reading_time: 3
---

# Design Principles

Rationale and examples for Section 9 (Design Principles) of the python-foundational skill.

## DRY

Duplication causes maintenance failures and subtle bugs. Extract repeated logic to a single source of truth.

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

Introduce abstractions only when multiple implementations actually exist. Avoid premature complexity.

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

Some "dead" code is intentionally unused (e.g. framework hooks, public APIs, protocols). Verify before removal.

Before removing seemingly dead code, check whether it falls into one of these categories. If uncertain, flag it in a review comment rather than deleting it.

### When NOT to Clean Up Adjacent Code

Do not clean up unrelated style issues in the same change — it bloats the diff and risks regression. Flag separately.

The correct action: leave it alone. If the inconsistency is worth fixing, mention it as a separate finding. Every changed line in a review should trace directly to the stated purpose of the change.

## Approach Proportionality

Solve the problem at the narrowest reasonable scope. Avoid architectural changes that the task does not require.

### Example of a Disproportionate Change

A task asks to deduplicate a validation function used in two endpoints.

A disproportionate response: introducing a cross-module event system where endpoints emit validation events, a central dispatcher routes them, and a shared handler processes them. This adds three new modules, an event schema, and a registration mechanism to solve a problem that a single shared function would handle.

A proportionate response: extracting the duplicated validation into a helper function in the same package and calling it from both endpoints.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
