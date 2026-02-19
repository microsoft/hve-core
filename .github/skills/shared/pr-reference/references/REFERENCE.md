---
title: PR Reference Skill Reference
description: XML output format, usage scenarios, output path variations, and semantic invocation patterns
author: Microsoft
ms.date: 2026-02-18
ms.topic: reference
keywords:
  - pr-reference
  - xml
  - git
estimated_reading_time: 5
---

## XML Output Format

The PR reference generator produces an XML document with four top-level elements inside a `<commit_history>` root:

```xml
<commit_history>
  <current_branch>
    feature/add-authentication
  </current_branch>

  <base_branch>
    origin/main
  </base_branch>

  <commits>
    <commit hash="f3a21c7" date="2026-02-15">
      <message>
        <subject><![CDATA[feat: add JWT token validation]]></subject>
        <body><![CDATA[Implements token validation middleware with
expiration checks and signature verification.]]></body>
      </message>
    </commit>
    <commit hash="b8c94e2" date="2026-02-14">
      <message>
        <subject><![CDATA[chore: add auth dependency]]></subject>
        <body><![CDATA[]]></body>
      </message>
    </commit>
  </commits>

  <full_diff>
diff --git a/src/middleware/auth.ts b/src/middleware/auth.ts
new file mode 100644
index 0000000..a1b2c3d
--- /dev/null
+++ b/src/middleware/auth.ts
@@ -0,0 +1,25 @@
+import { verify } from 'jsonwebtoken';
+
+export function validateToken(token: string): boolean {
+  // Token validation logic
+}
  </full_diff>
</commit_history>
```

### Element Reference

| Element            | Description                                                    |
| ------------------ | -------------------------------------------------------------- |
| `<current_branch>` | Active git branch name or `detached@<sha>` in CI environments  |
| `<base_branch>`    | Comparison branch provided via `--base-branch` / `-BaseBranch` |
| `<commits>`        | Ordered commit entries with hash, date, subject, and body      |
| `<full_diff>`      | Unified diff output from `git diff`                            |

Each `<commit>` element has `hash` and `date` attributes. The `<subject>` and `<body>` elements wrap content in CDATA sections to preserve special characters.

## Usage Scenarios

### Default PR Reference Generation

Generate a reference comparing the current branch against `origin/main` with output at the default location:

```bash
./scripts/generate.sh
```

```powershell
./scripts/generate.ps1
```

Output: `.copilot-tracking/pr/pr-reference.xml`

### Custom Base Branch Comparison

Compare against a branch other than `origin/main`, such as a release branch:

```bash
./scripts/generate.sh --base-branch origin/release/2.0
```

```powershell
./scripts/generate.ps1 -BaseBranch release/2.0
```

The PowerShell script automatically resolves `origin/release/2.0` when a bare branch name is provided.

### Markdown Exclusion for PR Descriptions

Exclude documentation changes from the diff when generating PR descriptions, reducing noise in the output:

```bash
./scripts/generate.sh --no-md-diff
```

```powershell
./scripts/generate.ps1 -ExcludeMarkdownDiff
```

### Custom Output Path

Write the XML to a branch-specific tracking directory for PR review workflows:

```bash
./scripts/generate.sh \
  --output .copilot-tracking/pr/review/feature-auth/pr-reference.xml
```

```powershell
./scripts/generate.ps1 `
  -OutputPath .copilot-tracking/pr/review/feature-auth/pr-reference.xml
```

### Work Item Discovery

Use a custom filename for work item discovery workflows that analyze branch changes:

```bash
./scripts/generate.sh \
  --base-branch origin/main \
  --output .copilot-tracking/workitems/discovery/sprint-42/git-branch-diff.xml
```

```powershell
./scripts/generate.ps1 `
  -BaseBranch main `
  -OutputPath .copilot-tracking/workitems/discovery/sprint-42/git-branch-diff.xml
```

## Output Path Variations

Different workflows use different output paths and filenames:

| Workflow              | Output Filename      | Output Path                                                     |
| --------------------- | -------------------- | --------------------------------------------------------------- |
| Default PR generation | `pr-reference.xml`   | `.copilot-tracking/pr/pr-reference.xml`                         |
| PR review             | `pr-reference.xml`   | `.copilot-tracking/pr/review/{{branch}}/pr-reference.xml`       |
| New PR creation       | `pr-reference.xml`   | `.copilot-tracking/pr/new/{{branch}}/pr-reference.xml`          |
| Work item discovery   | `git-branch-diff.xml`| `.copilot-tracking/workitems/discovery/{{folder}}/git-branch-diff.xml` |

## Utility Script Reference

### list-changed-files

Extracts file paths from the PR reference XML diff headers.

| Parameter       | Flag (bash)    | Flag (PowerShell) | Default                                 | Description                              |
| --------------- | -------------- | ----------------- | --------------------------------------- | ---------------------------------------- |
| Input path      | `--input, -i`  | `-InputPath`      | `.copilot-tracking/pr/pr-reference.xml` | Path to the PR reference XML             |
| Change type     | `--type, -t`   | `-Type`           | `all`                                   | Filter: all, added, deleted, modified, renamed |
| Output format   | `--format, -f` | `-Format`         | `plain`                                 | Output: plain, json, or markdown         |

### read-diff

Reads diff content with chunking and file filtering support.

| Parameter       | Flag (bash)       | Flag (PowerShell) | Default                                 | Description                              |
| --------------- | ----------------- | ----------------- | --------------------------------------- | ---------------------------------------- |
| Input path      | `--input, -i`     | `-InputPath`      | `.copilot-tracking/pr/pr-reference.xml` | Path to the PR reference XML             |
| Chunk number    | `--chunk, -c`     | `-Chunk`          | -                                       | 1-based chunk number to read             |
| Chunk size      | `--chunk-size, -s`| `-ChunkSize`      | 500                                     | Lines per chunk                          |
| Line range      | `--lines, -l`     | `-Lines`          | -                                       | Range format: START,END or START-END     |
| File path       | `--file, -f`      | `-File`           | -                                       | Extract diff for specific file           |
| Summary         | `--summary`       | `-Summary`        | -                                       | Show file list with change stats         |
| Info            | `--info`          | `-Info`           | -                                       | Show chunk breakdown without content     |

## Semantic Invocation

Callers reference the skill by describing the task intent rather than hardcoding script paths. Copilot matches the task description against the skill's description and loads the skill on-demand.

```markdown
<!-- Semantic invocation (preferred) -->
Generate the PR reference XML file comparing the current branch against origin/main.

<!-- Semantic invocation with parameters -->
Generate a PR reference XML excluding markdown diffs, saving to the review tracking directory.
```

Avoid referencing script paths directly in prompts, agents, or instructions. The agent selects the appropriate script based on the current platform.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
