---
title: demo-setup
description: Repeatable HVE Core demo setup that simulates DT Coach sessions with a customer persona and scaffolds a hi-fi prototype - Brought to you by microsoft/hve-core
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - skill
  - design-thinking
  - demo-setup
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/skills/design-thinking/demo-setup`                                  |
| Invocation  | Invoked directly as `/demo-setup`, or loaded on demand by referencing agents |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Repeatable HVE Core demo setup that simulates DT Coach sessions with a customer persona and scaffolds a hi-fi prototype - Brought to you by microsoft/hve-core
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `demo-setup` to prepare a repeatable customer, partner, workshop, or
conference demonstration of the HVE Core Design Thinking workflow. It creates
a simulated customer persona, accelerates Methods 1 through 6, and scaffolds a
runnable prototype with presenter and recording guidance.

Use the DT Coach directly for a real stakeholder engagement. The demo workflow
uses simulated responses and compressed pacing that are not appropriate when
research must come from actual participants.

## Example usage

Invoke the skill with a customer and industry:

```text
/demo-setup customer="Northwind Utilities" industry="energy" problem="Dispatchers cannot reconcile outage and crew status quickly"
```

The workflow creates a persona brief and coaching state under the project's
`.copilot-tracking/dt/` directory, guides an accelerated Design Thinking
session, and produces a browser-ready prototype with an experiment card,
fixture data, telemetry, a presenter guide, and a narrated video script.
