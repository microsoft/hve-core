---
title: Demo Material
description: Levelled HVE Core training decks, narrated videos, and browser slides from L100 to L400, rebuilt weekly when their source documents change
author: Microsoft
ms.date: 2026-09-24
ms.topic: overview
keywords:
  - demo material
  - training
  - slides
  - video
  - L100
  - L400
sidebar_position: 1
estimated_reading_time: 3
---

HVE Core publishes a training deck, a narrated video, and a browser slide deck
for each of four depth levels. Each level targets a different audience and
builds on the one before it.

| Level | Audience                                        | Length       | Watch                                                                  | Present                                                          | Download                                                                                                                     |
|-------|-------------------------------------------------|--------------|------------------------------------------------------------------------|------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| L100  | New contributors and first-time HVE Core users  | 4 to 6 min   | [L100 video and transcript](pathname:///demo-material/L100/index.html) | [L100 slides](pathname:///demo-material/L100/hve-demo-L100.html) | [L100 deck](pathname:///demo-material/L100/hve-demo-L100.pptx), [L100 MP4](pathname:///demo-material/L100/hve-demo-L100.mp4) |
| L200  | Contributors ready to follow a guided task      | 6 to 8 min   | [L200 video and transcript](pathname:///demo-material/L200/index.html) | [L200 slides](pathname:///demo-material/L200/hve-demo-L200.html) | [L200 deck](pathname:///demo-material/L200/hve-demo-L200.pptx), [L200 MP4](pathname:///demo-material/L200/hve-demo-L200.mp4) |
| L300  | Engineers choosing an applied workflow          | 8 to 10 min  | [L300 video and transcript](pathname:///demo-material/L300/index.html) | [L300 slides](pathname:///demo-material/L300/hve-demo-L300.html) | [L300 deck](pathname:///demo-material/L300/hve-demo-L300.pptx), [L300 MP4](pathname:///demo-material/L300/hve-demo-L300.mp4) |
| L400  | Maintainers and contributors extending HVE Core | 10 to 12 min | [L400 video and transcript](pathname:///demo-material/L400/index.html) | [L400 slides](pathname:///demo-material/L400/hve-demo-L400.html) | [L400 deck](pathname:///demo-material/L400/hve-demo-L400.pptx), [L400 MP4](pathname:///demo-material/L400/hve-demo-L400.mp4) |

L100 and L200 videos show the deck slides. L300 and L400 add live VS Code
captures of the repository files they discuss.

The browser slides use the same presenter controls as the [HVE Core
presentations](pathname:///slides/): arrow keys to move, a slide index, speaker
notes, the level's sources, and a reading view. Each is one self-contained HTML
file, so you can download it and present offline.

## Accessibility

Every level is published with:

* Captions embedded in the MP4 and as a separate WebVTT file, generated from the
  exact narration text
* A video page with a captioned player and a full transcript listing each
  slide's title, on-screen text, image descriptions, and narration
* Narration that voices what each slide shows and describes each live capture,
  so the audio carries the visual content
* A deck with a title on every slide, alternative text on every image, and the
  document language set, so screen readers can navigate it
* Browser slides with keyboard navigation, labelled slides, a reading view that
  reflows on small screens, and speaker notes available to every viewer
* Text colours that meet the WCAG 2.2 AA contrast minimum of 4.5:1

The render workflow checks each item it can verify and withholds a level that
fails. Caption timing within a slide is estimated from sentence length, so
captions can lead or trail the voice by a moment. Whether the narration fully
describes each visual cannot be checked by a machine and needs human review.

## How the Material Stays Current

The material is rebuilt by two scheduled workflows, and only for the levels whose
source documents changed:

1. The [Demo Material Author](https://github.com/microsoft/hve-core/blob/main/.github/workflows/demo-material-author.md)
   agentic workflow runs weekly. A deterministic step compares each level's
   pinned sources with the commit its current material was built from, and the
   agent writes new slide content only for the levels that changed. When
   nothing changed, the agent does not run.
2. The [Demo Material Render](https://github.com/microsoft/hve-core/blob/main/.github/workflows/demo-material-render.yml)
   workflow builds each authored level into a deck, narration, a video, and
   browser slides from the same slide content, then scores the checks a machine
   can verify: narration paired to every slide, the video landing inside the
   level's length, readable live captures, the pinned house style, the
   accessibility items above, and browser slides that open offline with no
   slide overflowing. A level that fails any check keeps its previous files.
3. The documentation deployment publishes the latest passing files on this page.

The narration uses an offline [Piper](https://github.com/OHF-Voice/piper1-gpl)
voice (`en_US-joe-medium`, CC0), so the builds need no cloud speech service. The
[level contracts and sources](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/hve-demo-material/references/curriculum.md)
define what each level covers.

## Build Status

The [build index](pathname:///demo-material/index.json) records, for each level,
the commit it was built from, when it was rendered, its measured length, and the
result of every check, including the most recent failed attempt.

> [!NOTE]
> The decks, videos, and slides are drafted by an AI agent from this repository's
> documentation and checked automatically, not reviewed by a person before
> publication. Review a deck before presenting it to an external audience. A
> level's links resolve after its first successful render.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
