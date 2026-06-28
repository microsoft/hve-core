---
name: repo-tour
description: "Guided conversational tour of the hve-core repository that narrates one area at a time and verifies structure against the live tree before describing"
---

# Repo Tour Skill

## Goal

Give someone a short, conversational tour of the hve-core repository so they understand what exists and where it lives, without opening files for them. Narrate one area at a time, verify each area against the live tree before describing it so the map never drifts, and hand off to a file-level explorer for exact detail.

This skill is repo-local: it describes hve-core's own structure and is not distributed in any collection.

## Inputs

* (Optional) The area to start with (for example `docs/`, `.github/`, `evals/`). When absent, offer the map and let the user pick.
* (Optional) A signal to go one level deeper into a chosen area.

## Tour Flow

1. Offer the map. Name the main areas in one line each from [references/repo-map.md](references/repo-map.md) and ask which to start with. Do not describe them all at once.
2. Verify before describing. List the live directory for the chosen area and reconcile against the reference: note real children, mention folders the reference omits, and describe what is actually present when the reference is stale.
3. Walk one area at a time. Give a plain two-to-three sentence description, then ask whether they want another area, to go deeper, or to start building.
4. Go deeper on request. Verify the chosen area's subfolders against the live tree, then name them plainly using the one-level-deeper section of the reference. If the user wants to descend further (a sub-subfolder), repeat the same verify-then-name step against the live tree for that level rather than reciting from memory; stop short of opening files. When the user is done at this depth, return to step 3 to offer another area, go deeper still, or start building, so they are never stranded inside a subfolder.
5. Hand off for file-level depth. Describe structure only; for opening or tracing files, hand to the `#Explore` helper (or plain Copilot Chat).
6. Re-route if intent turns generative. If exploring becomes "I want to change or add X," return control to the onboarding flow to route through its Routing Map.

## Success Criteria

* The user explored the areas they cared about, one at a time, in their own order.
* Each described area was reconciled against the live tree before narration.
* The tour stayed at structure and handed off to `#Explore`, or returned to onboarding when intent turned generative.

## Constraints

* Describe structure; do not open file contents. Hand to `#Explore` for that.
* Do not list every area in depth at once. Converge through the user's picks.
* Do not start requirements, research, planning, or building.
* Do not invent paths. When unsure, verify against the live tree or hand off.

## Handoff

* File-level depth: hand to the `#Explore` helper (or plain Copilot Chat).
* Build intent: return to the onboarding flow to route through its Routing Map.

> Brought to you by microsoft/hve-core
