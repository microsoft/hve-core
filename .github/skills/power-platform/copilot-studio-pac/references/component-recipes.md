---
title: Copilot Studio pac Component Recipes
description: Field-level recipe map for every verified Copilot Studio mcs.yml component, with root kind, required keys, and placeholder-only YAML snippets.
author: microsoft/hve-core
ms.date: 2026-07-01
ms.topic: reference
keywords:
  - copilot-studio
  - power-platform
  - mcs-yml
  - knowledge
  - actions
---

# Copilot Studio pac Component Recipes

Every recipe below is verified unless it is called out as unverified. All
values are placeholder-only. Substitute real environment values only through
the gated pipeline, never inline in authored source.

## Component map

| Component                 | File                           | Root `kind` or key                               | Flow             |
|---------------------------|--------------------------------|--------------------------------------------------|------------------|
| Agent core                | `agent.mcs.yml`                | `kind: GptComponentMetadata`                     | Flow 1 or Flow 2 |
| Suggested prompts         | `agent.mcs.yml`                | `conversationStarters:`                          | Flow 1 or Flow 2 |
| Knowledge, public site    | `knowledge/<name>.mcs.yml`     | `kind: KnowledgeSourceConfiguration`             | Flow 2           |
| Conversational trigger    | `topics/<name>.mcs.yml`        | `kind: AdaptiveDialog` with `OnRecognizedIntent` | Flow 1 or Flow 2 |
| MCP tool or action        | `actions/<name>.mcs.yml`       | `kind: TaskDialog`                               | Flow 2           |
| Connection references     | `connectionreferences.mcs.yml` | `connectionReferences:`                          | Flow 2           |
| Knowledge answering topic | `topics/Search.mcs.yml`        | `kind: AdaptiveDialog` with `OnUnknownIntent`    | Flow 2           |

## Agent core

Root `kind` is `GptComponentMetadata`.

| Key                               | Shape                             | Notes                                                   |
|-----------------------------------|-----------------------------------|---------------------------------------------------------|
| `instructions`                    | YAML literal block scalar (`\|-`) | Persona and behavior text                               |
| `gptCapabilities.webBrowsing`     | boolean                           | Enables web browsing                                    |
| `gptCapabilities.codeInterpreter` | boolean                           | Enables code interpreter                                |
| `aISettings.model.modelNameHint`  | string                            | Pins a named model, for example `GPT5Chat`              |
| `aISettings.model.kind`           | string                            | Use `CurrentModels` to float to the environment default |

```yaml
kind: GptComponentMetadata
displayName: <Agent Name>
description: <one line agent description>
instructions: |-
  You are <Agent Name>, an assistant that helps with <task domain>.
  Answer from the configured knowledge sources when they are relevant.
gptCapabilities:
  webBrowsing: true
  codeInterpreter: false
aISettings:
  model:
    modelNameHint: GPT5Chat
```

The `modelNameHint` and `kind: CurrentModels` forms are mutually exclusive
alternatives under `aISettings.model`.

## Suggested prompts

Suggested prompts are a `conversationStarters` list on the agent core. Each
item has a `title` (chip label) and a `text` (prompt sent on click).

```yaml
conversationStarters:
  - title: <starter one title>
    text: <prompt text sent when the first starter is clicked>
  - title: <starter two title>
    text: <prompt text sent when the second starter is clicked>
```

## Knowledge, public site

Root `kind` is `KnowledgeSourceConfiguration`. Only the
`PublicSiteSearchSource` source kind is verified. The `site` value is a public
URL such as `https://learn.microsoft.com` or `https://contoso.com`.

```yaml
kind: KnowledgeSourceConfiguration
displayName: <knowledge source display name>
source:
  kind: PublicSiteSearchSource
  site: https://contoso.com
```

Non-public source kinds (SharePoint, file-upload, Dataverse) are unverified.
See the unverified section of `SKILL.md`.

## Conversational trigger topic

Root `kind` is `AdaptiveDialog`. The `beginDialog.kind` is `OnRecognizedIntent`.
The intent carries a `displayName` and a `triggerQueries` phrase list.

```yaml
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  intent:
    displayName: <Intent Display Name>
    triggerQueries:
      - <example trigger phrase one>
      - <example trigger phrase two>
  actions:
    - kind: SendActivity
      id: <sendActivityActionId>
      activity: <text the agent replies with>
```

Verified system topic kinds that reuse this shape under `beginDialog.kind` are
`OnEscalate` and `OnUnknownIntent`. Autonomous or event triggers are
unverified.

## MCP tool or action

Root `kind` is `TaskDialog`. The `action.kind` is
`InvokeExternalAgentTaskAction`.

| Key                                   | Value                                           |
|---------------------------------------|-------------------------------------------------|
| `action.connectionReference`          | `<connectionReferenceLogicalName>`              |
| `action.connectionProperties.mode`    | `Invoker`                                       |
| `action.operationDetails.kind`        | `ModelContextProtocolMetadata`                  |
| `action.operationDetails.operationId` | for example `mcp_MeServer` or `mcp_m365copilot` |

```yaml
kind: TaskDialog
action:
  kind: InvokeExternalAgentTaskAction
  connectionReference: <connectionReferenceLogicalName>
  connectionProperties:
    mode: Invoker
  operationDetails:
    kind: ModelContextProtocolMetadata
    operationId: mcp_MeServer
```

## Connection references

Root key is `connectionReferences`, a list. Each entry pairs a
`connectionReferenceLogicalName` with a `connectorId` under
`/providers/Microsoft.PowerApps/apis/shared_*`.

```yaml
connectionReferences:
  - connectionReferenceLogicalName: <connectionReferenceLogicalName>
    connectorId: /providers/Microsoft.PowerApps/apis/shared_a365memcp
  - connectionReferenceLogicalName: <secondConnectionReferenceLogicalName>
    connectorId: /providers/Microsoft.PowerApps/apis/shared_a365copilotchatmcp
```

Observed connector-to-operation pairings:

| `connectorId` shared prefix | Paired `operationId` |
|-----------------------------|----------------------|
| `shared_a365memcp`          | `mcp_MeServer`       |
| `shared_a365copilotchatmcp` | `mcp_m365copilot`    |

## Knowledge answering topic

Root `kind` is `AdaptiveDialog` with `beginDialog.kind` `OnUnknownIntent`. The
system "Conversational boosting" topic runs `SearchAndSummarizeContent`, gates
on `=!IsBlank(Topic.Answer)` inside a `ConditionGroup`, then ends the dialog
with `clearTopicQueue: true`. A custom triggered topic mirrors this action
shape.

```yaml
kind: AdaptiveDialog
beginDialog:
  kind: OnUnknownIntent
  actions:
    - kind: SearchAndSummarizeContent
      id: <searchActionId>
      userInput: =System.Activity.Text
    - kind: ConditionGroup
      id: <conditionGroupId>
      conditions:
        - id: <hasAnswerConditionId>
          condition: =!IsBlank(Topic.Answer)
          actions:
            - kind: SendActivity
              id: <sendAnswerActionId>
              activity: "{Topic.Answer}"
    - kind: EndDialog
      id: <endDialogActionId>
      clearTopicQueue: true
```

The exact `elseActions` schema of `ConditionGroup` is unverified.
