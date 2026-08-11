---
title: Partner Workshop Setup
description: Shared Codespaces and local VS Code setup instructions for the two-hour HVE partner workshop
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-11
ms.topic: tutorial
keywords:
  - GitHub Codespaces
  - Visual Studio Code
  - macOS
  - HVE Core All
  - workshop setup
estimated_reading_time: 8
---

Use GitHub Codespaces when possible. It gives Windows and macOS participants the
same browser-based environment and avoids local tool installation during the
two-hour session.

> [!NOTE]
> These instructions use **Visual Studio Code**. The HVE Core extension is a VS
> Code extension. The full Visual Studio IDE is not the workshop host. Visual
> Studio users can keep the IDE installed and use VS Code or Codespaces for the
> workshop activities.

## Shared Prerequisites

Before the session, complete these steps:

1. Sign in to the GitHub account that has repository and Copilot access.
2. Confirm you can open the workshop repository.
3. Confirm your organization permits GitHub Copilot Chat.
4. Decide whether to use Codespaces or local VS Code.
5. Ask the facilitator for the team scenario and backlog target.

## Option A: GitHub Codespaces

1. Open the workshop repository on GitHub.
2. Select **Code**.
3. Select the **Codespaces** tab.
4. Select **Create codespace on main**, or choose the branch named by the
   facilitator.
5. Wait for the browser-based VS Code window to finish loading.
6. Open the Extensions view from the Activity Bar.
7. Search for **HVE Core All**.
8. Confirm the publisher is `ise-hve-essentials`.
9. Select **Install in Codespaces**.
10. Confirm GitHub Copilot and GitHub Copilot Chat are enabled in the Codespace.
11. Reload the window if VS Code asks you to do so.

## Option B: Local VS Code On Windows Or macOS

1. Install [Git](https://git-scm.com/downloads).
2. Install [Visual Studio Code](https://code.visualstudio.com/Download).
3. Open VS Code.
4. Open the Extensions view.
5. Install **GitHub Copilot** and **GitHub Copilot Chat**.
6. Sign in with the GitHub account that has Copilot access.
7. Install
   [HVE Core All](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core-all).
8. Open the Command Palette.
9. Run **Git: Clone**.
10. Paste the workshop repository URL.
11. Choose a local folder and select **Open** when cloning finishes.
12. Select **Trust** only when you recognize the repository and facilitator.

On macOS, use the same menus and buttons. Keyboard shortcuts that use `Ctrl` on
Windows often use `Command` on macOS, so this workshop favors menu navigation.

## Verify HVE Core

Complete these steps in either environment:

1. Open Copilot Chat from the Activity Bar.
2. Open the agent picker in the Chat view.
3. Confirm that agents such as **RPI Agent**, **BRD Builder**, **Agile Coach**,
   **UX UI Designer**, and **System Architecture Reviewer** are visible.
4. Type `/` in Chat.
5. Confirm that RPI prompts appear.
6. Enter this prompt:

   ```text
   List the HVE Core agents and skills available for requirements, backlog
   planning, user experience, and architecture. Do not modify files.
   ```

7. Compare the response with your assigned role.

If the expected agents are missing:

1. Confirm **HVE Core All** is installed in the current environment.
2. Disable **HVE Installer** if both extensions are installed.
3. Run **Developer: Reload Window** from the Command Palette.
4. Reopen Copilot Chat and check the agent picker again.
5. Use the [troubleshooting guide](troubleshooting) if the problem remains.

## Create The Workshop Workspace

Ask one technical participant or the facilitator to complete these steps:

1. Create a branch named `workshop/<team-name>`.
2. Create a folder named `workshop-output`.
3. Add six empty Markdown files using the names in the
   [workshop overview](partner-workshop#outcomes).
4. Add the scenario title and team member roles to `01-context-pack.md`.
5. Do not enter credentials, personal data, customer secrets, or production
   content in prompts or files.
6. Commit only when the facilitator confirms that workshop outputs belong in
   the repository.

> [!TIP]
> HVE workflows also use `.copilot-tracking/` for temporary state. Keep that
> folder in `.gitignore`. The `workshop-output` folder is the team's reviewed,
> shareable result.

## Learn The Interaction Pattern

Use the same pattern in every role exercise:

1. Select the named agent or invoke the named skill.
2. Provide the scenario, known facts, constraints, and requested output path.
3. Tell the agent to mark unknowns as assumptions or open questions.
4. Review the draft instead of accepting it as fact.
5. Correct unsupported claims.
6. Save only the reviewed result to `workshop-output`.
7. Hand the artifact to the next role.

Proceed to the [role exercises](partner-workshop-role-tracks).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
