---
description: "How an organization distributes Copilot OTel settings to a fleet through managed settings, covering the three delivery channels, their precedence, and the agent-host split"
---

# Organization distribution: managed settings

## Intended Use

Read this when the user wants OTel configuration applied across a fleet rather than on one machine. It carries the three managed-settings delivery channels and their precedence, the `telemetry` block shape, the extension-versus-agent-host split that silently drops headers, and how a developer diagnoses whether a policy applies to them.

## Nothing in this mode is applied by the agent

This mode explains the mechanism and drafts the configuration. Distributing it changes organization state on machines the agent cannot see, so the administrator applies it. Produce the block, name the channel, state the consequences, and stop.

## The configuration

Administrators mandate OTel export through the `telemetry` block in Copilot managed settings, so telemetry reaches an approved collector without each developer configuring anything.

```json
{
  "telemetry": {
    "enabled": true,
    "endpoint": "http://127.0.0.1:4318",
    "protocol": "otlp-http",
    "captureContent": false,
    "lockCaptureContent": true,
    "serviceName": "copilot-chat",
    "resourceAttributes": { "team.id": "platform", "department": "engineering" }
  }
}
```

The endpoint is the per-workstation relay, not the fleet receiver, and there is no `headers` field. One endpoint applies to both the extension and the agent host, so pointing it at the relay is what lets both authenticate: the relay adds the fleet credential on its upstream hop, and no fleet credential is distributed to workstations through managed settings. `examples/azure/agent-host-relay/` ships that relay.

Deploy and verify the relay on every workstation **before** distributing this block. Once it applies, a workstation without a running relay sends no telemetry at all rather than sending it directly, and nothing queues it. Rolling back means restoring the fleet endpoint and its `headers` block, which also restores the agent-host gap.

`protocol` must be `otlp-http`. The relay exposes port 4318 only; there is no gRPC listener, so `otlp-grpc` reaches nothing.

`lockCaptureContent` is worth deciding deliberately rather than copying. It removes the developer's ability to turn content capture on, which is usually what an organization wants, and it is also the setting most likely to be missed when the block is adapted.

`headers` is a managed-settings field and has no user-settings counterpart in the builds this skill has verified. An operator who goes looking for it in the settings UI will not find it; that is the surface being different, not the field being missing. Its delivery is also what produces the agent-host split below, and why the relay topology avoids using it.

`resourceAttributes` is where fleet-wide dimensions belong. Anything put here lands on every span from every developer, so keep it to team and org structure. Do not put anything that identifies an individual in it.

## The three channels

Exactly one channel applies. The highest-precedence channel that supplies **any** managed settings wins outright; channels do not merge. An organization that sets one value by MDM and expects the rest to come from a file will get only the MDM value.

| Precedence | Channel        | Location                                                                                                                                                                                  |
|------------|----------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Highest    | Native MDM     | macOS `com.github.copilot` managed preferences; Windows `HKLM\SOFTWARE\Policies\GitHubCopilot`                                                                                            |
| Middle     | Server-managed | `copilot/managed-settings.json` on the GitHub enterprise or organization                                                                                                                  |
| Lowest     | File-based     | macOS `/Library/Application Support/GitHubCopilot/managed-settings.json`; Windows `%ProgramFiles%\GitHubCopilot\managed-settings.json`; Linux `/etc/github-copilot/managed-settings.json` |

Channel precedence enforcement begins in VS Code 1.128. Below that version the behavior differs, so state the fleet's minimum version before promising precedence.

## Four things that decide a rollout

* **A managed value beats environment variables and user settings.** Once set, developers cannot redirect telemetry to their own collector. That is usually the point, and it is also why a wrong endpoint in a managed block is a fleet-wide outage rather than one person's problem. With the relay topology, an unhealthy relay is the same kind of outage, scoped to one workstation.
* **Managed `telemetry.headers` reach the extension exporter and not the agent host.** They are applied directly rather than through environment variables, which is deliberate: it stops an auth token leaking into spawned tool subprocesses. The consequence is a silent split, where extension telemetry authenticates and agent-host telemetry does not. Against a receiver that requires authentication this is data loss, not degraded data: the rejection is a non-retryable HTTP 401 or gRPC `UNAUTHENTICATED`, so the export is dropped rather than queued. Sending both emitters to the loopback relay is what closes it, which is why the block above sets no headers at all.
* **The agent host computes its telemetry configuration at start.** Changing a managed value requires a VS Code reload on every affected machine, not just a policy refresh.
* **A developer can find out what applies to them.** **Developer: Policy Diagnostics** from the command palette is the per-device discriminator. It answers "is my setting being overridden" without guessing.

## What to hand the administrator

1. The `telemetry` block, with any resource attributes filled in from what the user supplied. The endpoint is the loopback relay.
2. The chosen channel and its exact path or registry key for each platform in the fleet.
3. The precedence warning: this channel wins entirely, so everything the organization intends to manage must be in this one place.
4. The reload requirement.
5. The relay prerequisite: every workstation needs a healthy relay before this block applies, and the rollback is the previous endpoint plus its `headers` block.
6. The credential question, which the Azure reference covers: whatever authenticates the collector will exist on every workstation, now inside each relay's environment file rather than in managed settings.

## Links

* [Manage AI settings in enterprise environments](https://code.visualstudio.com/docs/enterprise/ai-settings)
* [Monitor agent usage with OpenTelemetry](https://code.visualstudio.com/docs/agents/guides/monitoring-agents)

