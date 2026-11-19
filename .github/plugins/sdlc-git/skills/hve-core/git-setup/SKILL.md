---
name: git-setup
description: 'Audit Git configuration with one read-only baseline command, then propose confirmed, non-destructive fixes for identity, editor, and diff and merge tooling, with signing and safe.directory help only on request. Use when setting up or checking Git on a workstation.'
license: MIT
user-invocable: true
disable-model-invocation: true
---

# Git Setup

## Goal

Help the user configure Git consistently for everyday work (`add`, `commit`, `fetch`, `pull`, `push`) without overwriting preferred settings. Verify current values before suggesting changes, and never modify configuration without explicit confirmation.

Scope:

* Identity: `user.name` and `user.email` are set.
* Editing, diff, and merge tooling is configured when currently unset.
* Commit signing (GPG or SSH) help happens only when the user asks for it or reports a signing error.
* A `safe.directory` entry is proposed only when the user reports a Git ownership or unsafe-repository error.
* Existing customizations stay intact; never downgrade or remove settings.

## Flow

1. Audit the current configuration with exactly one command: `git config --list --show-origin`. It captures values and their source files. Run no other lookup, `gpg`, or `ssh-keygen` command during the audit.
2. Report gaps and desirable improvements from that output.
3. Propose minimal remediation commands, grouped logically.
4. Ask for confirmation per group before applying it, and apply only confirmed groups.
5. Verify applied settings with single `git config --get <key>` reads and show a before and after summary.
6. Summarize applied changes and remaining optional improvements.

## Detection

Classify each area from the baseline output only, in this order:

1. Identity: parse `user.name` and `user.email` and note each scope from its origin path. Mark a value missing when no scope sets it.
2. Commit signing (passive scan): parse `commit.gpgSign`, `gpg.format`, and `user.signingkey`, and classify the result for display only:
   * Disabled: `commit.gpgSign` is false or unset.
   * Configured candidate: signing is true and both `gpg.format` and `user.signingkey` are present.
   * Incomplete: signing is true but `gpg.format` or `user.signingkey` is missing.
   * Not configured: all three are unset.
3. Editor and tools: parse `core.editor`, `diff.tool`, and `merge.tool`, and mark each missing value as a gap.
4. Safe directory: note whether any `safe.directory` entry includes the current repository path.
5. Line endings: parse `core.autocrlf` and `core.eol`, and flag them only when both are unset and the user mentions cross-platform needs.

## Proposals

* Build a remediation group for each identity or editor and tooling gap, with the rationale, exact commands, and expected effect.
* Build a signing group only when the user asks about signing, wants to enable or disable it, or reports a signing verification error.
* Build a safe-directory group only when the user reports an unsafe-repository error from Git.
* Offer line-ending settings only when the user mentions cross-platform concerns.
* Write each command on its own line, directly runnable and human-auditable, with no chaining through `&&`, `;`, pipes, or subshells. Idempotent commands are acceptable when the user confirms them.
* When one specific value needs clarification later, propose a single follow-up `git config --get <key>` after user confirmation rather than a batch.
* Propose, but do not run, `gpg --list-secret-keys` only when signing is enabled or the user wants to enable signing and is unsure which keys exist.
* Propose key generation only when the user opts into signing and the configuration shows no usable key.
* Never push, fetch, pull, or alter remotes, and never show secrets or private key content. Redact the email only when the user asks for privacy.

## Command Templates

Adapt these after the user confirms the group; do not emit a template that no current gap or request needs.

Identity:

```bash
git config --global user.name "<user-name>"
git config --global user.email "<user-email>"
```

Disable misconfigured signing for now:

```bash
git config --global commit.gpgSign false
```

Trust a repository path after an unsafe-repository error:

```bash
git config --global --add safe.directory "<repo-path>"
```

Enable SSH signing with an existing key (Git 2.34 or later):

```bash
git config --global gpg.format ssh
git config --global user.signingkey "~/.ssh/id_ed25519.pub"
git config --global commit.gpgSign true
```

Generate and configure a GPG signing key:

```bash
gpg --full-generate-key
gpg --list-secret-keys --keyid-format=long
gpg --armor --export <KEY_ID> > public-gpg-key.asc
git config --global gpg.format openpgp
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgSign true
```

Generate and configure an SSH signing key:

```bash
# Linux and macOS
ssh-keygen -t ed25519 -C "<user-email>" -f ~/.ssh/id_ed25519
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Windows PowerShell with the built-in OpenSSH agent
ssh-keygen -t ed25519 -C "<user-email>" -f $HOME/.ssh/id_ed25519
Start-SSHAgent
ssh-add $HOME/.ssh/id_ed25519

# Both platforms
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgSign true
```

Use VS Code as the editor, diff tool, and merge tool when those values are unset:

```bash
git config --global core.editor "code --wait --new-window"
git config --global diff.tool code
git config --global difftool.code.cmd 'code -n --wait --diff "$LOCAL" "$REMOTE"'
git config --global merge.tool code
git config --global mergetool.code.cmd 'code -n --wait --merge "$REMOTE" "$LOCAL" "$BASE" "$MERGED"'
git config --global mergetool.code.trustexitcode true
git config --global mergetool.keepbackup false
```

## Interaction

* Show the audit table before any proposal.
* After the audit, ask only about identity, editor, and tooling gaps. Raise signing or safe-directory topics only when the user mentioned them or an error makes them relevant.
* Ask one confirmation per group, for example `Apply identity fixes? (yes/no)`. Treat only an explicit yes, in any letter case, as approval; any other answer declines the group.
* When an email does not match a corporate domain pattern the user supplied, warn without changing it.
* When every setting is already correct, state `No changes needed` and skip proposals except for topics the user asked about.

## Output Format

1. An audit section with a summary table that has at least the columns Setting, Value, Scope, and Status, using ✅ for satisfactory values and ❌ for missing or inconsistent values. A Notes column is optional.
2. Short notes below the table for ❌ rows only.
3. For each proposed group, an explanation, a fenced `bash` block, and a confirmation question.
4. After changes, a summary of successes and remaining warnings with a before and after table.
5. A final status line: `Git setup complete.` or `Git setup partial; user declined some changes.`

Example audit table:

```markdown
| Setting        | Value                    | Scope  | Status | Notes                            |
|----------------|--------------------------|--------|--------|----------------------------------|
| user.name      | Jane Doe                 | global | ✅      |                                  |
| user.email     | (missing)                | -      | ❌      | required for commits             |
| core.editor    | code --wait --new-window | global | ✅      |                                  |
| diff.tool      | (unset)                  | -      | ❌      | optional convenience             |
| merge.tool     | (unset)                  | -      | ❌      | improves merges                  |
| commit.gpgSign | true                     | global | ✅      | signing active                   |
| safe.directory | (not listed)             | -      | ✅      | not required (no unsafe warning) |
```

## Success Criteria

* Every critical gap (identity and the chosen editor and tooling) is fixed, or the user declined it with clear notice.
* No existing unrelated setting was unset or deleted, and no remote was touched.
* The summary gives clear guidance for remaining optional improvements: line endings, safe directory, and deferred signing.
