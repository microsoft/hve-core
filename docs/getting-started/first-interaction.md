---
title: Your First Interaction
description: Talk to an HVE Core agent and see it respond in under 60 seconds
author: Microsoft
ms.date: 2026-02-19
ms.topic: tutorial
keywords:
  - getting started
  - first interaction
  - memory agent
  - github copilot
estimated_reading_time: 2
---

> [!NOTE]
> Step 1 of 4 in the [Getting Started Journey](README.md).

Before diving into workflows and methodologies, confirm that everything works.
You need one agent interaction that produces a visible result.

## Talk to the Memory Agent

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`).
2. Select the **memory** agent from the agent picker.
3. Type this prompt:

   > Remember that I am a [your role] and I'm learning HVE Core for the first
   > time.

   Replace `[your role]` with your actual role, such as *software engineer*,
   *tech lead*, *product manager*, or *designer*.

4. The agent responds and creates a file in your workspace under `memories/`.
   Open it. You'll see your role stored as a note that persists across
   sessions.

## See Memory in Action

Now verify that other agents can read what the memory agent stored.

1. Open a new Copilot Chat thread.
2. Type this prompt:

   > Explain what this repository does and how it helps someone in my role.

3. The response references your role without you mentioning it again. Copilot
   read the memory file, found your stored context, and tailored the
   explanation.

You just proved four things: HVE Core is installed, agents respond to natural
language, the memory system creates real files, and other agents use those
files to personalize their responses.

## What Is the Memory Agent?

The memory agent stores notes that persist across conversations. Agents and
prompts can read these notes to personalize their behavior. When you told it
your role, every future interaction can use that context without you repeating
it.

This is a small example of a larger pattern in HVE Core: agents produce
artifacts (files, documents, plans) rather than chat responses alone. The
artifacts carry context forward so you don't repeat yourself.

## Next Step

Now that you know agents work, try using one for real work:
[Your First Research](first-research.md).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
