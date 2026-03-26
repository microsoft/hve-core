---
description: "Shared diff computation protocol for code review agents - branch detection, scope locking, large diff handling, and non-source artifact filtering - Brought to you by microsoft/hve-core"
applyTo: "**/.github/agents/coding-standards/**, **/.github/prompts/coding-standards/**"
---

# Diff Computation Protocol

Obtain the diff before reading any source files. Use the decision tree below to determine the appropriate method, then apply scope rules and large diff handling.

## Decision Tree

Run `git branch --show-current` and `git status --short` to determine context. Match the first applicable case:

1. **Branch review** (user explicitly requests a specific branch or PR, or is on a feature branch that is not `main` and not detached HEAD): follow the Feature Branch Diff section. The pr-reference skill captures committed changes; a working-tree supplement captures staged, unstaged, and untracked changes. If the user says "review the PR" while on `main` or detached HEAD without naming a branch, PR, or commit, ask which branch or PR they want reviewed, then route to this case or to the Specific Commit section as appropriate.
2. **Local uncommitted changes on `main` or detached HEAD** (not on a feature branch, but edits exist that are not yet committed): follow the Uncommitted Changes section.
3. **Selected code or `#file` references** (user selects code in the editor or references `#file:path/to/file.ext`): follow the Selected Code section.
4. **Specific commit review** (user asks to review a particular commit): follow the Specific Commit section.
5. **No reviewable content**: inform the user that no diff could be determined and stop.

## Feature Branch Diff

Invoke the **pr-reference** skill to compute the diff. The skill handles branch detection, merge-base resolution, file listing, non-source exclusions, and large diff chunking.

1. Generate the structured diff:

   ```bash
   generate.sh --base-branch auto --merge-base --exclude-ext min.js,min.css,map
   ```

2. Get the changed file list:

   ```bash
   list-changed-files.sh --exclude-type deleted --format plain
   ```

3. For large diffs, use chunk planning and batched analysis:

   ```bash
   read-diff.sh --info       # chunk count and size summary
   read-diff.sh --chunk N    # read chunk N
   ```

If `list-changed-files.sh` returns an empty list, stop and report "no reviewable content" per Decision Tree case 5.

Pass the diff output and file list as pre-computed input to the review agent so it skips its own scope detection.

## Uncommitted Changes

* Unstaged: `git diff HEAD`
* Staged: `git diff --cached`
* Untracked (new files not yet staged): enumerate with `git ls-files --others --exclude-standard`, then read the full content of each file as the review input.

## Selected Code

Use the provided code as the review input; no git diff is needed. Apply all loaded skills or review logic to the selected code. Skip artifact persistence since there is no branch context.

## Specific Commit

```bash
git diff <commit>^..<commit>
```

## Scope Rules

* Do not enumerate, list, or read source files before obtaining the diff or review input.
* Only lines present in the diff (added or modified lines) are in scope for findings.
* For selected code reviews (no diff context), all provided code lines are in scope.
* Read full file contents only for contextual understanding of diff lines, never as a source of findings.
* Pre-existing issues in unchanged code go in the **Out-of-scope Observations** table, clearly labelled and excluded from the verdict.

## Large Diff Handling

Use the `timeout` parameter on terminal commands to prevent hanging on large repositories.

| Changed Files | Strategy                                                       |
|---------------|----------------------------------------------------------------|
| Fewer than 20 | Analyze all files with full diffs.                             |
| 20 to 50      | Group files by directory and analyze each group.               |
| More than 50  | Progressive batched analysis, processing 5-10 files at a time. |

When a diff exceeds 2000 lines of combined changes or 500 lines in a single file, review the most recent commits individually using `git log --oneline` and `git show --stat`.

## Non-Source Artifact Skip List

Skip these artifacts when computing and analyzing diffs:

* Lock files: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
* Minified bundles: `.min.js`, `.min.css`
* Source maps: `.map`
* Binaries
* Build output directories: `/bin/`, `/obj/`, `/node_modules/`, `/dist/`, `/out/`, `/coverage/`

---

Brought to you by microsoft/hve-core
