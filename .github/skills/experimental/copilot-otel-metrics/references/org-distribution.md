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
    "endpoint": "https://collector.example.internal:4318",
    "protocol": "otlp-http",
    "captureContent": false,
    "lockCaptureContent": true,
    "serviceName": "copilot-chat",
    "resourceAttributes": { "team.id": "platform", "department": "engineering" }
  }
}
```

`lockCaptureContent` is worth deciding deliberately rather than copying. It removes the developer's ability to turn content capture on, which is usually what an organization wants, and it is also the setting most likely to be missed when the block is adapted.

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

* **A managed value beats environment variables and user settings.** Once set, developers cannot redirect telemetry to their own collector. That is usually the point, and it is also why a wrong endpoint in a managed block is a fleet-wide outage rather than one person's problem.
* **Managed `telemetry.headers` reach the extension exporter and not the agent host.** They are applied directly rather than through environment variables, which is deliberate: it stops an auth token leaking into spawned tool subprocesses. The consequence is a silent split, where extension telemetry authenticates and agent-host telemetry does not. Expect it and check for it rather than discovering it as missing data.
* **The agent host computes its telemetry configuration at start.** Changing a managed value requires a VS Code reload on every affected machine, not just a policy refresh.
* **A developer can find out what applies to them.** **Developer: Policy Diagnostics** from the command palette is the per-device discriminator. It answers "is my setting being overridden" without guessing.

## What to hand the administrator

1. The `telemetry` block, with the endpoint and any resource attributes filled in from what the user supplied.
2. The chosen channel and its exact path or registry key for each platform in the fleet.
3. The precedence warning: this channel wins entirely, so everything the organization intends to manage must be in this one place.
4. The reload requirement.
5. The credential question, which the Azure reference covers: whatever authenticates the collector will exist on every workstation.

## Links

* [Manage AI settings in enterprise environments](https://code.visualstudio.com/docs/enterprise/ai-settings)
* [Monitor agent usage with OpenTelemetry](https://code.visualstudio.com/docs/agents/guides/monitoring-agents)

