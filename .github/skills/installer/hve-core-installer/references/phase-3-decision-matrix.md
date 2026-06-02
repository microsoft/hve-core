---
title: 'Phase 3: Environment Detection and Decision Matrix'
description: 'Environment detection questions and decision matrix that determine the recommended hve-core installation method.'
---

# Phase 3: Environment Detection & Decision Matrix

Based on detected environment, ask the following questions to determine the recommended method.

## Question 1: Environment Confirmation

Present options filtered by detection results:

<!-- <question-1-environment> -->
```text
### Question 1: What's your development environment?

Based on my detection, you appear to be in: [DETECTED_ENV_TYPE]

Please confirm or correct:

| Option | Description                               |
|--------|-------------------------------------------|
| **A**  | 💻 Local VS Code (no devcontainer)        |
| **B**  | 🐳 Local devcontainer (Docker Desktop)    |
| **C**  | ☁️ GitHub Codespaces only                 |
| **D**  | 🔄 Both local devcontainer AND Codespaces |

Which best describes your setup? (A/B/C/D)
```
<!-- </question-1-environment> -->

## Question 2: Team or Solo

<!-- <question-2-team> -->
```text
### Question 2: Team or solo development?

| Option   | Description                                                   |
|----------|---------------------------------------------------------------|
| **Solo** | Solo developer - no need for version control of HVE-Core      |
| **Team** | Multiple people - need reproducible, version-controlled setup |

Are you working solo or with a team? (solo/team)
```
<!-- </question-2-team> -->

## Question 3: Update Preference

Ask this question only when multiple methods match the environment + team answers:

<!-- <question-3-updates> -->
```text
### Question 3: Update preference?

| Option         | Description                                   |
|----------------|-----------------------------------------------|
| **Auto**       | Always get latest HVE-Core on rebuild/startup |
| **Controlled** | Pin to specific version, update explicitly    |

How would you like to receive updates? (auto/controlled)
```
<!-- </question-3-updates> -->

## Decision Matrix

Use this matrix to determine the recommended method:

<!-- <decision-matrix> -->
| Environment                | Team | Updates    | **Recommended Method**                                  |
|----------------------------|------|------------|---------------------------------------------------------|
| Any (simplest)             | Any  | -          | **Extension Quick Install** (works in all environments) |
| Local (no container)       | Solo | -          | **Method 1: Peer Clone**                                |
| Local (no container)       | Team | Controlled | **Method 6: Submodule**                                 |
| Local devcontainer         | Solo | Auto       | **Method 2: Git-Ignored**                               |
| Local devcontainer         | Team | Controlled | **Method 6: Submodule**                                 |
| Codespaces only            | Solo | Auto       | **Method 4: Codespaces**                                |
| Codespaces only            | Team | Controlled | **Method 6: Submodule**                                 |
| Both local + Codespaces    | Any  | Any        | **Method 5: Multi-Root Workspace**                      |
| HVE-Core repo (Codespaces) | -    | -          | **Method 4: Codespaces** (already configured)           |
<!-- </decision-matrix> -->

## Method Selection Logic

After gathering answers:

1. Match answers to decision matrix
2. Present recommendation with rationale
3. Offer alternative if user prefers different approach

<!-- <recommendation-template> -->
```text
## 📋 Your Recommended Setup

Based on your answers:
* **Environment**: [answer]
* **Team**: [answer]
* **Updates**: [answer]

### ✅ Recommended: Method [N] - [Name]

**Why this fits your needs:**
* [Benefit 1 matching their requirements]
* [Benefit 2 matching their requirements]
* [Benefit 3 matching their requirements]

Would you like to proceed with this method, or see alternatives?
```
<!-- </recommendation-template> -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
