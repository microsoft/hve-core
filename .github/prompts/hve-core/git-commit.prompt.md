---
agent: 'agent'
description: 'Stage selected paths, confirm the staged set, and create a conventional commit'
model:
  - MAI-Code-1-Flash (copilot)
  - Claude Haiku 4.5 (copilot)
---

# Select, Stage, Confirm, and Commit

Must follow all instructions provided by #file:../../instructions/hve-core/commit-message.instructions.md

Protocol:

1. **Inventory candidate paths**: Before changing the index, run `git status --porcelain=v1 -z --untracked-files=all` and `git rev-parse --verify HEAD` in the target repository.
  * Record tracked, untracked, deleted, renamed, and initially staged paths. Treat a reported rename's old and new paths as one logical selection.
  * If `HEAD` cannot be verified, STOP because this workflow cannot restore a rejected staging change safely.
  * If any path has both staged and unstaged changes, STOP and ask the user to resolve its hunk-level intent outside this workflow. Do not restage a partially staged path.
  * If there are no candidate changes, output `No changes to commit.` and STOP.
2. **Confirm whole-path intent**: Present the candidate paths and their states without file contents, then ask the user to select the whole paths intended for this commit.
  * Every initially staged path must be selected. If the user excludes one, STOP before changing the index; never unstage prior user work.
  * A detected rename is selected only as its complete old-and-new path pair.
  * If the selection is empty, ambiguous, unsafe to represent as shell arguments, or absent, STOP without staging or committing.
3. **Stage only the selection**: Stage only selected paths with `git add -- <safely quoted selected paths>`. Never use an unscoped `git add -A` or `git add -u` path.
  * Quote each path for the active shell and keep `--` before path arguments. If a path cannot be represented safely, STOP.
  * Record only the selected paths that were not initially staged as this invocation's staging delta.
  * If staging fails, report a concise error and STOP without retrying.
4. **Inspect and confirm the staged set**: Use the `get_changed_files` tool with `sourceControlState` set to `staged` and `repositoryPath` set to the full project path.
  * Verify that the exact staged path set contains every selected path, contains every initially staged path, and contains no unselected path. If it differs, restore this invocation's staging delta as described below and STOP.
  * Present the exact staged paths without file contents or suspected sensitive values. Ask the user to confirm that these paths and their staged content are intended for the local commit.
  * If the user rejects, does not respond, or gives an ambiguous answer, restore this invocation's staging delta and STOP without committing.
5. **Generate and commit**: Analyze the staged changes and produce a clean Conventional Commit message according to the referenced commit-message instructions. The message is authoritative once generated. Commit once, without showing the message first, using only an allowed commit command:

   * Pipe the exact commit message (including body + footer emoji line) via STDIN: `echo "<full message>" | git commit -F -`.
   * Preserve newlines exactly; ensure the footer emoji line is the final line (file ends with a newline).
   * DO NOT run any other git commands (no push, pull, fetch, diff, show, status, log, branch, switch, merge, rebase, tag, etc.).

6. After the commit succeeds, display to the user a success line followed by the full commit message in a fenced `markdown` code block.
7. If the commit fails, output a concise error summary and STOP without retrying.

Staging-delta restoration:

* Restore only paths newly staged by this invocation with `git reset -- <safely quoted staging-delta paths>`. This resets their index entries to `HEAD` while preserving working-tree content and leaves initially staged paths unchanged.
* Treat both paths of a selected rename as one restoration unit.
* If restoration fails, report the affected path names and STOP. Do not retry or run another recovery command.

Rules & Constraints:

* Allowed Git commands during the normal flow: `git status --porcelain=v1 -z --untracked-files=all`, `git rev-parse --verify HEAD`, path-scoped `git add -- <paths>`, path-scoped `git reset -- <paths>` only for staging-delta restoration, and `git commit -F -` or single-line `git commit -m` variants. The optional adjustment flow may also use `git reset --soft HEAD^` as defined below.
* Never use root `.gitignore` presence, absence, length, or completeness as staging authorization.
* Never use Git CLI to obtain file contents or diffs. Use `git status` only for path and index-state metadata, and rely on `get_changed_files` for staged content.
* Never add a pre-commit hook, require a secret-scanner dependency, or claim that this workflow performs deterministic secret detection. Repository-owned scanning remains a separate downstream control.
* If there are no staged changes after staging, output `No changes to commit.` and STOP without creating an empty commit.
* Commit message MUST:
  * Use an allowed type and optional allowed scope.
  * Be present tense.
  * Keep description under 4 specific change points (comma-separated concise phrases).
  * Include an optional body ONLY for large, wide-reaching changes (list bullet points starting each line with `-`) preceded by a blank line.
  * Include a footer line starting with a blank line, containing an emoji, a space, `- Generated by Copilot`.
* Wait only for the two required user decisions: whole-path selection before staging and exact staged-set confirmation before commit. Never infer either decision from silence.

Output Format:

* When proceeding (changes present):
  * Perform the commit first.
  * After success, print a single confirmation line: `Commit created successfully with the following message:`
  * Then a blank line.
  * Then the commit message inside a fenced ```markdown code block.
* For no-change scenario, skip code block and print: `No changes to commit.`

Example for a large change (structure illustration after committing):
<!-- <example-commit-and-commit-action-large> -->
Commit created successfully with the following message:

```markdown
feat: add repo-wide instruction files including prompts and agents

* add commit message, markdown, C# along with C# test instructions
* introduce RPI, HVE Builder, and ADR authoring capabilities
* configure markdownlint and VS Code workspace settings
* add ADO work items prompts for getting and preparing my work items
* add .gitignore and cleanup README newlines

🧭 - Generated by Copilot
```

Commit display complete.
<!-- </example-commit-and-commit-action-large> -->

Example for a medium/small change (after committing):
<!-- <example-commit-and-commit-action> -->
Commit created successfully with the following message:

```markdown
feat(prompts): update summarize-my-work-items.prompt.md to clarify json output, correct get-my-work-items.prompt.md to fallback to wit_my_work_items

🔒 - Generated by Copilot
```

Commit display complete.
<!-- </example-commit-and-commit-action> -->

Error Handling:

* If `git commit` fails (e.g., hooks reject), report a concise error summary with suggested fix and STOP without retries.

## Post-Commit Adjustments (Optional)

Trigger: Only initiate this flow if, immediately after displaying the commit, the user explicitly asks to (a) modify the commit message, or (b) undo the just-created commit without providing a replacement message. If no such explicit request occurs, do nothing further.

Flow:

1. Verify last action created exactly one new commit in this session (assume true since we just committed; do not run git history commands).
2. Run `git reset --soft HEAD^` to uncommit while preserving index and working tree.
3. If user only wants to undo (no new message requested): STOP after reset and output: `Commit undone (changes staged, no new commit message requested).` Do not auto-create a new commit.
4. If user wants a new/modified message: Re-interpret the user's requested edits to the prior message; merge them into the authoritative previous commit message while enforcing all Conventional Commit rules (type, optional scope, description length, bullet list formatting, footer emoji line).
5. Regenerate the updated commit message (replace, do not append diffs unless justified) and re-commit using: `echo "<updated message>" | git commit -F -`.
6. Display a confirmation line: `Commit message updated successfully:` then a blank line, then the updated commit message in a fenced ```markdown code block.

Constraints:

* Use `git reset --soft HEAD^` strictly once per original commit; if user requests further tweaks again, repeat only if they just acknowledged the previous updated message (still limited to a single soft reset per actual commit creation cycle).
* Never use any other git commands (no amend, no rebase, no reflog). Use soft reset + fresh commit only.
* Preserve original staged content; never modify file contents in this flow—only the message.
* Re-validate description limits and footer formatting; fix user-proposed changes if they violate standards, silently correcting to compliant form.

User Request Interpretation:

* If user supplies only a new description: keep original type/scope and replace description.
* If user supplies a new type/scope: validate against allowed list; otherwise keep original.
* If user requests adding bullets/body: ensure a blank line before bullets and each bullet starts with `-`.
* Always ensure exactly one footer line with emoji + `- Generated by Copilot` remains last.

Error Handling (Adjustment Flow):

* If `git reset --soft HEAD^` fails: report concise error and STOP.
* If re-commit fails: report concise error and STOP.

Example Adjustment:
User: "Can you change the description to clarify it's adding instruction files?"
Action: soft reset, update description portion, re-commit, display updated message per formatting.

Example Undo Without New Message:
User: "Undo that commit" (no further message guidance)
Action: soft reset only; leave all changes staged; output undo confirmation line; no commit message block shown.

---

Proceed now following the protocol.
