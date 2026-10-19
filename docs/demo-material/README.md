---
title: Demo Material
description: Levelled HVE Core training decks, silent CI videos, and browser slides from L100 to L400, rebuilt weekly when their source documents change
author: Microsoft
ms.date: 2026-10-09
ms.topic: overview
keywords:
  - demo material
  - training
  - slides
  - video
  - L100
  - L400
sidebar_position: 1
sidebar_label: Overview
sidebar_custom_props:
  accessibleName: "Overview: Demo Material"
pagination_label: Demo Material
estimated_reading_time: 3
---

HVE Core publishes a training deck, a video, and a browser slide deck
for each of four depth levels. Each level targets a different audience and
builds on the one before it. The catalog reads the published build index and
shows links only when that level has a complete passing bundle.

<!-- markdownlint-disable-next-line MD033 -->
<DemoMaterialCatalog />

L100 and L200 videos show the deck slides. L300 and L400 add live VS Code
captures of the repository files they discuss.

The browser slides use the same presenter controls as the [HVE Core
presentations](pathname:///slides/): arrow keys to move, a slide index, speaker
notes, the level's sources, and a reading view. Each is one self-contained HTML
file, so you can download it and present offline.

## Accessibility

Every level is published with:

* Visible text embedded in the MP4 and as a separate WebVTT file, generated from
  the authored speaker notes
* A video page with a captioned player and a full transcript listing each
  slide's title, on-screen text, image descriptions, and narration
* A text transcript describing each slide and live capture; new CI videos have
  no voiceover or audio stream
* A deck with a title on every slide, alternative text on every image, and the
  document language set, so screen readers can navigate it
* Browser slides with keyboard navigation, labelled slides, a reading view that
  reflows on small screens, and speaker notes available to every viewer
* Text colors that meet the WCAG 2.2 AA contrast minimum of 4.5:1

The render workflow checks each item it can verify and withholds a level that
fails. Silent CI timing is derived from the notes' word count, not synthesized
speech. A human must review reading pace and whether the transcript fully
describes each visual. Silent videos do not provide spoken audio description.

## How the Material Stays Current

The material is rebuilt by two scheduled workflows, and only for the levels whose
source documents changed:

1. The [Demo Material Author](https://github.com/microsoft/hve-core/blob/main/.github/workflows/demo-material-author.md)
  agentic workflow runs weekly. A deterministic step compares each level's
  pinned sources with the commit its current material was built from. The
  agent writes new slide content for changed, failed, or unpublished levels.
  When every level is current and published, the agent does not run.
2. The [Demo Material Render](https://github.com/microsoft/hve-core/blob/main/.github/workflows/demo-material-render.yml)
  workflow builds each authored level into a deck, a silent video, and
   browser slides from the same slide content, then scores the checks a machine
  can verify: timing paired to every slide, absence of an audio stream, the video landing inside the
   level's length, readable live captures, the pinned house style, the
   accessibility items above, and browser slides that open offline with no
  slide overflowing. A level that fails any check keeps its previous files.
  The later weekly render check forces another authoring attempt for any level
  whose latest attempt failed or whose first passing bundle is still missing.
3. The documentation deployment publishes the latest passing files. This page
  reads that same index, so a missing level appears as unavailable rather than
  linking to files that do not exist.

New CI builds are silent: neither Piper nor Azure Speech is used for synthesis.
For local narrated production, Azure AI Speech is the default; Piper remains an
explicit optional choice subject to applicable review and approval. During
regeneration, a level may retain an earlier passing video with voiceover until
its silent replacement passes. The published index records `narration_engine`
and the timing basis for new renders. The
[level contracts and sources](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/hve-demo-material/references/curriculum.md)
define what each level covers.

## Build Status

The [build index](pathname:///demo-material/index.json) records, for each level,
the commit it was built from, when it was rendered, its measured length, and the
result of every check, including the most recent failed attempt.

> [!NOTE]
> The decks, videos, and slides are drafted by an AI agent from this repository's
> documentation and checked automatically, not reviewed by a person before
> publication. Review a deck before presenting it to an external audience. An
> unavailable level exposes no media links until its first successful render.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
