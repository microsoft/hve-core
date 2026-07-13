---
title: "Transparency Note: HVE Core (May 2026)"
description: "Public Transparency Note for HVE Core, a prompt-engineering and agentic-customization framework distributed by microsoft/hve-core."
author: HVE Core Maintainers
ms.date: 2026-07-09
ms.topic: overview
keywords:
  - responsible-ai
  - rai
  - transparency-note
  - hve-core
  - copilot
estimated_reading_time: 14
---
## What is a Transparency Note?

A Transparency Note explains how an AI-related system works, the choices its maintainers made, and the limits to keep in mind when you decide whether and how to use it. The goal is to help you understand what the system can and cannot do, where a human needs to stay in control, and how to use it responsibly.

This note covers HVE Core: the files in the `microsoft/hve-core` repository. It does not cover the AI platforms that run those files, such as GitHub Copilot Chat in Visual Studio Code, the GitHub Copilot CLI, Microsoft Foundry, third-party model hosts, or other IDEs. Each of those has its own documentation and Transparency Note.

## The basics of HVE Core

HVE Core is a collection of text files and supporting tools that shape how GitHub Copilot behaves. It ships custom agents, prompts, instructions, skills, collections, PowerShell scripts, GitHub Actions workflows, and a Visual Studio Code extension. The point is to give engineering teams a ready-made, review-friendly starting point for AI-assisted software work.

HVE Core does not run any AI model itself. It does not train models, host inference, call external services while you use it, or process personal data on its own. All of the AI work happens on the host platform (Copilot Chat or the Copilot CLI). That leaves three areas where HVE Core still carries Responsible AI weight:

1. What the files tell the model to do, and what they say about it.
2. The trust people place in files that carry Microsoft branding through this repository and the official VS Code extension.
3. The saved-memory feature and the customer-handoff steps that some agents drive.

The appendices at the end add detail for the agents that most influence downstream decisions.

### Key terms

| Term                 | Meaning in HVE Core                                                                                                                                                      |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Artifact             | A file HVE Core ships: an agent, prompt, instruction, skill, collection, script, or workflow. Other tools read these files; the files do not run on their own.           |
| Custom agent         | A persona (`*.agent.md`) that Copilot Chat can take on to run a specialized workflow. An agent can call subagents and use instructions, prompts, and skills.             |
| Prompt               | A reusable user-message template (`*.prompt.md`) you load into a Copilot Chat or CLI session.                                                                            |
| Instructions         | Guidance (`*.instructions.md`) that shapes how the model responds for a given file type, language, or workflow.                                                          |
| Skill                | A self-contained capability package (`SKILL.md` plus optional scripts and references) that documents a reusable task.                                                    |
| Collection           | A bundle of files (`*.collection.yml` plus a description) that you can install as one unit.                                                                              |
| Subagent             | An agent that another agent calls for a focused task, such as a read-only researcher or a single implementation step.                                                    |
| Distribution channel | One of the ways HVE Core files reach you: the VS Code extension, the GitHub plugin marketplace, a direct git clone, or a copy placed in a customer repository.           |
| Host platform        | The Copilot surface that runs the model: GitHub Copilot Chat in Visual Studio Code, or the GitHub Copilot CLI. HVE Core does not include or replace it.                  |
| Memory layer         | The saved-notes feature the host platform offers. HVE Core agents may write notes scoped to a user, a session, or a repository. The host controls storage and retention. |
| Decision-shaping     | An agent whose output tends to drive downstream decisions by default: planning agents, code-review agents that gate pull requests, and customer-handoff agents.          |

## Capabilities

### How it works

HVE Core ships text files and supporting tools. When you load an HVE Core file into the host platform, three things happen:

1. The host platform reads the file into the session.
2. You work with the host's model, now shaped by the file's instructions.
3. The model's replies come back through the normal Copilot surface.

HVE Core has no model, no API, and no network calls while you author or install it. It ships one optional local telemetry hook that is disabled by default and, when you turn it on, records Copilot session lifecycle events to plaintext files on your own disk with no network egress.
The processed event stream stores derived signals (such as tool-input key names and a truncated prompt preview) rather than full payloads; a separate, explicit opt-in is required before any verbatim prompt or tool input is captured. See the [Local Telemetry guide](docs/customization/local-telemetry.md) for exactly what is captured and how to disable or remove it.
Validation tools (linters, frontmatter checks, Pester tests, plugin generation) run in CI on pull requests. Nothing runs on your machine unless you install the VS Code extension or run a packaged script yourself.

Most skills are pure authoring or validation helpers with no independent Responsible AI surface and are not called out individually. A few skills warrant specific mention because they assemble media outputs or depend on external services:

* The **Customer Card Render** skill assembles synthetic-persona slides from authored Design Thinking content through a template-driven PowerPoint pipeline; HVE Core has no image-generation model. When concept imagery is needed, the workflow emits prompts the operator runs on an external platform such as M365 Copilot, where the host's Responsible AI layers apply. The cards stay low-fidelity and carry disclosure, redaction, and stereotyping-review controls. See Appendix 5.
* The **PowerPoint Builder** and **TTS Voice-over** experimental skills turn authored YAML into slides and audio. They do not create likenesses of people or claim to be a real speaker; they assemble content that was written elsewhere. The TTS Voice-over skill depends on an external speech service (such as Azure Speech) that you provision and govern under its own subscription and terms.

#### Responsibility boundary

| Aspect                         | HVE Core (microsoft/hve-core)                                                                                                      | Host platform (Copilot Chat or CLI)                                                                                                     |
|--------------------------------|------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| Inference                      | None                                                                                                                               | All inference happens here                                                                                                              |
| Model selection and management | Recommends models in artifact frontmatter; cannot enforce a model choice                                                           | Selects, hosts, and operates the model                                                                                                  |
| Safety classifiers             | None                                                                                                                               | Provides input and output classification, jailbreak detection, content filters                                                          |
| User authentication            | None at the framework level; some skills authenticate to third-party services and carry a skill-specific threat model              | Manages identity, tenant scope, and access controls                                                                                     |
| Telemetry and feedback         | None at the artifact level; CI logs only                                                                                           | Collects user interaction telemetry per the [host's telemetry and privacy docs](https://code.visualstudio.com/docs/configure/telemetry) |
| Persistent memory              | Authors agents that write to memory; does not store memory itself                                                                  | Stores, retains, and exposes the memory layer                                                                                           |
| Attribution                    | Carries attribution through per-file copyright notices and SPDX license headers, and an optional attribution line where convention | Surfaces any attribution line to the user through the chat session                                                                      |

### Use cases

#### Intended uses

HVE Core is built for these situations:

* **Ready-made starting points for engineers, field teams, and other GitHub Copilot users.** Agents and prompts capture common workflows (research, planning, implementation, review, discovery) so you begin a task with structure already in place instead of authoring it from scratch.
* **Consistent coding standards through Copilot.** Per-language instructions and code-review agents bring shared guidance into Copilot when you work in C#, Python, PowerShell, Rust, Bash, Bicep, Terraform, and related stacks.
* **Help with governance-aware planning.** The RAI Planner, Security Planner, and SSSC Planner help teams structure assessments aligned with the NIST AI RMF, STRIDE, and the OpenSSF Scorecard family. These agents produce drafts; a qualified person must review and approve every output.
* **Backlog help for Azure DevOps, GitHub Issues, GitLab, and Jira.** Agents can search, draft, triage, and prepare updates for a human to review and approve.
* **Design Thinking facilitation in solution development work.** Coaching agents support a structured Design Thinking workflow. The Customer Card Render skill makes synthetic personas for stakeholder communication, under the limits in Appendix 5.
* **Project-planning drafts.** Agents help draft architecture decision records, business and product requirements documents, user journeys, and architecture diagrams for a human to refine.
* **Documentation upkeep.** Agents help keep docs in sync, check links, and apply consistent style across markdown.

#### When not to use HVE Core without extra care

HVE Core is a set of files, not a managed service. You stay responsible for the AI platform, the data that flows through it, and any action a person takes based on agent output. Do not use HVE Core files in these ways without your own design, testing, and human oversight:

* **Automated decisions in regulated areas.** Agent recommendations are advisory. Do not use them to decide finance, medical, legal, employment, education, housing, or insurance matters without qualified human review.
* **Guessing personal traits.** Do not repurpose agents to infer protected characteristics about people from stray data.
* **Assessing developer performance.** Do not repurpose HVE Core telemetry, code-review verdicts, or agent activity logs to rate, rank, or evaluate the people doing the work. These signals describe artifacts and workflows, not individual performance.
* **Synthetic media of real people without disclosure.** Customer Card Render makes synthetic personas only and keeps a low-fidelity style. Do not reconfigure it to render real, identifiable people or to drop the synthetic-media disclosure.
* **Evading safety controls.** Do not modify files to weaken the host platform's safety features.
* **Sole basis for high-stakes calls.** Agent output is not tuned to be the only input to a decision that significantly affects a person.
* **Unsupported clients.** HVE Core targets current Copilot Chat in VS Code and the Copilot CLI. Behavior on other clients, older versions, or third-party model hosts is not characterized.

Legal and regulatory considerations. Organizations need to evaluate potential specific legal and regulatory obligations when using any AI services and solutions, which may not be appropriate for use in every industry or scenario. Restrictions may vary based on regional or local regulatory requirements. Additionally, AI services or solutions are not designed for and may not be used in ways prohibited in applicable terms of service and relevant codes of conduct.

## Limitations

HVE Core is a set of files that depends on a downstream AI platform. That shapes its limits:

* **Inherits the downstream model's inherent properties.** Every HVE Core output is produced by a host-platform model, so it inherits that model's inherent properties: the model will sometimes fail, is not neutral, and is not bias-free. HVE Core cannot detect or correct these properties and adds no safety layer of its own.
* **No model of its own.** HVE Core cannot check what a model actually produces from its instructions. File quality is verified through linting, frontmatter checks, link checking, plugin-generation gates, and human pull-request review. Whether the output fits a given model and prompt depends on the host platform.
* **Behavior depends on the host.** Different Copilot Chat versions, model choices, and VS Code extensions can produce very different results from the same file. HVE Core does not pin the model and cannot guarantee the same behavior across hosts.
* **No built-in safety filtering.** HVE Core relies entirely on the host platform's safety stack (input and output classifiers, jailbreak detection, content filters, abuse monitoring). It adds none of its own.
* **Saved memory is controlled by the host.** Some agents write to the host's memory layer (user, session, or repository scope). HVE Core writes the notes; the host owns retention, scope isolation, redaction, and access. Follow the host's guidance to inspect and clear memory.
* **Synthetic personas can be misread.** Even with low-fidelity enforcement, someone who removes the disclosure footer or the slide watermark could mistake a Customer Card Render persona for a real research participant. See Appendix 5.
* **Copied files lose their trail.** When HVE Core files are copied into a customer repository, the original history, lint coverage, and publisher verification do not come along. Record the source version and apply your own governance.
* **Coverage is uneven.** Coding-standards instructions favor C#, Python, PowerShell, Rust, Bash, Bicep, and Terraform; other stacks have less. Agent and prompt output is mainly in English.
* **Multi-agent runs are not fully auditable.** Subagent steps appear in session traces but are not yet exported in a structured, replay-friendly format for compliance review.
* **Read public claims narrowly.** The repository's docs describe what the files ship and what you can do with them. They do not describe how the host's model behaves at runtime. Any claim of safety, fitness, or production-readiness applies to the files, not to the model.

Some prior gaps that are now being addressed:

* **AI-disclosure.** A central disclaimer source (`.github/config/disclaimers.yml`) and a CI validation script now define and check the required disclaimer text for planner artifacts. Applying consistent AI-attribution markers across every artifact type is still being standardized.
* **Accessibility.** Accessibility planning instructions are now part of the repository, giving teams a structured way to run accessibility assessments. A baseline accessibility audit of HVE Core's own documentation and rendered output is still pending.
* **Telemetry.** A telemetry-foundations skill with a built-in PII denylist is now available to standardize how adopters instrument their own use. A published re-assessment cadence is still pending.
* **Prompt injection.** The ADR Creator agent treats untrusted input (web content, templates, handoff payloads) as data rather than instructions and scans content before producing output. Extending this pattern across all agents is still in progress.

## System performance

For a set of files, "performance" is not a model-accuracy score. It is how well the files behave as expected when loaded into a supported host, plus how carefully the files themselves are maintained.

Quality rests on a few things:

* **CI checks on every pull request.** Markdown linting, frontmatter validation, model-reference checks, link checking, PowerShell and Python linting, YAML validation, collection-metadata and marketplace validation, dependency-pinning and action-version checks, copyright-header checks, and skill-structure validation all run on each pull request and block merge on failure.
* **Plugin-generation gate.** Collection manifests are regenerated from source on every change; a mismatch with the generated `plugins/` outputs blocks merge.
* **Human review.** Every file change needs human review. Supply-chain and dependency checks surface to reviewers.
* **Phase-gated releases.** Artifacts move through experimental, prerelease, and stable maturity stages, giving natural points for deeper human review before broad adoption. Releases follow `release-please` conventional-commit rules with a CHANGELOG, and the VS Code extension carries version metadata you can pin against.
* **Feedback channel.** GitHub issues on `microsoft/hve-core` are the main place for bugs, requests, and concerns.

HVE Core does not measure performance against a specific model. If you need reproducible behavior, pin both the file version and the host configuration.

### Getting the best results

* **Pin to a release tag.** Treat the main branch as a moving target. For anything production-relevant, pin to a release tag and review changes before upgrading.
* **Adopt one collection at a time.** HVE Core ships several collections (see the `collections/` manifests for the current set), and most teams do not need all of them. Start with the one closest to your work and grow from there.
* **Read an agent's description before loading it.** Each agent file documents its purpose, inputs, outputs, and limits. Skipping this is the most common cause of surprises.
* **Treat decision-shaping output as a draft.** Planning agents, code-review agents that gate pull requests, and customer-handoff agents produce drafts. Do not turn a draft into a binding decision without qualified human review.
* **Check saved memory before sharing a workspace.** Agents that write to the memory layer carry context across sessions. Inspect and clear it through the host's controls before sharing a workspace, screenshot, or recording.
* **Preserve attribution on copies.** When you copy a file into a fork or customer repository, keep its copyright notice and SPDX license header, and record the source version. If an attribution line is present, keep it.
* **Report concerns through GitHub issues.** Bugs, behavior concerns, accessibility problems, and Responsible AI questions go through the public issue tracker.

## Evaluation of HVE Core

HVE Core is evaluated as a set of files, not as a model. Evaluation checks whether each artifact is well-formed, behaves as documented when loaded into a supported host, and carries appropriate Responsible AI controls.

Evaluation methods:

* **Automated validation.** Every pull request runs the full CI suite: markdown and frontmatter linting, model-reference checks, link checking, PowerShell and Python linting, YAML validation, collection-metadata and marketplace checks, dependency-pinning and action-version checks, copyright-header checks, and skill-structure validation.
* **Test suites.** Pester tests cover the PowerShell scripts and pytest covers the Python skill code. Results are written to the repository's logs directory and gate merge.
* **Prompt-engineering evaluation.** HVE Builder uses independent static review, fidelity-labeled behavior testing, and non-mutating host validation. Reports distinguish contained simulation from native behavior and retain human review as the final gate.
* **Human review.** A maintainer reviews every change. Supply-chain and dependency findings surface to that reviewer.

Evaluation results: the CI suite and human review gate merge, so a file that fails any check does not ship. This verifies file quality (structure, links, conventions, pinned dependencies). It does not verify how a downstream model behaves on the file, which depends on the host platform and sits outside HVE Core's control.

Fairness and representational considerations:

* **Language coverage is uneven.** Coding-standards instructions and most agent output favor English; behavior in other languages is less characterized.
* **Synthetic personas.** The Customer Card Render skill can encode demographic shorthand in its persona templates. Low-fidelity enforcement and disclosure controls apply, and a stereotyping review of the bundled templates is not yet complete (see Appendix 5).

## Evaluating and integrating HVE Core for your use

HVE Core is engineering tooling, not a managed service. At integration time, three things are still the responsibility of the HVE Core user:

* **Pick the right scope.** Coding-standards collections suit day-to-day engineering work. Planning collections (RAI, Security, SSSC) support governance work but still need qualified human reviewers. The experimental collection ships features that are deliberately less mature.
* **Check the host platform.** Current GitHub Copilot Chat in VS Code or the GitHub Copilot CLI are the supported hosts. Other clients are not characterized.
* **Set up your own oversight.** Agents do not commit code, file work items, or send messages on their own without operator confirmation. Keep that confirmation step, and keep code-review gates on any agent-authored change to source, configuration, infrastructure, or workflows.

Watch out for automation bias. Treat agent suggestions as starting points for human work, not replacements for it. The decision-shaping agents in particular (Appendices 1 through 4) carry no compliance authority; their drafts are inputs to human review boards, security teams, and qualified reviewers.

## Learn more about responsible AI

* [Microsoft AI Principles](https://www.microsoft.com/ai/responsible-ai): fairness; reliability and safety; privacy and security; inclusiveness; transparency; and accountability.
* [Microsoft Responsible AI Resources](https://www.microsoft.com/ai/tools-practices)
* [NIST AI Risk Management Framework 1.0](https://www.nist.gov/itl/ai-risk-management-framework)
* [Responsible use of GitHub Copilot features](https://docs.github.com/en/copilot/responsible-use)
* [GitHub Copilot Trust Center](https://copilot.github.trust.page/)

## Learn more about HVE Core

* [HVE Core repository (microsoft/hve-core)](https://github.com/microsoft/hve-core)
* [Documentation index](docs/README.md)
* [Contributing guidelines](docs/contributing/README.md)
* [Architecture overview](docs/architecture/README.md)
* [Custom agents](docs/contributing/custom-agents.md)
* [Skills overview](docs/contributing/skills.md)
* [Roadmap](docs/contributing/ROADMAP.md)

## Contact us

Give us feedback on HVE Core or on this document by opening a GitHub issue at [microsoft/hve-core](https://github.com/microsoft/hve-core/issues) using the relevant issue template. Bugs, behavior concerns, accessibility problems, and Responsible AI questions all go through the public issue tracker.

## Appendices: per-agent transparency notes

The five appendices below cover the agents whose output most influences downstream decisions, plus the Customer Card Render skill. They are not exhaustive. The full agent inventory lives in the repository's `.github/agents/` tree, and per-agent notes for the remaining agents are not yet written.

### Appendix 1: RAI Planner

* **Agent file:** `.github/agents/rai-planning/rai-planner.agent.md`
* **Purpose:** Walks an authoring team through a six-phase Responsible AI assessment workflow. Produces drafts of risk-classification screening, standards mapping, security model addendum, control surface catalog, evidence register, tradeoffs log, threat addendum, RAI review summary, and a backlog handoff.
* **Inputs:** Operator-supplied system definition, stakeholder context, and prior assessment artifacts (when present). Reads instruction files under `.github/instructions/rai-planning/`.
* **Outputs:** Markdown artifacts under `.copilot-tracking/rai-plans/{project}/` plus, on user direction, published artifacts under `docs/planning/rai/{project}-{YYYY-MM}/`. All outputs carry an "AI-assisted content; review and validate before use" footer.
* **Intended uses:** Drafting the structural scaffolding of a Responsible AI assessment for review by a qualified RAI reviewer or board. Maintaining session state and resuming an in-progress assessment.
* **Specific limitations:** The agent does not approve, certify, or sign off on Responsible AI assessments. Drafts must be reviewed by a qualified reviewer (RAI champion, Office of Responsible AI, ethics committee, legal, or compliance) before any use that would carry weight in a real decision. The agent's own framework knowledge is bounded by its embedded standards instructions; it is not a substitute for current regulatory or organizational guidance. The agent does not pull live regulatory updates.
* **Specific considerations:** Treat every output as a draft. Do not promote a draft to "approved" status. The agent surfaces tradeoffs and concern levels as suggested reads; rating a risk as Low or Moderate is the reviewer's decision, not the agent's.

### Appendix 2: Security Planner

* **Agent file:** `.github/agents/security/security-planner.agent.md`
* **Purpose:** Walks a team through a STRIDE-aligned security model exercise organized by operational bucket. Produces a threat model, control mapping against OWASP and NIST families, and a backlog handoff suitable for security and engineering teams to triage.
* **Inputs:** Operator-supplied architecture description, data-flow notes, prior security artifacts (when present), and instruction files under `.github/instructions/security/`.
* **Outputs:** Markdown artifacts under `.copilot-tracking/security-plans/{project}/`, including operational-bucket inventory, security model, standards mapping, and backlog handoff. All outputs carry the AI-assistance disclosure footer.
* **Intended uses:** Drafting an initial threat model for a system that does not yet have one, expanding an existing model with additional buckets, or preparing material for review by a security architect or threat-modeling lead.
* **Specific limitations:** The agent does not perform live vulnerability discovery, does not run penetration tests, and does not query CVE databases at runtime. Standards mapping reflects the embedded standards in the agent's instructions and should be cross-checked against current authoritative sources before publication. The agent does not produce certifications, attestations, or compliance evidence; its outputs are inputs to those processes.
* **Specific considerations:** Treat every output as a draft; do not promote a draft to approved status. Threat IDs and concern levels are suggested. A qualified security reviewer must validate the threat surface, the proposed mitigations, and the residual-risk reads before any operational decision.

### Appendix 3: SSSC Planner

* **Agent file:** `.github/agents/security/sssc-planner.agent.md`
* **Purpose:** Walks a team through a Secure Software Supply Chain assessment aligned with the OpenSSF Scorecard family, SLSA levels, the Best Practices Badge, Sigstore, and SBOM standards. Produces a 27-capability inventory, gap analysis, dual-format work-item backlog (Azure DevOps and GitHub Issues templates), and a Scorecard projection.
* **Inputs:** Operator-supplied repository scope, current toolchain state, and instruction files under `.github/instructions/security/`.
* **Outputs:** Markdown artifacts under `.copilot-tracking/sssc-plans/{project}/`. Outputs carry the AI-assistance disclosure footer.
* **Intended uses:** Establishing a baseline for supply-chain posture, identifying gaps against published standards, and producing a draft work plan to close those gaps.
* **Specific limitations:** The agent does not run Scorecard live, does not produce signed attestations, and does not generate SBOMs. Capability reads come from operator-supplied evidence; the agent cannot independently verify a claim that, for example, a workflow uses pinned action SHAs. Standards versions are pinned to the embedded mapping; recheck against current OpenSSF and SLSA documentation before publication.
* **Specific considerations:** Treat the projected Scorecard score as an estimate based on the operator-reported state. Actual scores depend on the live tooling configuration, recent commit history, and Scorecard heuristics that may evolve.

### Appendix 4: Code Review agent

* **Agent files:**
  * `.github/agents/coding-standards/code-review.agent.md`
  * `.github/agents/coding-standards/subagents/code-review-functional.agent.md`
  * `.github/agents/coding-standards/subagents/code-review-standards.agent.md`
  * `.github/agents/coding-standards/subagents/code-review-accessibility.agent.md`
  * `.github/agents/coding-standards/subagents/code-review-security.agent.md`
  * `.github/agents/coding-standards/subagents/code-review-pr.agent.md`
* **Purpose:** A single human-gated orchestrator that reads a diff or pull request scope, confirms scope with the operator, lets the operator choose which perspectives run and how deeply, and merges the results into one structured review document.
  It dispatches up to five thin perspective subagents: functional (behavior, correctness, design), standards (style, idiom, convention), accessibility (UI, markup, and document surfaces), security (auth, crypto, parsing, deserialization, secrets, networking), and pr (pull request readiness). Selecting `full` runs every perspective; the depth tier (`basic`, `standard`, or `comprehensive`) applies the same verification rigor to whichever perspectives were selected.
* **Inputs:** Diff scope (branch, commit range, or attached file set), language-specific instruction files under `.github/instructions/coding-standards/`, and repository copilot instructions.
* **Outputs:** A markdown review document under `.copilot-tracking/reviews/code-reviews/{branch-slug}/` containing per-finding categorization, severity, verdict normalization, and a summary, alongside a `metadata.json` record. Outputs carry the AI-assistance disclosure footer.
* **Intended uses:** Pre-pull-request self-review, draft review feedback for a human reviewer to vet, and perspective-specific coverage spot checks.
* **Specific limitations:** The agent does not execute code, does not run tests, does not connect to a debugger, and does not reason about runtime behavior beyond what the diff and the embedded instructions allow. It cannot verify security claims, cannot confirm test coverage figures, and cannot validate that an external dependency behaves as documented. The perspective subagents are pattern-matching reviewers, not human reviewers.
* **Specific considerations:** Treat verdicts as suggestions. The agent may produce false positives (flagging conformant code as non-conformant) and false negatives (missing real issues). A human code-reviewer remains responsible for the merge decision. Do not configure the agent as a required-status check that blocks merge without a human in the loop.

### Appendix 5: Customer Card Render skill

* **Skill file:** `.github/skills/experimental/customer-card-render/SKILL.md`
* **Purpose:** Generates customer-card PowerPoint content from Design Thinking canonical artifacts (interview notes, observations, synthesized themes). Each card represents a synthetic persona drawn from the research and is intended for stakeholder communication, not for delivery to the depicted individuals.
* **Inputs:** Canonical Design Thinking artifacts under `.copilot-tracking/dt/{project}/`, including research notes and synthesis output. Optionally, persona templates from the bundled set.
* **Outputs:** PowerPoint slide content YAML and rendered `.pptx` files. Cards include a low-fidelity visual rendering and persona narrative.
* **Intended uses:** Producing internal stakeholder-facing summaries of customer-research findings during customer engagements. Communicating synthesized insight in a format that reads as illustrative rather than as a literal portrait of any individual.
* **Specific limitations:**
  * The skill assembles cards through a template-driven PowerPoint pipeline; it does not call an image-generation model. Where the Design Thinking workflow needs concept imagery, the operator runs generated prompts on an external platform such as M365 Copilot, which applies its own Responsible AI layers. Because the cards depict people-like figures, AI-disclosure, redaction, and stereotyping controls apply.
  * Even with low-fidelity enforcement, the output may be misread as portraying real individuals.
  * The bundled persona templates may encode demographic shorthand; a stereotyping review of these templates is not yet complete.
  * Real participant data may bleed from source Design Thinking artifacts into rendered cards if the operator does not redact it before invoking the skill.
* **Specific considerations:**
  * **Hold the low-fidelity visual constraint.** Do not modify the skill to produce high-fidelity or photorealistic output. The low-fidelity style is the substantive control that keeps the output reading as illustrative rather than as a portrait of any individual; relaxing it requires an explicit accuracy review and an automated AI-disclosure marker, neither of which is in place yet.
  * **Redact source artifacts before rendering.** Real names, direct quotes attributed to identifiable individuals, photographs, and any other personally identifying detail in the Design Thinking research must be removed or generalized before the skill is invoked.
  * **Preserve disclosure on every output.** Generated cards should carry the AI-assistance disclosure footer and a slide-master watermark indicating that personas are synthetic. Do not strip these markers when copying decks into other contexts.
  * **Limit distribution to the originating engagement.** Synthetic personas should not be republished, repurposed for marketing, or used as evaluation data without explicit review.

## AI-Assistance Disclosure

The author created this content with assistance from AI. All outputs should be reviewed and validated before use by a qualified human reviewer.

## Disclaimer

This Transparency Note describes the artifacts shipped by `microsoft/hve-core` as of the document date. It does not constitute a warranty, certification, or compliance attestation, and it does not characterize the runtime behavior of any downstream model that the host platform may invoke. Adopters retain full responsibility for evaluating fitness for purpose, integrating appropriate human oversight, complying with applicable laws and regulations, and meeting the terms of service of the host platform.

Outputs from HVE Core agents and skills are advisory. They do not constitute legal, regulatory, security, or compliance advice and do not replace qualified human reviewers, ethics committees, security teams, legal counsel, or other appropriate authorities.

## About this document

| Field         | Value                         |
|---------------|-------------------------------|
| System        | HVE Core (microsoft/hve-core) |
| Document type | Transparency Note             |
| Cycle         | May 2026                      |
| Published     | 2026-06-11                    |
| Last updated  | 2026-06-11                    |

© 2026 Microsoft Corporation. All rights reserved. This document is provided "as-is" and for informational purposes only. Information and views expressed in this document, including URL and other Internet Web site references, may change without notice. You bear the risk of using it. Some examples are for illustration only and are fictitious. No real association is intended or inferred.

This document is not intended to be, and should not be construed as providing, legal advice. The jurisdiction in which you are operating may have various regulatory or legal requirements that apply to your AI system.

Consult a legal specialist if you are uncertain about laws or regulations that might apply to your system, especially if you think those might impact these recommendations. Be aware that not all of these recommendations and resources will be appropriate for every scenario, and conversely, these recommendations and resources may be insufficient for some scenarios.

Published: 2026-06-11

Last updated: 2026-06-11

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
