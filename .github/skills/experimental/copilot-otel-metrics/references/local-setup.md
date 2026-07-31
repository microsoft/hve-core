---
description: "Procedure for enabling GitHub Copilot's OpenTelemetry export in the user's global VS Code settings, including the diff-and-confirm write and the manual alternative"
---

# Local setup: enable Copilot OTel export

## Intended Use

Read this before writing or advising on any `github.copilot.chat.otel.*` setting. It carries the settings inventory, the platform-specific file paths, the profile resolution pitfall that makes a careless write a silent no-op, the per-key upsert contract, and the paste-it-yourself alternative for a user who declines the assisted write.

## The settings

Eleven settings exist. Three of them turn export on; the remaining eight tune it. Enumerate the live set before quoting this table, because it describes one build.

| Setting                                           | Type    | Default                   | Sets what                                                                  |
|---------------------------------------------------|---------|---------------------------|----------------------------------------------------------------------------|
| `github.copilot.chat.otel.enabled`                | boolean | `false`                   | Master switch for trace, metric, and log emission                          |
| `github.copilot.chat.otel.exporterType`           | string  | `"otlp-http"`             | One of `otlp-grpc`, `otlp-http`, `console`, `file`                         |
| `github.copilot.chat.otel.otlpEndpoint`           | string  | `"http://localhost:4318"` | Where the data goes                                                        |
| `github.copilot.chat.otel.protocol`               | string  | `""`                      | One of `""`, `http/json`, `http/protobuf`, `grpc`; empty means `http/json` |
| `github.copilot.chat.otel.headers`                | object  | `{}`                      | Extra OTLP headers such as auth tokens, applied to the exporter directly   |
| `github.copilot.chat.otel.serviceName`            | string  | `""`                      | The `service.name` resource attribute                                      |
| `github.copilot.chat.otel.resourceAttributes`     | object  | `{}`                      | Extra resource attributes, merged per key with the environment             |
| `github.copilot.chat.otel.captureContent`         | boolean | `false`                   | Prompts, responses, system instructions, and tool definitions on spans     |
| `github.copilot.chat.otel.maxAttributeSizeChars`  | integer | `0`                       | Truncation limit in characters; `0` disables truncation                    |
| `github.copilot.chat.otel.outfile`                | string  | `""`                      | JSON-lines output path; setting it forces the `file` exporter              |
| `github.copilot.chat.otel.dbSpanExporter.enabled` | boolean | `false`                   | Local SQLite span exporter; turning it on turns OTel on                    |

Every one of them is `scope: application`. That single fact drives the rest of this procedure.

A minimal local setup writes three keys and leaves the other eight at their defaults:

```json
{
  "github.copilot.chat.otel.enabled": true,
  "github.copilot.chat.otel.exporterType": "otlp-http",
  "github.copilot.chat.otel.otlpEndpoint": "http://localhost:4318"
}
```

Do not add `captureContent` to that block. Raise what it does, and what happens without it, before the user chooses; the position to take is in `SKILL.md`.

### Precedence

Enterprise policy beats environment variable beats user setting beats default. A user whose setting appears to be ignored is usually looking at a policy or a stray environment variable, not a failed write.

| Setting                 | Environment variable                    |
|-------------------------|-----------------------------------------|
| `enabled`               | `COPILOT_OTEL_ENABLED`                  |
| `captureContent`        | `COPILOT_OTEL_CAPTURE_CONTENT`          |
| `otlpEndpoint`          | `OTEL_EXPORTER_OTLP_ENDPOINT`           |
| `protocol`              | `OTEL_EXPORTER_OTLP_PROTOCOL`           |
| `serviceName`           | `OTEL_SERVICE_NAME`                     |
| `resourceAttributes`    | `OTEL_RESOURCE_ATTRIBUTES`              |
| `headers`               | `OTEL_EXPORTER_OTLP_HEADERS`            |
| `maxAttributeSizeChars` | `COPILOT_OTEL_MAX_ATTRIBUTE_SIZE_CHARS` |

`exporterType`, `outfile`, and `dbSpanExporter.enabled` declare no environment variable in the manifest inspected for this revision; they are set through user settings or enterprise policy. Confirm against the installed build before telling a user an environment variable will or will not apply, because this mapping moves with the extension.

The VS Code documentation renders "This setting is managed at the organization level. Contact your administrator to change it." next to these settings. That means the setting *can* be policy-managed, not that it *is*. Have the user run **Developer: Policy Diagnostics** from the command palette to find out which applies to them.

## Find the file that actually resolves

Application-scoped settings live only in the global `settings.json`, and that file resolves from the **default profile no matter which profile is active**. Writing into `User/profiles/<id>/settings.json` therefore accomplishes nothing for these keys, and it fails silently: no error, no warning, no telemetry.

| Platform | VS Code                                                 | VS Code Insiders                                                   |
|----------|---------------------------------------------------------|--------------------------------------------------------------------|
| macOS    | `~/Library/Application Support/Code/User/settings.json` | `~/Library/Application Support/Code - Insiders/User/settings.json` |
| Windows  | `%APPDATA%\Code\User\settings.json`                     | `%APPDATA%\Code - Insiders\User\settings.json`                     |
| Linux    | `~/.config/Code/User/settings.json`                     | `~/.config/Code - Insiders/User/settings.json`                     |

Confirm rather than infer. Have the user run **Preferences: Open Application Settings (JSON)** from the command palette; VS Code opens the exact file these settings resolve from. Ask which build they run before choosing a path, because a machine with both installed has both files and only one of them matters.

Stop and ask if the file cannot be identified with confidence. Do not write to a guessed path.

## The assisted write

Follow every step. Steps 1, 4, and 5 are what make this reversible and visible.

1. **Back up.** Copy the file alongside itself as `settings.json.bak-otel-<UTC timestamp>`, for example `settings.json.bak-otel-20260727T142530Z`. Tell the user the backup path and that restoring it is a file copy in the other direction. That path sits beside `settings.json`, outside the workspace; name it when asking for the write rather than treating it as a separate approval.
2. **Read the file as text.** If it does not exist or is empty, treat the content as `{}`. It is JSONC: it may contain `//` and `/* */` comments and trailing commas, all of which are legal and all of which the user wrote deliberately.
3. **Compute the change per key. Do not write yet.** Work out the exact edit without applying it, so step 4 has something to show.
   * For a key already present, the change replaces only its value span, leaving the key, its indentation, and any adjacent comment untouched.
   * For a key not present, it is collected and inserted immediately before the document's final `}`, matching the file's existing indentation and adding the separating comma to the previous last entry when one is needed.
   * Match keys at the document's top level only. `"github.copilot.chat.otel.enabled"` appearing inside a `[...]` override block or a nested object is a different key and is not a target.
   * **Never reserialize.** Reserializing the document destroys every comment and every formatting choice in a file the user owns.
4. **Show the exact diff and stop.** Present the computed change as a unified diff against the file on disk, and name the file path above it. Ask for approval. Do not fold this into a broader "shall I proceed" question that bundles other work.
5. **Apply the upsert**, exactly as shown in the approved diff and no more.
6. **Validate after writing.** Re-read the file and parse it with comments and trailing commas tolerated. If it does not parse, restore the backup immediately, tell the user it was restored, and hand them the manual block instead.
7. **Reload.** These settings are read at window startup. Have the user run **Developer: Reload Window**. A skipped reload is the single most common cause of an empty dashboard.

Every write gets its own diff and its own approval. An approval earlier in the session does not carry forward to the next key or the next value.

### Two caveats worth stating out loud

**Settings Sync.** If the user has Settings Sync on, a change to the global settings file propagates to their other machines. Whether a write made outside the running VS Code instance produces a sync conflict has not been confirmed, so say that it may and let the user decide whether to close VS Code first.

**Concurrent writes.** VS Code writes this file too. If the user changes a setting through the Settings UI while an assisted write is in flight, one of the two writes wins and the other is lost. The backup is the recovery path.

## The manual alternative

A user who declines the assisted write should lose nothing but keystrokes. Give them this, complete, without asking again:

> Run **Preferences: Open Application Settings (JSON)** from the command palette. Add these three keys inside the outermost `{ }`, keeping your existing keys and comments as they are. If a key is already there, change its value rather than adding a second copy.
>
> ```json
> "github.copilot.chat.otel.enabled": true,
> "github.copilot.chat.otel.exporterType": "otlp-http",
> "github.copilot.chat.otel.otlpEndpoint": "http://localhost:4318"
> ```
>
> Save, then run **Developer: Reload Window**.

Then point them at the verification reference, because a pasted block is exactly as unproven as a written one.

## Turning it off

Set `github.copilot.chat.otel.enabled` to `false` and reload the window. The other keys are inert while it is off, so there is no need to remove them. Data already in the store stays there until the store is cleared.

