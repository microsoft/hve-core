---
description: 'Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.'
applyTo: '**/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md, **/.github/instructions/experimental/mural/**'
---

## Mural Bootstrap

Before any Mural verb in a fresh session, call `mural doctor`. Act on the verdict before proceeding. A fresh session is any agent turn where no successful `mural doctor` or Mural command has already confirmed readiness for the current workspace, credential backend, and working directory.

The bootstrap check is an operator safety gate. It verifies that the agent is in the expected project context, that dependencies are available, and that the configured credential backend can support the requested Mural operation. It does not authorize logging secrets or bypassing host credential policy.

## Credential Backend Defaults

| Host environment | Credential backend             |
|------------------|--------------------------------|
| devcontainer     | `auto`                         |
| Codespaces       | `file`                         |
| Remote-SSH       | `file`                         |
| WSL2             | `auto` with fallback to `file` |

## Verdict Handling

If `mural doctor` returns `ready`, continue with the requested Mural workflow.

If `mural doctor` returns `needs_setup`, pause and say:

```text
Mural is not configured for this workspace yet. Please run the documented setup for the Mural skill in this repository, then ask me to retry the Mural step.
```

If `mural doctor` returns `needs_login`, pause and say:

```text
Mural needs an authenticated session before I can continue. Please complete the login flow in your terminal or browser using the repository's Mural setup instructions, then ask me to retry.
```

If `mural doctor` returns `needs_scope_upgrade`, pause and say:

```text
The current Mural authorization is missing a required scope for this operation. Please reauthorize Mural with the required repository-documented scopes, then ask me to retry.
```

If `mural doctor` returns `wrong_cwd`, pause and say:

```text
The Mural tool is running from the wrong working directory. I need to run Mural commands from the repository root or the documented skill directory before continuing.
```

If `mural doctor` returns `deps_missing`, pause and say:

```text
The Mural tool dependencies are not installed in this environment. Please run the repository's documented dependency setup for the Mural skill, then ask me to retry.
```

## Sensitive Data Hygiene

Never print, summarize, or ask the user to paste secrets into chat. This includes raw authentication URLs, OAuth tokens, authorization headers, Azure SAS query strings, refresh tokens, and credential file contents. When escalation is needed, name the verdict and the remediation path without exposing sensitive values.
