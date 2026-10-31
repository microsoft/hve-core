---
title: hve-slides
description: "Create, update, review or render presentation-first HTML slide decks. Use for slide content research, deck styling, VS Code-style walkthroughs, presenter controls, or render-only standalone HTML delivery from authored sources in repository and installed workflows."
sidebar_position: 7
author: Microsoft
ms.date: 2026-10-27
ms.topic: reference
keywords:
  - skill
  - experimental
  - hve-slides
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/skills/experimental/hve-slides`                                     |
| Invocation  | Invoked directly as `/hve-slides`, or loaded on demand by referencing agents |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create, update, review or render presentation-first HTML slide decks. Use for slide content research, deck styling, VS Code-style walkthroughs, presenter controls, or render-only standalone HTML delivery from authored sources in repository and installed workflows.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use HVE Slides to create a source-backed HTML presentation, update an existing deck, review
its content and interactions, or render authored sources into one standalone HTML file.
The same skill serves repository, plugin and VSIX users; it retains the authoring workflow
and canonical template rather than delegating to a second rendering skill.

Select render-only mode when another workflow already owns the narrative. It does not
perform research, speech generation, frame capture, video assembly or publication.
Use the relevant media skill for those separate operations.

## Example usage

For authoring, request `/hve-slides mode=create topic="Contributor onboarding"` and supply
the audience and approved source material. The skill creates source under the caller's
`slides/<deck-slug>/` and uses its shared template for the presentation.

For existing authored source, request `/hve-slides mode=render deck=slides/onboarding output=output/onboarding.html`.
The renderer requires an approved output outside the source and skill installation, plus
Node.js and the pinned reveal.js installation in the source directory. Missing resources
or unsafe paths fail rather than yielding a partial delivery.

Bundling success is not browser, accessibility or visual-quality evidence. Validate the
delivered HTML separately before presenting or sharing; no publication occurs implicitly.
