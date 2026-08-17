---
title: Partner Workshop Setup
description: Shared Codespaces and local VS Code setup instructions for the HVE partner workshop
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-17
ms.topic: tutorial
keywords:
  - GitHub Codespaces
  - Visual Studio Code
  - macOS
  - HVE Core All
  - workshop setup
estimated_reading_time: 8
---

## Workshop Agenda

| Item | Activity | Mode | Output |
|------|----------|------|--------|
| 1 | HVE and RPI overview | Shared | Common vocabulary and scenario |
| 2 | Environment setup and verification | Shared | Working HVE Core All installation |
| 3 | Scenario framing | Shared | Initial problem statement |
| 4 | Role exercises | Breakout | Context, requirements, experience, architecture inputs |
| 5 | Artifact integration | Shared | Requirements, backlog, and Azure diagram |
| 6 | Publication readiness | Shared | Managed App and Agent Store checklists |
| 7 | Playback and next actions | Shared | Owners, gaps, and follow-up plan |

> [!NOTE]
> These instructions use **Visual Studio Code**. The HVE Core extension is a VS Code extension. The full Visual Studio IDE is not the workshop host. Visual Studio users can keep the IDE installed and use VS Code or GitHub Codespaces for the workshop activities.

## Choose Your Setup Path

Select the setup option that fits your environment, then follow the matching steps below.

* Use Option A if you want a browser-based VS Code experience in GitHub Codespaces.
* Use Option B if you want to run VS Code locally on Windows or macOS.

## Shared Prerequisites

Before you begin either option, complete these steps:

1. Sign in to your GitHub account with GitHub Copilot access.
2. Confirm your organization permits GitHub Copilot Chat.

## Option A: GitHub Codespaces

1. Open the **Code** dropdown, select the **Codespaces** tab, and create a Codespace.
2. Wait for the browser-based VS Code window to finish loading.
3. Confirm GitHub Copilot and GitHub Copilot Chat are enabled in the Codespace.
4. Open the Extensions view from the Activity Bar.
5. Search for **HVE Core All**, confirm the publisher is `ISE-HVE-ESSENTIALS`, and install it in the Codespace.
6. Open the terminal in Codespaces and clone the workshop repository at [https://github.com/asiapartners/hve-partner-workshop](https://github.com/asiapartners/hve-partner-workshop) and open it in your chosen environment.
7. Create a branch for workshop activities before you start editing files. Use a name such as `workshop/<team-name>`.
8. Reload the window if VS Code asks you to do so.

## Option B: Local VS Code On Windows Or macOS

1. Install [Git](https://git-scm.com/downloads) and [Visual Studio Code](https://code.visualstudio.com/Download).
2. Open VS Code, open the Extensions view, and install **GitHub Copilot** and **GitHub Copilot Chat**.
3. Sign in with your GitHub account that has Copilot access.
4. Install [HVE Core All](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core-all).
5. Open the Command Palette, run **Git: Clone** on [https://github.com/asiapartners/hve-partner-workshop](https://github.com/asiapartners/hve-partner-workshop), and open it.
6. Select **Open** when cloning finishes, and select **Trust** only when you recognize the repository and facilitator.
7. Create a branch for workshop activities before you start editing files. Use a name such as `workshop/<team-name>`.

If you have Foundry local models available in your environment, prefer them for local inference. Otherwise, select `MAI-Code-1-Flash` in GitHub Copilot Chat for a more cost-effective option.

On macOS, use the same menus and buttons. Keyboard shortcuts that use `Ctrl` on Windows often use `Command` on macOS, so this workshop favors menu navigation.

## Verify The Environment

Complete these steps in either environment:

1. Open Copilot Chat from the Activity Bar.
2. Open the agent picker in the Chat view.
3. Confirm that agents such as **RPI Agent**, **BRD Builder**, **UX UI Designer**, and **System Architecture Reviewer** are visible.
4. Type `/` in Chat.
5. Confirm that RPI prompts appear.
6. Enter this prompt:

```text
Review the repository and identify the most relevant HVE Core assets for a partner workshop scenario. Summarize the likely workflow, likely agents, and any prerequisites before the team begins the role exercises.
```

If the expected agents are missing:

1. Open the Extensions view.
2. Disable **HVE Installer** if both extensions are installed.
3. Run **Developer: Reload Window** from the Command Palette.
4. Reopen Copilot Chat and check the agent picker again.
5. Use the [troubleshooting guide](troubleshooting.md) if the problem remains.

## Create The Workshop Workspace

Ask the technical lead to complete these steps:

1. Create a folder named `workshop-output` at the repository root.
2. Add six empty Markdown files using the names in the [workshop overview](partner-workshop.md#outcomes).

```text
workshop-output/
|-- 01-context-pack.md
|-- 02-requirements.md
|-- 03-experience.md
|-- 04-architecture.md
|-- 05-backlog.md
`-- 06-publication-readiness.md
```

1. Add the scenario title and team member roles to `01-context-pack.md`.
2. Do not enter credentials, personal data, customer secrets, or production content in prompts or files.
3. Commit your workshop outputs to your branch only.

> [!TIP]
> Use `.copilot-tracking/` only for temporary workflow state. Keep that folder in `.gitignore`. Create `workshop-output` at the repository root so it stays the team's reviewed, shareable result.

## Learn The Interaction Pattern

In the next step, we will use the same pattern in every role exercise:

1. Select the named agent or invoke the named skill.
2. Provide the scenario, known facts, constraints, and requested output path.
3. Ask for a first draft.
4. Review and revise the result.
5. Save only the reviewed result to `workshop-output`.
6. Hand the artifact to the next role.

Proceed to the [role guide](partner-workshop-role-tracks.md).

---
