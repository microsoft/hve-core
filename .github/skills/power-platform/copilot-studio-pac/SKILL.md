---
name: copilot-studio-pac
description: Verified Copilot Studio pac recipes for the init-pack-import and clone-edit-push flows, with placeholder mcs.yml for core, prompts, knowledge, triggers, MCP tools, and connections.
---

# copilot-studio-pac

## Overview

This skill encodes empirically verified recipes for authoring Microsoft
Copilot Studio agents with the Power Platform CLI (`pac`). It is consumed by
the Copilot Studio Agent Builder agent, which loads these recipes to emit
correct `*.mcs.yml` component files rather than guessing at schema shapes.

Every format below was confirmed by cloning real deployed agents and by
round-tripping a live agent through `pac`. Formats that were not confirmed are
isolated in the [Unverified patterns to confirm](#unverified-patterns-to-confirm)
section and MUST be treated as hypotheses, not facts.

All examples are placeholder-only. Angle-bracket tokens such as
`<publisherPrefix>`, `<copilotId>`, `<schemaName>`, and
`<connectionReferenceLogicalName>` are substituted with real environment values
only through the gated deployment pipeline described in
[Safety and boundary](#safety-and-boundary), never inline in authored source.

Reference material lives beside this file:

- `references/deploy-flows.md` gives the full command walkthrough for both flows.
- `references/component-recipes.md` gives a field-level recipe map for every component.
- `references/pac-verb-reference.md` lists the relevant `pac` verbs.
- `scripts/validate-topics.ps1` (with a `.sh` bash launcher) is the executable, fail-closed topic-integrity gate for the Builder's Phase 9 pre-pack step.

## Deployment flows

Two flows form the spine of the skill. The flow you pick determines which
components you can author.

### Flow 1: new agent (init, pack, solution import)

Use this flow to scaffold and ship a brand-new agent. It supports the agent
core, suggested prompts, and topics, but not knowledge or actions.

```bash
pac copilot init --name "<Agent Name>" --publisher-prefix <publisherPrefix> --template default
pac copilot pack --publisher-prefix <publisherPrefix> --project-dir <ws> --solution-name <solutionName> --output-path <dir>
pac solution import --path <dir>/<solutionName>.zip --publish-changes --force-overwrite
```

Notes:

- `pac copilot init` scaffolds a workspace containing `agent.mcs.yml`,
  `settings.mcs.yml`, `icon.png`, and a `topics/` directory. The
  `--template` value is `default` or `minimal`.
- `pac copilot pack` packages the workspace into a solution `.zip`. Here `<ws>`
  is the workspace directory that contains `agent.mcs.yml`.
- `pac solution import` deploys the packed solution to the environment.

Gotcha: `pac copilot pack` rejects a `knowledge/` directory and fails with
`Unsupported directory: knowledge/`. Knowledge sources and actions are not part
of Flow 1. Author them through Flow 2 instead.

### Flow 2: existing agent (clone, edit, push, publish)

Use this flow to edit an existing agent. It supports the full component
surface, including `knowledge/`, `actions/`, and `connectionreferences.mcs.yml`.

```bash
pac copilot clone --bot <copilotId or schemaName> --output-dir <dir>
# edit the *.mcs.yml files under the synced workspace at <dir>/<Agent Name>/
pac copilot push --project-dir <ws>
pac copilot publish --bot <copilotId>
```

Notes:

- `pac copilot clone` creates a synced workspace as a subfolder named after the
  agent. Editing happens inside that subfolder.
- `pac copilot push` requires a synced or cloned workspace and otherwise errors
  with `No synced workspace found`. Here `<ws>` is the folder that contains
  `agent.mcs.yml`.
- Pushing an action bound to a `connectionReference` requires that connection
  reference record to already exist in the environment (see Recipe 6).
  Otherwise `pac copilot push` fails with a `DataverseBadRequestException
  [IsvAborted]` reporting that a record does not exist in the
  `connectionreference` entity.
- `pac copilot publish` makes pushed changes live. It can fail transiently, so
  retry on failure. Publish may also report a `Failed` status whose timestamp
  does not advance across retries even though the change already landed; confirm
  success with `pac copilot list` or a `pac copilot clone` round-trip rather than
  trusting the publish verb's reported status.

## Capability to pac verb to mcs.yml recipe map

| Capability                      | Flow and pac verb                                  | File                           | Root `kind` or key                               |
|---------------------------------|----------------------------------------------------|--------------------------------|--------------------------------------------------|
| Agent core, instructions, model | Flow 1 `init` + `pack`, or Flow 2 `clone` + `push` | `agent.mcs.yml`                | `kind: GptComponentMetadata`                     |
| Suggested prompts               | Same as agent core                                 | `agent.mcs.yml`                | `conversationStarters:`                          |
| Knowledge, public site          | Flow 2 `clone` + `push`                            | `knowledge/<name>.mcs.yml`     | `kind: KnowledgeSourceConfiguration`             |
| Conversational trigger topic    | Flow 1 or Flow 2                                   | `topics/<name>.mcs.yml`        | `kind: AdaptiveDialog` with `OnRecognizedIntent` |
| MCP tool or action              | Flow 2 `clone` + `push`                            | `actions/<name>.mcs.yml`       | `kind: TaskDialog`                               |
| Connection references           | Flow 2 `clone` + `push`                            | `connectionreferences.mcs.yml` | `connectionReferences:`                          |
| Knowledge answering topic       | Flow 2, system topic                               | `topics/Search.mcs.yml`        | `kind: AdaptiveDialog` with `OnUnknownIntent`    |

## Component recipes

Each component below is a minimal, valid, placeholder-only snippet. See
`references/component-recipes.md` for field-level notes.

### 1. Agent core (`agent.mcs.yml`)

Root `kind` is `GptComponentMetadata`. The `instructions` value uses a YAML
literal block (`|-`). The `gptCapabilities` map toggles `webBrowsing` and
`codeInterpreter`. The `aISettings.model` map pins the model.

```yaml
kind: GptComponentMetadata
displayName: <Agent Name>
description: <one line agent description>
instructions: |-
  You are <Agent Name>, an assistant that helps with <task domain>.
  Answer from the configured knowledge sources when they are relevant.
  Keep responses concise and cite the source site when you use one.
gptCapabilities:
  webBrowsing: true
  codeInterpreter: false
aISettings:
  model:
    modelNameHint: GPT5Chat
```

The model can instead float to the environment default:

```yaml
aISettings:
  model:
    kind: CurrentModels
```

### 2. Suggested prompts (`conversationStarters:` in `agent.mcs.yml`)

The Copilot Studio "Suggested prompts" feature is authored as a
`conversationStarters` list on the agent core. Each item has a `title` (the
chip label) and a `text` (the prompt sent when the chip is clicked).

```yaml
conversationStarters:
  - title: <starter one title>
    text: <prompt text sent when the first starter is clicked>
  - title: <starter two title>
    text: <prompt text sent when the second starter is clicked>
```

### 3. Knowledge, public site (`knowledge/<name>.mcs.yml`)

Root `kind` is `KnowledgeSourceConfiguration`. Only the
`PublicSiteSearchSource` source kind is verified. The `site` value is a public
URL.

```yaml
kind: KnowledgeSourceConfiguration
displayName: <knowledge source display name>
source:
  kind: PublicSiteSearchSource
  site: https://learn.microsoft.com
```

### 4. Conversational trigger topic (`topics/<name>.mcs.yml`)

A conversational trigger is a topic whose root `kind` is `AdaptiveDialog` and
whose `beginDialog.kind` is `OnRecognizedIntent`. The intent carries a
`displayName` and a `triggerQueries` phrase list, followed by `actions`.

```yaml
kind: AdaptiveDialog
beginDialog:
  kind: OnRecognizedIntent
  intent:
    displayName: <Intent Display Name>
    triggerQueries:
      - <example trigger phrase one>
      - <example trigger phrase two>
      - <example trigger phrase three>
  actions:
    - kind: SendActivity
      id: <sendActivityActionId>
      activity: <text the agent replies with>
```

System topics reuse this shape with a different `beginDialog.kind`. Verified
system kinds are `OnEscalate` and `OnUnknownIntent`.

### 5. MCP tool or action (`actions/<name>.mcs.yml`)

Root `kind` is `TaskDialog`. The `action.kind` is
`InvokeExternalAgentTaskAction`. It binds to a connection reference by logical
name and declares Model Context Protocol operation details.

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

Observed `operationId` values include `mcp_MeServer` and `mcp_m365copilot`. The
named `connectionReference` must resolve to a connection reference record that
already exists in the environment — see Recipe 6; `pac copilot push` will not
create it.

### 5a. Custom (non-MCP) REST connector action (`actions/<name>.mcs.yml`)

Recipe 5 covers an MCP tool; a **custom REST connector** — stood up from an
OpenAPI definition, for example a public no-auth API — binds differently and has
a two-track reality: `pac` can create the connector and author the action, but a
runtime **connection** is a maker-portal step `pac` cannot perform.

**Step 1 — create the real connector (verified).**

```bash
pac connector create --api-definition-file <apiDefinition.swagger.json> --api-properties-file <apiProperties.json>
# → "Connector created with ID <guid>"; confirm with:
pac connector list
```

For a no-auth connector, `<apiProperties.json>` carries an empty
`connectionParameters` (`"connectionParameters": {}`). This step is verified — it
creates a real custom connector object in the environment.

**Step 2 — author the action (schema-accepted; round-trip pending).**

```yaml
kind: TaskDialog
action:
  kind: InvokeConnectorTaskAction
  connectionReference: <connectionReferenceLogicalName>
  connectionProperties:
    mode: Invoker
  operationDetails:
    kind: OpenApiOperationMetadata
    operationId: <operationIdFromOpenApi>
```

> `pac copilot push` **accepts this shape at schema validation** and proceeds to
> the Dataverse write, so the action YAML is not the blocker; the full server
> round-trip (clone-verify) is **not yet confirmed** because it depends on
> Steps 3–4. Treat as *schema-accepted, round-trip pending* — not verified
> schema — until a clone confirms it.

**Step 3 — pre-mint the connection reference (Recipe 6, custom-connector variant).**

Use the same mint-then-push dance as Recipe 6, but `connectorId` points at the
**custom** connector, not a `shared_*` one:

```yaml
connectionReferences:
  - connectionReferenceLogicalName: <connectionReferenceLogicalName>
    connectorId: /providers/Microsoft.PowerApps/apis/<customConnectorLogicalName>
```

Without this, `pac copilot push` fails identically to the MCP case:

```text
DataverseBadRequestException [IsvAborted] code 10000:
"A record with the specified key values does not exist in connectionreference entity"
```

The push reaches the Dataverse write and fails on the missing
connection-reference record, confirming the wall is the connection reference,
not the action schema.

**Step 4 — create the runtime connection (maker-portal step; the non-headless boundary).**

For the action to execute, a **connection** to the custom connector must exist.
The Power Platform CLI has **no `pac connection create` verb**, so this one step
is done in the maker portal — for a no-auth connector it is a single "Create
connection" click. `pac` creates the connector and authors and binds the action,
but cannot mint the connection.

**Two-track output.** The Builder emits (1) the part `pac` can automate —
connector create plus action `.mcs.yml` plus connection-reference pre-mint — and
(2) a short operator note for the one portal connection click. It must **never**
claim a custom-REST tool is "live" or "callable" from a `pac copilot push` alone.

### 6. Connection references (`connectionreferences.mcs.yml`)

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

Pairing observed in cloned agents: connector `shared_a365memcp` goes with
`operationId: mcp_MeServer`, and connector `shared_a365copilotchatmcp` goes
with `operationId: mcp_m365copilot`.

**Prerequisite: the connection reference record must pre-exist**

`pac copilot push` cannot create or mint a connection reference. Pushing an
action whose `connectionReference` names a logical name with no backing record
fails with `DataverseBadRequestException [IsvAborted]: "A record with the
specified key values does not exist in connectionreference entity"`. The MCP
connection being Connected in the environment is necessary but not sufficient —
the connection reference is a separate Dataverse solution component (component
type `371`) that must already exist. Mint it once through a solution import,
then push:

1. `pac solution unpack` the agent's exported solution zip. The structure is
   `Other\Customizations.xml`, `Other\Solution.xml`, `bots/`, and
   `botcomponents/`.
2. Add a `<connectionreferences>` node to `Other\Customizations.xml`, placed
   after `<EntityDataProviders />` and before `<Languages>`. Each entry sets the
   `connectionreferencelogicalname` attribute on the element and carries child
   elements `connectionreferencedisplayname`, `connectorid`
   (`/providers/Microsoft.PowerApps/apis/shared_*`), `iscustomizable`,
   `statecode`, and `statuscode`.
3. Carry the reference through this `<connectionreferences>` customizations node,
   not as a `<RootComponent type="371" ...>` in `Solution.xml`. Declaring it as
   a type-371 root component fails import with `Cannot add a Root Component ...
   of type 371 because it is not in the target system`, because root-component
   registration runs before customizations create the record. (An earlier wrong
   value `10062` fails with `Invalid component type provided 10062`; the correct
   type is `371`.) Leave `<RootComponents />` empty and let the customizations
   node create the record.
4. `pac solution pack --packagetype Unmanaged`, then
   `pac solution import --publish-changes` mints the record.
5. Once the record exists, the `pac copilot push` and `pac copilot publish` from
   Flow 2 succeed, and `pac copilot clone` round-trips both the action and the
   connection reference from server truth.

```bash
pac solution unpack --zipfile <solution.zip> --folder <src>
# add the <connectionreferences> node to <src>\Other\Customizations.xml (component type 371)
pac solution pack --zipfile <out.zip> --folder <src> --packagetype Unmanaged
pac solution import --path <out.zip> --publish-changes
# now the record exists; the copilot push/publish from Flow 2 will succeed
```

### 7. Knowledge answering topic (`topics/Search.mcs.yml`)

This is how the agent actually answers from knowledge. The system
"Conversational boosting" topic has root `kind` `AdaptiveDialog` and
`beginDialog.kind` `OnUnknownIntent`. It runs `SearchAndSummarizeContent`, then
a `ConditionGroup` gated on `=!IsBlank(Topic.Answer)`, then `EndDialog` with
`clearTopicQueue: true`. A custom triggered topic mirrors this action shape.

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

## Unverified patterns to confirm

The following were not confirmed against a live agent. Do not present them as
verified schema. Confirm each by cloning an agent that uses the feature and
reading the emitted YAML before relying on it.

1. Non-public knowledge source kinds. Only `PublicSiteSearchSource` is verified
   under `KnowledgeSourceConfiguration.source.kind`. SharePoint, file-upload,
   and Dataverse source kinds are unverified patterns to confirm.
2. Autonomous and event triggers. Only conversational topic triggers
   (`OnRecognizedIntent`) and the system topic kinds `OnEscalate` and
   `OnUnknownIntent` are verified. The autonomous or event trigger format
   behind the Copilot Studio "Triggers" tab is an unverified pattern to confirm.
3. `ConditionGroup` else branch. The `conditions` list with
   `condition: =!IsBlank(Topic.Answer)` is verified, but the exact
   `elseActions` schema of `ConditionGroup` is an unverified pattern to confirm.
4. Custom (non-MCP) REST connector action shape. `InvokeConnectorTaskAction`
   with `OpenApiOperationMetadata` (Recipe 5a) is accepted by `pac copilot push`
   schema validation, but its full server round-trip is pending a pre-minted
   connection reference and a portal-created connection. Confirm by cloning an
   agent that uses a custom-connector action and reading the emitted YAML.

## Prerequisites

- PowerShell 7.4 or later (`pwsh`).
- The `PowerShell-Yaml` module (repo-pinned 0.4.7):
  `Install-Module powershell-yaml -Scope CurrentUser`. hve-core CI provisions
  this module; install it locally to run the gate or its Pester tests.

## Topic-integrity gate (`scripts/validate-topics.ps1`)

The skill ships an executable, fail-closed validator that enforces the Copilot
Studio Agent Builder's Phase 9 pre-pack topic-integrity gate. Run it against a
scaffold root or a `topics/` directory before `pac copilot pack` or
`pac solution import`, and do not proceed while it reports a FAIL.

```bash
pwsh -File scripts/validate-topics.ps1 -Path <scaffold-root-or-topics-dir> [-StatePath <state.json>] [-JsonOut <out.json>]
```

The bash launcher forwards to the same engine and propagates its exit code:

```bash
./scripts/validate-topics.sh -Path <scaffold-root-or-topics-dir>   # bash wrapper -> pwsh
```

Exit codes: `0` every topic passes; `1` at least one topic FAILs (the gate is
fail-closed — stop the pack or import) or topicCount reconciliation fails; `2` a
usage, parse, IO, or missing-dependency error. An invalid `-Path` fails
parameter binding (`ValidateScript`) and surfaces as exit `1` (fail-closed).

The validator loads each `topics/<name>.mcs.yml` and checks:

- schema skeleton — the load-bearing `mcs.metadata`, `kind: AdaptiveDialog`,
  `beginDialog.kind`, and `beginDialog.id: main`;
- undeclared `{…}` tokens — every interpolation token resolves to a `System`,
  `Topic`, `Global`, or `Env` namespace;
- system-trigger collision — no custom topic reuses a system trigger kind
  (`OnConversationStart`, `OnUnknownIntent`, `OnEscalate`, `OnError`,
  `OnSignIn`), evaluated on each topic's own `beginDialog.kind`, and at most one
  topic per system trigger;
- `componentName` uniqueness and the filename-equals-`componentName` rule for
  custom topics (system topics are exempt via the canonical name map);
- topic-count reconciliation — `state.json topics.topicCount` equals the packed
  custom-topic count when a `state.json` is supplied.

It reads topic source only and never writes to the environment. It requires
PowerShell 7.4+ and the repo-pinned `PowerShell-Yaml` module
(`Install-Module powershell-yaml -Scope CurrentUser`).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Path` | Yes | Scaffold root (auto-discovers `workspace/topics/*.mcs.yml`) or a directory of `*.mcs.yml` files. |
| `-StatePath` | No | Explicit `state.json` for topicCount reconciliation. Auto-discovered under the scaffold root when omitted (prefers one inside `.copilot-tracking/`). |
| `-JsonOut` | No | Path to write a machine-readable JSON report. |
| `-AllowPrefix` | No | Declared variable namespaces treated as bound. Defaults to `System, Topic, Global, Env`. |

### Troubleshooting

- **Exit 2, "Required module 'powershell-yaml' is not installed"** — run
  `Install-Module powershell-yaml -Scope CurrentUser`.
- **A parameter binding error on `-Path`** — the path does not exist or is not a
  directory; pass a scaffold root or a `topics/` directory.
- **Exit 2, "YAML parse error"** — a `*.mcs.yml` file has invalid YAML; fix the
  syntax and re-run.
- **A `FAIL` line with `system-trigger-collision` / `reserved-name-collision`** —
  a custom topic uses (or its `componentName` matches) a built-in system topic;
  rename it or route to the system topic via a redirect instead.
- **`SCAFFOLD FAIL topicCount-reconciliation`** — `state.json topics.topicCount`
  does not equal the number of `OnRecognizedIntent` topic files; reconcile the
  count.

## Safety and boundary

Authoring in this skill emits source-controlled `*.mcs.yml` for human review
before anything reaches an environment. Provisioning and deployment are gated and attended: in-session deploys go to
an operator-designated environment — Dev/Test after explicit confirmation, and
Production only with the Phase 7 evaluation gate (evalPassed) and the
Phase 10 post-deploy Responsible AI behavior gate (raiApproved) green and
explicit, environment-named approval (Phase 8 provides the
raiDevTestCleared Dev/Test design clearance); the CI/CD pipeline is the
alternative/degrade executor for hands-off promotion. Identity for any data-accessing tool or
connection must come from the authenticated deployment context and never from a
user-typed name, email address, or ID. The recipes here are placeholder-only
and must be populated with environment values through the gated pipeline, not
inline.

The built-in MCP server (`pac copilot mcp --run`, invoked through `dnx`)
requires .NET 10 or later and uses stdio transport. Besides local
development and test invocation, it MAY serve as the Copilot Studio Agent
Builder's attended deploy execution channel against an operator-designated,
authenticated environment (Phase 10 of that agent). It is distinct from — and
is not — the deployed agent's runtime tools and actions channel, and it adds
no capability or gate: Production remains gated by the evaluation and
Responsible AI gates and explicit user approval.

## References

- `references/deploy-flows.md`: full command walkthrough for Flow 1 and Flow 2,
  workspace layout, and the pack knowledge gotcha.
- `references/component-recipes.md`: field-level recipe map for every component,
  with the root `kind` and required keys per file.
- `references/pac-verb-reference.md`: the relevant `pac copilot` and
  `pac solution` verbs, plus the local MCP server and template extraction notes.
