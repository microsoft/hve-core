---
description: "Where .copilot-tracking/ lives (codebase root, not a host session folder) and how to find its gitignored files. Use when creating, finding, listing, or reading tracking files or storing intermediate files."
applyTo: '**/.copilot-tracking/**'
---

# Copilot Tracking Location

Apply these rules in every workflow that creates, finds, lists, or reads files in `.copilot-tracking/`. Each workflow's own instructions define the subfolders and file conventions inside it.

## Tracking Root

* Keep `.copilot-tracking/` directly under the codebase root: the root of the open workspace folder, which is normally the repository root. Do not create it in a subdirectory, even when the working directory or the files you change are nested.
* In a multi-root workspace, use the root of the primary (default) workspace folder, which is the first folder in the workspace. Do not use a secondary folder, such as an added HVE Core clone.
* When the host or session describes a session folder or session workspace for intermediate, working, or scratch files, store those files in the codebase `.copilot-tracking/` folder instead. Tracking kept in the codebase stays available to later sessions and to the workflows that resume from it.

## Finding Tracking Files

`.copilot-tracking/` is usually gitignored, and many search, list, and read tools skip ignored or excluded files by default.

* Turn on the tool's include-ignored or include-excluded option, such as `includeIgnoredFiles`, whenever you search, grep, list, or read `.copilot-tracking/` files. Limit those searches to the `.copilot-tracking/` folder so they do not scan ignored dependencies, build output, or secret files.
* When a tool has no such option, list the folder or read the file at its exact path, or search only that folder from a terminal with ignore rules disabled, such as `rg --no-ignore <pattern> .copilot-tracking/`.
* Treat an empty result from a search that applied ignore rules as inconclusive. Check the folder directly before concluding that a tracking file is missing, creating a replacement, or restarting work.
