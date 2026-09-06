---
title: Team Adoption and Governance
description: Establish governance practices, naming conventions, onboarding patterns, and change management for team-wide HVE Core adoption
author: Microsoft
ms.date: 2026-08-19
ms.topic: how-to
keywords:
  - governance
  - adoption
  - onboarding
  - naming conventions
  - change management
estimated_reading_time: 7
---

## Recommended Starting Point

Start team adoption with the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) for the complete managed component set across all team members.
When the team is ready for clone-based methods, ask an agent to use the included `hve-core-installer` skill. It evaluates the environment, recommends peer clone, submodule, git-ignored, or another method, guides MCP configuration, and supports a complete or custom selection across agents, prompts, instructions, and distributable skill directories.
Move to direct clone setup only when artifact modification is required beyond what the installer provides.

## Adoption Strategy

Adopt HVE Core incrementally. A phased approach lets your team build confidence
with simpler artifacts before advancing to complex ones.

### Phase 1: Instructions

Start with instructions files. They require the least effort and deliver
immediate value by shaping Copilot's behavior for every conversation. Write
two or three instructions covering your team's coding standards, commit message
format, or PR conventions.

### Phase 2: Agents and Prompts

Once the team is comfortable with instructions, introduce custom agents for
repeatable workflows (code reviews, research tasks, implementation patterns)
and prompts for one-shot operations (generating boilerplate, formatting
outputs).

### Phase 3: Skills and Shared Distribution

Package domain knowledge into skills for complex, multi-step workflows. Place related artifacts under package-scoped `.github` paths and synchronize root `plugin.json` for managed distribution, or use selective cloning for a repository-owned subset.

### Measuring Adoption Progress

Track adoption through observable indicators:

* Number of team members using custom agents in daily work
* Frequency of instructions and prompt invocations
* Reduction in repetitive manual tasks
* Quality improvements in generated code and documentation

## Naming Conventions

Consistent naming makes artifacts discoverable and their purpose clear at a
glance. Follow kebab-case patterns throughout.

### File Naming Patterns

| Artifact Type  | Pattern                                        | Example                         |
|----------------|------------------------------------------------|---------------------------------|
| Instructions   | `{topic}.instructions.md`                      | `python-script.instructions.md` |
| Agents         | `{workflow}.agent.md`                          | `code-review.agent.md`          |
| Prompts        | `{action}.prompt.md`                           | `generate-tests.prompt.md`      |
| Skills         | `{skill-name}/SKILL.md`                        | `pr-reference/SKILL.md`         |
| Manifest paths | Plugin manifest and `docs/plugins/hve-core.md` | `agents/ado/example.agent.md`   |

### Namespace IDs

Namespace IDs serve as conventional directory names throughout `.github/` and must be unique, lowercase, and kebab-cased. They organize source and do not create independently installable marketplace products. Choose IDs that reflect the domain or team the namespace serves:

* `ado` for Azure DevOps integration
* `coding-standards` for language-specific conventions
* `security` for security architecture workflows

### Directory Organization

Place artifacts under their namespace ID in the appropriate `.github/`
subdirectory:

```text
.github/
  agents/{package-id}/
  instructions/{package-id}/
  prompts/{package-id}/
  skills/{package-id}/
```

Artifacts at the root of `.github/agents/`, `.github/instructions/`,
`.github/prompts/`, or `.github/skills/` (without a subdirectory) are treated
as repo-specific and excluded from plugin membership and extension packaging.

## Governance Model

### Ownership

Assign clear ownership for each artifact category:

* A designated maintainer or team owns each component namespace within the `hve-core` plugin
* Individual instructions files can have separate owners when they span
  multiple domains
* The `copilot-instructions.md` file at the repository root reflects
  cross-cutting concerns and requires broader review

### Review and Approval

Treat Copilot customization files with the same rigor as production code:

* Require pull request review for changes to instructions, agents, and skills
* Use CODEOWNERS to route reviews to artifact owners
* Validate changes with `npm run validate:local` before merging
* Run `npm run plugin:sync` and `npm run plugin:validate` after changing distributable membership

### Handling Conflicting Instructions

When multiple instructions files provide contradictory guidance, resolution
follows priority order:

1. `copilot-instructions.md` highest-priority rules override everything
2. More specific `applyTo` patterns take precedence over broader ones
3. When two instructions at the same specificity conflict, the artifact owner
   resolves the conflict through a pull request

## Onboarding New Team Members

### Step-by-Step Onboarding

1. Point new members to the [Getting Started](../getting-started/README.md)
   guide for installation.
2. Walk through a first interaction using an existing agent (the RPI workflow
   is a good starting point).
3. Show how instructions files shape Copilot behavior by editing one together.
4. Introduce the team's custom agents and explain when to use each.
5. Share the team's naming conventions and governance expectations.

### First Customization Walkthrough

Have new team members create their first instructions file as an onboarding
exercise. A simple coding-style instruction works well:

1. Create a file at `.github/instructions/{package-id}/my-style.instructions.md`
   with minimal frontmatter (`description` and `applyTo` fields)
2. Run `hve-builder` in create mode and supply an existing team instruction as
  a known reference
3. Review HVE Builder's static verdict, behavior-test disposition, and host
  validation result
4. Continue the approved improve run if actionable findings require source
  changes
5. Test by opening a Copilot chat and verifying the instructions influence
   responses
6. Submit the file for review following the team's PR process

> [!TIP]
> Pair the new member with someone experienced during their first
> customization. Seeing how HVE Builder authors and validates an artifact
> builds intuition for the full authoring workflow.

## Change Management

### Introducing New Artifacts

Follow a structured process when adding new instructions, agents, or skills:

1. Create the artifact file with minimal frontmatter in a feature branch
2. Run `hve-builder` in create or improve mode with the relevant known references
3. Resolve its static, behavior, and validation gates until the overall outcome passes
4. Run `npm run validate:local` to validate local-safe checks, then reproduce any relevant CI-owned lane separately
5. Run `npm run plugin:sync` and update `docs/plugins/hve-core.md` when the user-visible surface changes
6. Run `npm run plugin:validate` and `npm run docs:generate:check`
7. Submit a pull request with clear description of what the artifact does and
   why

### Communication Patterns

Announce changes that affect team workflows:

* New agents: share the agent name, purpose, and invocation example
* Modified instructions: explain what changed and why
* Deprecated artifacts: provide migration steps and a timeline

### Deprecation Workflow

To deprecate an artifact:

1. Use `hve-builder` improve mode to add a deprecation notice pointing to the replacement.
2. Announce the deprecation and provide a migration timeline.
3. Move the artifact under `.github/deprecated/` when it should leave managed distribution.
4. Run `npm run plugin:sync` and `npm run plugin:validate`; the manifest change removes it from Stable and PreRelease together.
5. Remove the archived artifact after the agreed transition period.

## Role-Based Adoption Paths

Each role enters customization at a different level. These paths provide
starting points and progression for each of the nine roles.

### Engineer

1. Create an instructions file for your team's coding standards
2. Build a custom agent for your most common code review patterns
3. Package domain knowledge into a skill with scripts and references

### TPM (Technical Program Manager)

1. Use the RPI workflow to research and document project status
2. Create prompts for generating status reports and risk summaries
3. Build an agent that tracks cross-team dependencies

### Tech Lead

1. Write instructions for architecture decision conventions
2. Create a code review agent that enforces team standards
3. Establish a reviewed custom selection that captures your team's workflow

### Security Architect

1. Add security-focused instructions for security model analysis
2. Create a security review agent that checks for common
  vulnerabilities
3. Build a skill that integrates with security scanning tools

### Data Scientist

1. Create instructions for notebook conventions and data handling
2. Build prompts for exploratory data analysis patterns
3. Package statistical methodology into a skill with reference
  datasets

### SRE/Operations

1. Write instructions for runbook format and incident response
2. Create an agent for infrastructure review workflows
3. Build a skill integrating monitoring, alerting, and deployment tools

### Business PM (Product Manager)

1. Use prompts to generate user story drafts from requirements
2. Create an agent for requirements analysis
3. Build a Design Thinking workflow with custom agents

### New Contributor

1. Follow the [Getting Started](../getting-started/README.md)
  guide and complete your first interaction
2. Create your first instructions file with the onboarding
  walkthrough above
3. Propose a new agent or skill for a workflow gap you've
  identified

### Utility

1. Use existing prompts and agents without modification
2. Customize instructions for your specific workflow context
3. Contribute improvements to shared components based on
  usage patterns

## Measuring Success

### Quantitative Indicators

* Artifact count: track the number of instructions, agents, and skills over time
* Invocation frequency: monitor how often team members activate custom agents
  and prompts
* Error reduction: measure before-and-after rates for common mistakes the
  customizations target
* Onboarding velocity: compare time-to-productivity for members who use HVE
  Core versus those who do not

### Qualitative Indicators

* Team confidence: survey whether members feel more effective with AI-assisted
  workflows
* Consistency: review whether generated outputs (code, docs, PRs) follow team
  conventions more reliably
* Feedback quality: assess whether Copilot suggestions require fewer manual
  corrections

### Feedback Collection

Establish regular feedback cycles:

* Include Copilot customization effectiveness in sprint retrospectives
* Maintain a shared channel or document for reporting customization gaps
* Review and adjust artifacts quarterly based on accumulated feedback
* Track which artifacts are rarely used and consider deprecation

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
