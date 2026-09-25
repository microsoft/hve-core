---
title: "Transparency Note for HVE Core"
description: "What HVE Core does, how we test it, its limitations, and what you should know before using it with GitHub Copilot."
author: HVE Core Maintainers
ms.date: 2026-09-24
ms.topic: overview
keywords:
  - responsible-ai
  - rai
  - transparency-note
  - hve-core
  - copilot
estimated_reading_time: 10
---

## About HVE Core

HVE Core provides reusable agents, prompts, instructions, skills, and tools for
AI-assisted engineering. You can use them with GitHub Copilot to research a
problem, plan changes, write code, review work, or prepare documents for your
team.

The files come from
[`microsoft/hve-core`](https://github.com/microsoft/hve-core). HVE Core does not
train or host AI models. GitHub Copilot and any services you connect have their
own permissions, safety features, data practices, and terms.

## How it works and who is responsible

GitHub Copilot reads HVE Core instructions during a session and uses them to
guide its responses and actions. Depending on the task and the permissions you
grant, it may also run local scripts or call external tools. Installing the
files does not by itself run every included capability.

| Who                                              | Responsibility                                                                                                                                   |
|--------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| HVE Core Maintainers                             | Maintain the instructions, tools, tests, documentation, and release process shipped by this repository                                           |
| GitHub Copilot and model providers               | Operate the AI services and provide their model safeguards, account controls, and data handling                                                  |
| Copilot clients, such as VS Code and Copilot CLI | Provide tool permissions, approval controls, and session records according to the client and configuration                                       |
| Connected service providers                      | Process API requests and manage the service's storage, access controls, and retention                                                            |
| You and your organization                        | Choose capabilities, protect credentials and source data, grant permissions, review outputs, and decide whether the results are suitable for use |

HVE Core instructions can recommend a model, but the Copilot client and your
configuration determine which model runs. HVE Core does not replace the client's
safety systems or add its own runtime content filter.

## Capabilities and risks

The [agent catalog](docs/reference/agents/README.md) and
[skill catalog](docs/reference/skills/README.md) list the available capabilities.
They cover software development, documentation, planning, backlog management,
Design Thinking, and security, privacy, accessibility, and Responsible AI work.

| What can happen                                                                       | What HVE Core provides                                                                                  | What you should do                                                                                         | Learn more                                                                         |
|---------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| A plan or review can influence a consequential decision                               | Workflows for recording evidence, assumptions, decisions, and review needs                              | Treat outputs as drafts. Ask a qualified person to check findings and make the final decision              | [Agents](docs/reference/agents/README.md)                                          |
| An agent can edit files, run commands, or update a tracker                            | Workflow instructions for scope, approval, and delegated tasks                                          | Review the permissions you grant and the changes an agent proposes                                         | [Security model](docs/security/security-model.md)                                  |
| A tool can send data to an external service                                           | Optional API tools and guidance for configuring them                                                    | Check the provider's terms, use limited credentials, and send only data you are authorized to share        | [Skills](docs/reference/skills/README.md)                                          |
| Saved files or memory can retain sensitive context                                    | Local tracking conventions and workflows that can use Copilot memory                                    | Inspect saved content, control access, and remove it when it is no longer needed                           | [Security model](docs/security/security-model.md)                                  |
| Slides, voice-over, or personas can be mistaken for authentic accounts of real people | Tools for turning authored material into media; customer cards use a template-based PowerPoint workflow | Remove identifying details, label synthetic content, check for stereotypes, and review sharing permissions | [Customer Card Render](docs/reference/skills/experimental/customer-card-render.md) |
| A document, issue, or web page can contain instructions that try to redirect an agent | Some workflows explicitly tell agents to treat imported content as data, not instructions               | Treat external content as untrusted and review tool actions; instruction coverage varies                   | [Security model](docs/security/security-model.md)                                  |
| The same task can produce different results across models or clients                  | Supported-client guidance and tests for selected workflows                                              | Test with the model, tools, language, and environment you plan to use                                      | [AI artifact architecture](docs/architecture/ai-artifacts.md)                      |

## Intended uses and uses requiring extra care

HVE Core helps engineers and teams:

* Research, plan, implement, and review software changes.
* Apply shared coding and documentation conventions.
* Draft requirements, architecture decisions, backlog items, and assessments
  for security, privacy, accessibility, and Responsible AI.
* Facilitate Design Thinking and prepare stakeholder materials.
* Run the repository's development, validation, and release tools.
* Adapt selected patterns into workflows they maintain themselves.

Use additional testing and qualified human review when an output could affect
a person's safety, rights, employment, education, housing, insurance,
healthcare, credit, or legal status. AI output must not be the sole basis for
these decisions.

Do not use HVE Core to infer sensitive personal traits from unrelated data,
rank developers using agent activity or review findings, evade safety controls,
or present generated assessments as professional approval or certification.
Do not portray a synthetic persona as a real participant.

Components labeled `experimental` may change substantially. Inclusion in a
Stable release does not make a capability suitable for every production use.

## Models, connected services, and your data

HVE Core targets GitHub Copilot Chat in Visual Studio Code and GitHub Copilot
CLI. Clients do not load every type of customization in the same way. For
example, Copilot CLI does not automatically apply instructions contained in a
plugin. See the [CLI plugin guidance](docs/getting-started/methods/cli-plugins.md).

In a typical session:

1. Copilot loads the selected instructions and relevant workspace context.
2. It sends prompts and context to the configured model.
3. It may run tools locally or contact services allowed by your configuration
   and permissions.
4. It can save working files locally or use the client's memory feature.

Before sending project content, review
[responsible use of GitHub Copilot](https://docs.github.com/en/copilot/responsible-use)
and the
[VS Code Copilot account and data-handling guidance](https://code.visualstudio.com/docs/setup/copilot).
Your Copilot plan, organization policies, and model-provider terms determine
how that data is handled.

Optional tools have separate data paths.
[Mural](docs/reference/skills/experimental/mural.md),
[Jira](docs/reference/skills/project-planning/jira.md), and
[GitLab](docs/reference/skills/project-planning/gitlab.md) use configured APIs.
[TTS Voice-over](docs/reference/skills/experimental/tts-voiceover.md) uses Azure
Speech to create audio from authored notes. If you use a Microsoft AI Service
covered by Microsoft Product Terms, follow the
[Code of Conduct for Microsoft AI Services](https://learn.microsoft.com/legal/ai-code-of-conduct).
That code governs covered services; it is not HVE Core's license or a substitute
for GitHub Copilot's terms.

Keep credentials out of prompts, source files, saved working notes, and logs.
Use the credential storage and permissions documented for each tool.

### Telemetry and saved data

HVE Core does not operate a central telemetry collector, and the plugin ships
no hooks. The [Copilot OpenTelemetry Metrics](docs/customization/copilot-otel-metrics.md)
skill helps you configure optional export to a receiver you control.

This is separate from telemetry collected by VS Code, Copilot, or other
extensions. Review [VS Code telemetry settings](https://code.visualstudio.com/docs/configure/telemetry)
and the relevant provider's data policy. Disabling VS Code telemetry does not
by itself stop prompts being sent to an AI provider.

<details>
<summary>Cleaning up data from the retired telemetry hook</summary>

Older HVE Core versions included a session hook that wrote local telemetry.
Removing that hook stops its new writes but does not delete existing data.
If you used it, inspect these locations and remove only the files you no longer
need:

* The project telemetry store named by `HVE_TELEMETRY_DIR`, or the `telemetry`
  folder inside the project's local Copilot tracking directory
* The sensitive `raw-input.jsonl` capture in that store
* The cross-project registry at `~/.hve/telemetry-dirs` or
  `$HVE_HOME/telemetry-dirs`, including the older `telemetry-dirs.txt` name
* Generated `generate-report` and `clean-telemetry` launchers (`.sh` or `.ps1`)
  and `report.generated.html` under `~/.hve` or `$HVE_HOME`

The registry can help you find stores in other projects. The old cleanup
launchers may refer to scripts that are no longer installed. Current HVE Core
does not remove this data for you.

</details>

## Limitations

AI can produce plausible but incorrect, incomplete, biased, or insecure output.
An agent review can miss real problems or flag problems that do not exist.
Clear prompts and good source material help, but do not eliminate these risks.

Results also depend on the model, Copilot version, available context, enabled
tools, and external services. Guidance and evaluation coverage are strongest
for English and the technologies represented in the repository. Other clients
and languages may behave differently.

Copied or modified files can lose their connection to release history and
repository checks. Pin a release or commit when consistency matters, and record
the model and client you use. Identical inputs can still produce different
responses.

### Considerations for your workflow

GitHub Copilot and its model providers supply the underlying AI capabilities
and service safeguards. The Copilot client, such as VS Code or Copilot CLI,
provides tool permissions, approval controls, and session records. HVE Core
adds task instructions, workflows, and supporting tools. You and your
organization choose the settings and review the results before use.

These protections depend on the client and configuration. They do not guarantee
that generated content is correct, accessible, or free from bias. Keep AI
involvement clear when sharing content, and check that available records meet
your organization's needs. Treat external content as untrusted; workflow
instructions alone do not prevent prompt injection.

## How we test changes

Every pull request that changes an HVE Core agent, prompt, instruction, or skill
runs that artifact through the repository's evaluation pipeline. Results appear
on the pull request as blocking failures or advisory findings. These checks
help catch regressions, but they do not guarantee identical behavior across
every model, host, or use case.

Different checks answer different questions:

| Check                | What it tests                                                                                                                           |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| File checks          | Whether files have the expected structure, metadata, links, and configuration                                                           |
| Script tests         | Whether covered code paths in the supporting tools behave as expected                                                                   |
| Vally behavior tests | Whether selected prompts and workflows meet their expected behavior with the configured models and grading rules                        |
| Planner checks       | Whether the accessibility, Design Thinking, privacy, Responsible AI, security, and SSSC planners follow selected workflow requirements  |
| Content moderation   | Whether evaluation content raises concerns under the configured safety checks                                                           |
| Baseline comparisons | Whether selected answers change when HVE Core instructions are added; these comparisons are currently advisory and limited to RPI Agent |
| Human review         | Whether changes and their test results are suitable for release                                                                         |

Checks that call AI models require CI credentials and do not run on fork pull
requests. See [Evals in CI](docs/contributing/evals-ci.md) for execution rules,
coverage, and result reporting. A passing merge check does not mean every
advisory finding passed.

## Safeguards and human review

HVE Core workflows use instructions for task scope, approvals, source
citations, saved decisions, and domain-specific disclaimers. Their coverage
varies by workflow. Actual tool access depends on the Copilot client and the
permissions you grant, not on instructions alone.

Keep a qualified person responsible for consequential decisions. Confident
wording, detailed reports, or a favorable review verdict are not substitutes
for checking the underlying evidence. Only a human can complete a required
human-review acknowledgment.

For generated media and personas:

* Remove or generalize real names, identifying quotes, photographs, and other
  personal details before creating material for sharing.
* Clearly label invented personas and AI-generated media. Check for stereotypes
  and unsupported assumptions about people.
* Keep illustrative personas visibly distinct from portraits of real people.
  The customer-card renderer does not automatically label personas as synthetic
  or remove identifying details.
* Review consent and permissions before sharing outside the original engagement,
  republishing, using the material in marketing, or adding it to an evaluation
  dataset.

## Before you use HVE Core

1. Choose the agents and skills needed for your task. Read their documentation
   and any linked security models.
2. Review permissions and external services before enabling them. Grant only
   the access the task needs.
3. Test representative tasks, failure cases, and untrusted inputs with the
   client and model you intend to use.
4. Review generated code, documents, and proposed external actions before
   relying on them.
5. Inspect saved working files and host memory before sharing a workspace,
   screenshot, recording, or exported document.
6. Record the HVE Core version you use and review changes before upgrading.
   Preserve copyright notices, license information, and attribution on copies.

For VS Code, follow the
[AI-assisted development security guidance](https://code.visualstudio.com/docs/agents/run/security)
for workspace trust, tool approvals, sandboxing, and reviewing changes.
Auto-approval reduces opportunities to catch mistakes before tools act.

Stable and PreRelease use the same component-selection policy but can contain
different revisions. Stable releases follow promotion review; copying files
from a development branch does not provide the same release assurance.

## Updates and feedback

HVE Core Maintainers review this note at least every 180 days. They also review
and update it when:

* Intended uses or functionality change.
* The product moves to a new release stage.
* New information about reliability, safety, accuracy, or performance becomes
  available.
* Data handling, external services, supported clients, distribution methods,
  permissions, or review responsibilities change.

The [contributor guidance](CONTRIBUTING.md) describes when a change requires an
update. Report documentation problems, accessibility issues, or Responsible AI
concerns through [GitHub issues](https://github.com/microsoft/hve-core/issues).
Do not include secrets or personal data in a public report. Report suspected
vulnerabilities privately using [SECURITY.md](SECURITY.md).

For broader context, see [Microsoft's responsible AI principles](https://www.microsoft.com/ai/principles-and-approach).

## Disclaimer

HVE Core outputs are advisory. They do not provide professional advice,
approval, certification, or compliance sign-off. You remain responsible for
checking results, deciding whether they are fit for purpose, and meeting the
laws, policies, and service terms that apply to your use.

This note describes the repository at the document date. It does not certify
HVE Core or make assurances about downstream models and services.

## About this document

| Field         | Value                           |
|---------------|---------------------------------|
| System        | HVE Core (`microsoft/hve-core`) |
| Document type | Transparency Note               |
| Published     | 2026-06-11                      |

© 2026 Microsoft Corporation. All rights reserved. This document is provided
"as-is" and for informational purposes only, without warranty. Information and
links may change without notice. You bear the risk of using it. Examples are
illustrative and do not imply a real association.

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
