---
title: Mural Credentials (Experimental)
description: Configure and manage credential storage backends for the Mural skill (keyring, file, env-only).
sidebar_position: 10
author: microsoft/hve-core
ms.date: 2026-05-08
ms.topic: how-to
keywords: [mural, credentials, keyring, oauth, experimental]
estimated_reading_time: 8
---

:::warning Experimental

The Mural skill ships as an experimental capability under `microsoft/hve-core`. The `mural auth` subcommands, the keyring-backed credential storage, and the migration tooling described on this page are evolving. Pin commit SHAs in production use, validate behavior in a non-production workspace before adopting widely, and report regressions through the [hve-core issue tracker](https://github.com/microsoft/hve-core/issues/new/choose).

:::

The Mural skill resolves credentials through a three-tier `env → backend → file` lookup. The active backend is selected by `MURAL_CREDENTIAL_BACKEND` and exposed by the `mural auth status` command. This page explains how to choose a backend, walk through interactive bootstrap, configure devcontainer scenarios, troubleshoot the most common failures, migrate between backends, and reason about the underlying security model.

## Why credential storage matters

The Mural OAuth flow leaves three high-value secrets on the operator workstation: the OAuth client ID, the OAuth client secret (for confidential clients), and a long-lived refresh token.
Storing these on the local filesystem at mode `0600` defends against same-tenant snooping but remains exposed to backup, sync, and accidental copy operations that lift files out of the protected directory.
Moving the same material into the OS keychain (Keychain on macOS, DPAPI on Windows, SecretService on Linux desktop) removes the file copy from the easiest exfiltration paths and lets per-process unlock decisions become explicit.
Mural refresh tokens currently do not rotate on use, so a token leaked from a backup remains valid until it is revoked at the portal; this elevates the value of keeping the at-rest copy out of synchronizable filesystems.

## Backend chooser

The skill selects a backend based on the value of `MURAL_CREDENTIAL_BACKEND`:

* `auto` (default): prefer the `keyring` backend when an OS keychain is reachable; fall back to the `file` backend and emit a single WARN per process when the keychain is unavailable.
* `keyring`: require an OS keychain. If the keychain is unreachable (no SecretService daemon, locked Keychain that refuses to unlock, DPAPI failure), the skill fails closed rather than silently falling back.
* `file`: use the existing 0600 credential file at `$XDG_CONFIG_HOME/hve-core/mural.{profile}.env`. Suitable for headless containers, CI, and any environment without a usable OS keychain.
* `env-only`: read credentials only from process environment variables. Skips both the keyring and the credential file. Useful when an outer secret manager (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault) injects credentials at process start.

When the resolved backend has no credentials and the matching environment variables are also unset, the skill reports a clear `not configured` status and exits with a non-zero status code; it does not attempt to interactively bootstrap unless `mural auth bootstrap` or `mural auth login` is invoked explicitly.

## Subcommands reference

| Subcommand                                                                               | Purpose                                                                                                                                                                                                                                                                                                    |
|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `mural auth status`                                                                      | Print the resolved backend, profile, source URI, per-key presence, and (for `keyring`) the underlying keyring backend name.                                                                                                                                                                                |
| `mural auth login [--force]`                                                             | Run the OAuth authorization code flow against `http://localhost:8765/callback` and persist the tokens to the resolved backend.                                                                                                                                                                             |
| `mural auth logout [--keep-credentials] [--force]`                                       | Delete credentials from the resolved backend; `--keep-credentials` clears only the cached refresh token; `--force` skips confirmation. Note that local logout does not revoke the refresh token server-side (gap G-EOP-1); revoke at [https://app.mural.co/account/api](https://app.mural.co/account/api). |
| `mural auth migrate --to {keyring\|file} [--profile NAME] [--cleanup] [--force] [--yes]` | Move credentials between backends. `--cleanup` requires `--force` for destructive deletion; `--yes` bypasses interactive confirmation.                                                                                                                                                                     |
| `mural auth bootstrap [--force]`                                                         | Interactive walkthrough that registers a Mural OAuth app, collects credentials, runs OAuth login, verifies via `/me`, and reports status.                                                                                                                                                                  |
| `mural auth setup --client-id <ID>`                                                      | Non-interactive provisioning for CI and scripted setup.                                                                                                                                                                                                                                                    |
| `mural auth use NAME`                                                                    | Switch the active profile in the multi-profile token store.                                                                                                                                                                                                                                                |
| `mural auth list`                                                                        | Print every configured profile and mark the active one.                                                                                                                                                                                                                                                    |

## Bootstrap walkthrough

Run `mural auth bootstrap` to onboard a new workstation. The walkthrough proceeds through seven stages:

1. **Detect existing credentials.** The skill calls `mural auth status` internally and aborts with a hint when credentials already exist for the active profile. Pass `--force` to bypass detection and re-collect credentials over a populated backend.
2. **Explain Mural app registration.** The walkthrough prints the URL of the Mural developer portal at [https://app.mural.co/me/apps](https://app.mural.co/me/apps) and instructs the operator to register an app with the loopback redirect URL `http://localhost:8765/callback` and the scopes `identity:read`, `workspaces:read`, `murals:read`, and `murals:write`.
3. **Collect credentials.** The walkthrough prompts for the OAuth client ID and client secret using `getpass`. Both values are masked in the terminal and never echoed.
4. **Run OAuth.** The skill starts a localhost loopback listener bound to `127.0.0.1:8765`, opens the Mural authorization endpoint in the default browser, and exchanges the returned authorization code for an access token and refresh token.
5. **Persist via the resolved backend.** The skill writes the credentials through the backend selected by `MURAL_CREDENTIAL_BACKEND` (defaulting to `auto`). When `auto` falls back to `file`, the walkthrough prints a single WARN that names the reason.
6. **Verify against `/me`.** The skill calls the Mural `/me` endpoint with the freshly minted access token to confirm the credentials work end-to-end before exiting.
7. **Report status.** The walkthrough closes by invoking `mural auth status` so the operator sees the resolved backend, source URI, and per-key presence.

When `MURAL_NONINTERACTIVE=1` is set, `mural auth bootstrap` refuses to prompt and exits with a hint that points at `mural auth setup`.

## Devcontainer recipes

Pick the recipe that matches the runtime environment:

### Local Docker

Leave `MURAL_CREDENTIAL_BACKEND=auto`. When the container forwards a SecretService socket from the Linux host (or runs on macOS with Keychain forwarding), the keyring backend works inside the container. Otherwise the auto-fallback selects the file backend and emits a single WARN that explains the reason.

```bash
# devcontainer.json or compose env
MURAL_CREDENTIAL_BACKEND=auto
```

### GitHub Codespaces

Set `MURAL_CREDENTIAL_BACKEND=file`. Codespaces does not expose a reachable OS keychain to the workspace container; forcing the file backend avoids the auto-fallback WARN on every invocation and keeps credentials at mode `0600` inside the container.

```bash
# .devcontainer/devcontainer.json containerEnv
"MURAL_CREDENTIAL_BACKEND": "file"
```

### Remote-SSH

Set `MURAL_CREDENTIAL_BACKEND=file` unless a SecretService daemon is configured on the remote host (this is uncommon outside of full Linux desktops). The file backend keeps credentials on the remote machine where the OAuth loopback listener actually binds.

```bash
# ~/.ssh/environment on the remote host (requires PermitUserEnvironment)
MURAL_CREDENTIAL_BACKEND=file
```

### WSL2

Leave `MURAL_CREDENTIAL_BACKEND=auto` when WSLg and a SecretService implementation are available; otherwise set `MURAL_CREDENTIAL_BACKEND=file`. The Windows DPAPI keychain is not reachable from inside the WSL2 distribution, so `keyring` resolves through SecretService inside WSL when present.

```bash
# ~/.bashrc inside the WSL2 distribution
export MURAL_CREDENTIAL_BACKEND=auto
```

## Troubleshooting

* **No SecretService on Linux headless.** `mural auth status` reports `keyring=unavailable`. Set `MURAL_CREDENTIAL_BACKEND=file` for the workstation, or install and run a SecretService implementation (for example `gnome-keyring-daemon --components=secrets`) and re-run `mural auth login`.
* **Locked Keychain on macOS.** `mural auth login` fails with `keyring: refused to unlock`. Unlock the login keychain in Keychain Access and retry, or pass `--force` to re-prompt.
* **DPAPI failure on Windows.** `mural auth login` reports `keyring backend raised an error`. The most common cause is running under a Windows service account that has no profile loaded. Set `MURAL_CREDENTIAL_BACKEND=file` for the service account, or run the command interactively under the operator account first.
* **Foreign-owned credential file refused (G3).** `mural auth status` reports `file backend refused: st_uid mismatch`. Re-run `mural auth bootstrap` under the owning user account, or `chown` the file to the current user; the runtime intentionally refuses files owned by a different uid.
* **Mode-0600 enforcement is loud (G5).** Setting `MURAL_ENV_FILE_RELAXED=1` now emits a single WARN per process to surface the loosened constraint. The variable continues to skip mode-0600 enforcement; remove it from CI configuration once the environment is hardened.
* **Symlinked credential file (G6).** The runtime refuses to follow a symlinked credential file (`O_NOFOLLOW` is set on open). Replace the symlink with a regular file in the expected location, or update `MURAL_ENV_FILE` to point at the real path.

## Migration

Use `mural auth migrate` to move credentials between backends without re-running OAuth.

Forward migration (file → keyring):

```bash
mural auth migrate --to keyring --cleanup --force
```

`--cleanup` deletes the source credential file after the keyring write completes; `--force` is required when `--cleanup` is set so the deletion is explicit. Without `--cleanup`, the file remains in place and the skill emits a single WARN per `(profile, selected backend)` per process noting that both backends now hold credentials. Subsequent reads prefer the keyring entry.

Reverse migration (keyring → file):

```bash
mural auth migrate --to file
```

Reverse migration writes the credentials back to `$XDG_CONFIG_HOME/hve-core/mural.{profile}.env` at mode `0600`. The source keyring entry is left in place by default; pass `--cleanup --force` to delete it.

`--yes` bypasses the interactive confirmation prompt for both directions; combine it with `--force` when running migrations from CI.

## Security model

This page reflects the threat model captured in [SECURITY.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/mural/SECURITY.md).
Operators planning a production deployment should also review the [Enterprise Readiness Gaps](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/mural/SECURITY.md#enterprise-readiness-gaps) table, which records known limitations such as the absence of server-side token revocation on `mural auth logout` (G-EOP-1), the lack of certificate pinning for `app.mural.co` (G-TLS-1), and the operator-controlled `MURAL_ENV_FILE_RELAXED` escape hatch (G-INF-3).
The [TLS posture](https://github.com/microsoft/hve-core/blob/main/.github/skills/experimental/mural/SECURITY.md#tls-posture) subsection in B2 documents how the skill validates the Mural endpoint's certificate (system trust store via Python's default `ssl.create_default_context()`; no custom CA bundle, no pinning, no mTLS).

Two trust boundaries are most relevant to credential storage:

* **A2 refresh tokens** and **A3 client secrets** are the long-lived assets the keyring backend is intended to remove from the operator filesystem. Mural refresh tokens currently do not rotate, so a leaked refresh token remains valid until revoked at the portal.
* **ADV-c backup and sync exfiltration** is the largest risk reduction the keyring backend delivers. Moving credentials out of `$XDG_CONFIG_HOME/hve-core/` removes them from synced home directories, snapshot-based backups, and editor "open recent" indexes that read filesystem paths.
* **ADV-d stolen device** is partially mitigated when the keychain requires explicit unlock (Keychain on macOS, DPAPI tied to user logon, SecretService with a passphrase). Where the keychain is auto-unlocked at login, the residual risk equals that of `0600` filesystem storage.
* **ADV-a same-uid malware** is _not_ defended by either backend. A process running as the operator can call the same keyring API or read the credential file directly. Treat workstation hygiene as the controlling defense.

NIST SP 800-63B and OWASP ASVS V6.x both speak to credential storage practices that informed the design (keyring usage, restricted filesystem permissions, explicit reauthentication on suspicion of compromise). These references are informative; conformance with either standard requires additional environmental controls that are out of scope for the skill.

## Feedback

The credential storage redesign is experimental. Report bugs, surprising defaults, or platform-specific gaps through the [hve-core issue tracker](https://github.com/microsoft/hve-core/issues/new/choose). Include `mural auth status` output (with secrets redacted) and the operating system and devcontainer recipe in the report.

<!-- markdownlint-disable MD036 -->
_🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers._
<!-- markdownlint-enable MD036 -->
