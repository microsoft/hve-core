---
name: git-commit
description: 'Stage user-selected paths, confirm the exact staged set, and create one local Conventional Commit, or generate a commit message for staged changes without committing. Use when you want a guarded commit or a ready-to-paste message.'
argument-hint: '[mode={commit|message-only}]'
license: MIT
user-invocable: true
disable-model-invocation: true
---
<!-- cspell:ignore pathspecs unstages -->

# Git Commit

## Goal

Create one local Conventional Commit from whole paths the user selects and confirms, or generate a message for the currently staged changes without touching the index.

## Inputs

* `mode` (optional): `commit` (default) runs the select, stage, confirm, and commit protocol. `message-only` generates a message for the staged changes and never stages, unstages, or commits.

## Message Rules

Generate every message by following the `commit-message` instructions. They own types, scopes, description and body limits, and the footer line. Once generated, the message is authoritative for the commit.

## Message-Only Mode

1. Read the staged changes with `git --no-pager diff --staged`. Use the host's staged-changes tool instead when the user asks to avoid the terminal or no terminal is available.
2. When nothing is staged, output `No changes to commit.` and stop.
3. Generate the message from the complete staged diff.
4. Output the message in a fenced code block and tell the user to copy it as-is or edit it before committing.

## Commit Protocol

1. Inventory candidate paths. Before changing the index, run `git status --porcelain=v1 -z --untracked-files=all` and `git rev-parse --verify HEAD` in the target repository.
   * Record tracked, untracked, deleted, renamed, copied, and initially staged paths. Treat only an `R` or `C` status record that supplies both old and new paths as one logical selection. Present a separate deletion and untracked addition as independent candidates without inferring a rename.
   * If `HEAD` cannot be verified, stop, because this workflow cannot restore a rejected staging change safely.
   * If any path has both staged and unstaged changes, stop and ask the user to resolve its hunk-level intent outside this workflow. Do not restage a partially staged path.
   * If there are no candidate changes, output `No changes to commit.` and stop.
2. Confirm whole-path intent. Present the candidate paths and their states without file contents, then ask the user to select the whole paths intended for this commit.
   * Every initially staged path must be selected. If the user excludes one, stop before changing the index; never unstage prior user work.
   * A status-reported rename or copy is selected only as its complete old-and-new path pair.
   * If the selection is empty, ambiguous, unsafe to represent as shell arguments, or absent, stop without staging or committing.
3. Stage only the selection with `git --literal-pathspecs add -- <safely quoted selected paths>`. Never use an unscoped `git add -A` or `git add -u` path.
   * Quote each path for the active shell and keep `--` before path arguments. If a path cannot be represented safely, stop.
   * Record only the selected paths that were not initially staged as this invocation's staging delta.
   * If staging fails, report a concise error and stop without retrying.
4. Inspect and confirm the staged set. Use the host's staged-changes tool, such as `get_changed_files` with `sourceControlState` set to `staged` and `repositoryPath` set to the full project path.
   * Verify that the exact staged path set contains every selected path, contains every initially staged path, and contains no unselected path. If it differs, restore this invocation's staging delta and stop.
   * Present the exact staged paths without file contents or suspected sensitive values. Ask the user to confirm that these paths and their staged content are intended for the local commit.
   * If the user rejects, does not respond, or gives an ambiguous answer, restore this invocation's staging delta and stop without committing.
   * If no staged changes remain, output `No changes to commit.` and stop without creating an empty commit.
5. Generate the message from the staged changes and commit once, without showing the message first.
   * Pipe the exact message, including body and footer line, through STDIN, for example `echo "<full message>" | git commit -F -`. Preserve newlines exactly and end with the footer line followed by a newline.
   * Run no other Git command at this step (no push, pull, fetch, diff, show, status, log, branch, switch, merge, rebase, or tag).
6. After the commit succeeds, print `Commit created successfully with the following message:`, a blank line, and the full message in a fenced `markdown` code block.
7. If the commit fails, for example because a hook rejects it, report a concise error with a suggested fix and stop without retrying.

### Staging-Delta Restoration

* Restore only paths newly staged by this invocation with `git --literal-pathspecs reset -- <safely quoted staging-delta paths>`. This resets their index entries to `HEAD`, preserves working-tree content, and leaves initially staged paths unchanged.
* Treat both paths of a selected status-reported rename or copy as one restoration unit.
* If restoration fails, report the affected path names and stop. Do not retry or run another recovery command.

### Allowed Commands

* Normal flow: `git status --porcelain=v1 -z --untracked-files=all`, `git rev-parse --verify HEAD`, path-scoped `git --literal-pathspecs add -- <paths>`, path-scoped `git --literal-pathspecs reset -- <paths>` for staging-delta restoration only, and `git commit -F -` or a single-line `git commit -m`.
* Adjustment flow: `git reset --soft HEAD^` as defined in Post-Commit Adjustments.
* Never use Git CLI to obtain file contents or diffs in commit mode. Use `git status` only for path and index-state metadata, and rely on the staged-changes tool for staged content.
* Never use root `.gitignore` presence, absence, length, or completeness as staging authorization.
* Never add a pre-commit hook, require a secret-scanner dependency, or claim that this workflow performs deterministic secret detection. Repository-owned scanning remains a separate downstream control.

## Post-Commit Adjustments

Start this flow only when, immediately after the commit is displayed, the user explicitly asks to change its message or to undo it.

1. Treat the commit just created in this session as the target; do not run history commands to confirm it.
2. Run `git reset --soft HEAD^` to uncommit while preserving the index and working tree.
3. For an undo without a new message, print `Commit undone (changes staged, no new commit message requested).` and stop without committing.
4. For a message change, merge the requested edits into the previous message, correct anything that breaks the commit-message instructions, and commit again with `git commit -F -`.
5. Print `Commit message updated successfully:`, a blank line, and the updated message in a fenced `markdown` code block.

Constraints for this flow:

* Use one soft reset per commit created; repeat only after the user acknowledges the previous update.
* Never amend, rebase, or use the reflog, and never change file contents; only the message changes.
* Keep the original type and scope unless the user supplies valid replacements, and keep exactly one footer line last.
* If the reset or the new commit fails, report a concise error and stop.

## Success Criteria

* Wait only for the two required user decisions: whole-path selection before staging and exact staged-set confirmation before commit. Never infer either decision from silence.
* Only selected paths and initially staged paths enter the commit, and a rejected staged set leaves the initial index and working tree unchanged.
* Message-only mode leaves the index untouched.
* No push or remote operation occurs.

## Example Output

````markdown
Commit created successfully with the following message:

```markdown
feat(prompts): update work item prompts to clarify json output

🔒 - Generated by Copilot
```
````
