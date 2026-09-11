---
title: powerpoint
description: PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - experimental
  - powerpoint
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/skills/experimental/powerpoint`                                     |
| Invocation  | Invoked directly as `/powerpoint`, or loaded on demand by referencing agents |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill for YAML-driven deck creation, extraction, selected-slide updates,
theme variants, audio embedding, and slide export. Supply per-slide `content.yaml`
and global `style.yaml`, or an existing PPTX to extract. For canonical Design
Thinking cards, let `customer-card-render` perform the mapping first.

Building needs Python 3.11+, `uv`, and PowerShell 7+ for the orchestrator. Export
and pipeline validation need LibreOffice; optional vision checks additionally
need authenticated Copilot model access. A build result alone is not visual validation.

## Example usage

Ask: `/powerpoint Build a sample three-slide service overview from content/ and
content/global/style.yaml into output/overview.pptx. Use YAML-only drawings and
report which checks actually ran.` Include speaker notes and approved images.
Expect slides in numeric directory order and a deck whose slide count, notes,
geometry, and rendered readability can be checked separately.

For an existing deck, ask to extract and rebuild only slide 3 while preserving
the others. That route uses `--source` (or `-SourcePath`) and a slide selection,
not `--template`: a template build inherits masters, layouts, and theme but
discards existing slides. Success includes unchanged unselected slides and the
original slide count; validate neighboring slides as well as the changed slide.

Custom `content-extra.py` execution is disabled by default and requires review
plus explicit `--allow-scripts` authorization. Its AST lint is not a sandbox.
Treat imported binaries as untrusted, confirm output destinations, and do not
claim vision validation when model access or export prerequisites were unavailable.
