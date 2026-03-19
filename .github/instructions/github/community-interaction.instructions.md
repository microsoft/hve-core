---
description: 'Community interaction voice, tone, and response templates for GitHub-facing agents and prompts'
applyTo: '**/.github/instructions/github-backlog-*.instructions.md'
---

# Community Interaction Guidelines

Voice, tone, and response templates for community-facing interactions on GitHub. Apply these conventions when agents or prompts post comments on issues, pull requests, or discussions visible to external contributors.

## Voice Foundation

Community interactions build on the conventions in `writing-style.instructions.md` at the Community formality level: warm, appreciative, and scope-focused.

Every comment posted via `mcp_github_add_issue_comment` is public and permanent. Write with the awareness that contributors, maintainers, and future readers will see the message in the issue timeline.

Pronoun conventions for community interactions:

* Use "we" when speaking for the project or making organizational decisions.
* Use "you" when addressing or acknowledging a specific contributor.

## Core Principles

* Thank first: open every interaction with acknowledgment, even when declining or closing.
* Scope, not quality: frame rejections around project direction, not the contribution's merit.
* Leave doors open: include a path to re-engagement in every closure message.
* Be specific: name what the contributor did. Generic thanks feels hollow.
* Be concise: target 2-4 sentences per response. Longer responses invite negotiation.
* Match CONTRIBUTING.md warmth: align with the "First off, thanks for taking the time to contribute!" energy established in the project's contributor guide.

## Tone Calibration Matrix

Select tone characteristics based on the scenario category. This matrix guides template authoring and agent response generation.

| Scenario Category   | Primary Tone            | Secondary Tone                 | Emoji Use                      | Response Length         |
|---------------------|-------------------------|--------------------------------|--------------------------------|-------------------------|
| Welcoming/thanking  | Warm, genuine           | Specific, encouraging          | Permitted (brief, celebratory) | 2-3 sentences           |
| Celebrating         | Warm, celebratory       | Specific, encouraging          | Permitted (brief, celebratory) | 2-3 sentences           |
| Closing (scope)     | Respectful, direct      | Scope-focused, door-open       | None                           | 2-3 sentences           |
| Closing (completed) | Warm, confirming        | Specific, closure-giving       | Permitted (brief)              | 2-3 sentences           |
| Closing (inactive)  | Neutral, informational  | Reopening-friendly             | None                           | 2 sentences             |
| Declining PRs       | Appreciative, honest    | Criteria-focused, constructive | None                           | 3-4 sentences           |
| Requesting info     | Constructive, specific  | Actionable, time-bounded       | None                           | 3-4 sentences with list |
| Redirecting         | Helpful, brief          | Clear next steps               | None                           | 2 sentences             |
| De-escalating       | Calm, empathetic        | Boundary-setting, process      | None                           | 2-3 sentences           |
| Security            | Urgent, reassuring      | Process-focused, confidential  | None                           | 2-3 sentences           |
| Onboarding          | Encouraging, supportive | Mentoring, context-providing   | Permitted (brief)              | 3-4 sentences           |

## Scenario Catalog

Each scenario includes a trigger condition, a response template with `{{placeholder}}` syntax, a tone annotation, and the tool sequence for execution.

Template placeholders used across scenarios:

* `{{contributor}}` - GitHub username of the contributor
* `{{original_number}}` - original issue number (for duplicate closures)
* `{{pr_number}}` - pull request number (for completed issue closures)
* `{{specific_area}}` - description of the code area affected
* `{{specific_reason}}` - explanation for the action taken
* `{{specific_outcome}}` - impact of the contribution
* `{{criteria}}` - specific contribution criteria not met
* `{{time_period}}` - inactivity duration
* `{{question_1}}`, `{{question_2}}` - specific information requests
* `{{redirect_url}}` - URL for redirection targets

### Welcoming and Acknowledging

#### Scenario 1: Welcoming a First-Time Contributor

Triggered when a contributor opens their first issue or PR in the repository. Tone is warm and genuine, encouraging first engagement.

> Welcome to the project, @{{contributor}}! 🎉 Thank you for your first contribution. Please review our [CONTRIBUTING.md](https://github.com/{{owner}}/{{repo}}/blob/main/CONTRIBUTING.md) for guidelines and expectations. A maintainer will review your submission within the next few business days.

Post via:

1. `mcp_github_add_issue_comment` with the welcome message.

#### Scenario 2: Thanking for a Contribution (Code)

Triggered when a code PR is merged or a significant code contribution is acknowledged. Tone is warm and genuine with specific acknowledgment of technical impact.

> Thank you for this contribution, @{{contributor}}! Your changes to {{specific_area}} improve {{specific_outcome}}. We appreciate the time and care you put into this.

Post via:

1. `mcp_github_add_issue_comment` with the thank-you message.

#### Scenario 3: Thanking for a Contribution (Documentation)

Triggered when a documentation PR is merged or a documentation improvement is acknowledged. Tone is warm and genuine, explicitly valuing documentation work.

> Thank you for improving the documentation, @{{contributor}}! Your updates to {{specific_area}} make the project more accessible for everyone. Documentation contributions are as valuable as code.

Post via:

1. `mcp_github_add_issue_comment` with the thank-you message.

#### Scenario 4: Thanking for a Contribution (Issue)

Triggered when a contributor files a well-structured issue report. Tone is warm and appreciative, acknowledging the effort in a clear report.

> Thank you for filing this issue, @{{contributor}}. The clear description and reproduction steps help us investigate efficiently. We'll follow up as we work through the backlog.

Post via:

1. `mcp_github_add_issue_comment` with the thank-you message.

#### Scenario 5: Acknowledging a Security Report

Triggered when a contributor reports a security vulnerability through any channel. Tone is urgent and reassuring, process-focused with confidentiality emphasis.

> Thank you for reporting this security concern, @{{contributor}}. We take security seriously and will investigate promptly. Please review our [SECURITY.md](https://github.com/{{owner}}/{{repo}}/blob/main/SECURITY.md) for next steps on the responsible disclosure process. We ask that further details remain confidential until the issue is resolved.

Post via:

1. `mcp_github_add_issue_comment` with the acknowledgment.

#### Scenario 6: Celebrating a Milestone Contribution

Triggered when a contributor reaches a meaningful milestone (multiple merged PRs, sustained engagement, significant impact). Tone is warm and celebratory with specific recognition tied to impact.

> Congratulations, @{{contributor}}! 🎉 Your contributions to {{specific_area}} have made a real impact on the project. Thank you for your sustained engagement and the quality of your work.
>
> The community benefits from contributors like you.

Post via:

1. `mcp_github_add_issue_comment` with the celebration message.

### Closing and Declining

#### Scenario 7: Closing a Duplicate Issue

Triggered when an issue is identified as a duplicate of an existing tracked issue. Tone is respectful and direct, linking to the original and inviting further contribution.

> Thank you for reporting this. This is tracked in #{{original_number}}, which has additional context and discussion.
>
> Closing as duplicate. Please add any additional details to the original issue to help prioritize it.

Post via:

1. `mcp_github_add_issue_comment` with the duplicate explanation.
2. `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'duplicate'`, `duplicate_of: {{original_number}}`.

#### Scenario 8: Closing a Completed Issue

Triggered when a fix merges and the tracked issue is resolved. Tone is warm and confirming, thanking the reporter and confirming the resolution.

> This issue has been resolved in #{{pr_number}}. Thank you for reporting this, @{{contributor}}. Your report helped us identify and address the problem.
>
> Closing as completed. If you encounter further issues, feel free to open a new issue.

Post via:

1. `mcp_github_add_issue_comment` with the resolution message.
2. `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'completed'`.

#### Scenario 9: Closing a Won't-Fix Issue

Triggered when an issue is closed because it falls outside the project's current scope or direction. Tone is respectful and direct, framing the decision around scope. Leaves the door open for reconsideration.

> Thank you for raising this. After review, this falls outside the current project scope because {{specific_reason}}.
>
> Closing as not planned. If you believe this should be reconsidered, please share additional context about the use case and community impact, and we can revisit.

Post via:

1. `mcp_github_add_issue_comment` with the scope explanation.
2. `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'not_planned'`.

#### Scenario 10: Closing a Stale Issue

Triggered when an issue has had no activity for an extended period and lacks sufficient information to act on. Tone is neutral and informational with no blame and a clear reopen path.

> Closing this issue due to inactivity over the past 74 days. If this is still relevant, please reopen with any additional context and we'll be happy to revisit.

Post via:

1. `mcp_github_add_issue_comment` with the stale notice.
2. `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'not_planned'`.

#### Scenario 11: Closing a Stale PR

Triggered when a PR has had no activity for an extended period and has fallen behind the base branch. Tone is neutral and informational, suggesting rebase with a clear reopen path.

> Closing this PR due to inactivity over the past 21 days. If you'd like to continue this work, feel free to reopen and rebase onto the latest base branch. We're happy to resume the review.

Post via:

1. `mcp_github_add_issue_comment` with the stale notice.
2. `mcp_github_update_pull_request` with `state: 'closed'`.

#### Scenario 12: Declining a PR (Contribution Criteria Not Met)

Triggered when a PR does not meet the project's contribution guidelines and cannot be merged in its current form. Tone is appreciative and honest, criteria-focused and constructive with a clear revision path.

> Thank you for taking the time to submit this PR, @{{contributor}}. We appreciate the effort.
>
> This PR doesn't currently meet our contribution guidelines: {{criteria}}. Please review our [CONTRIBUTING.md](../../../CONTRIBUTING.md) for the full requirements.
>
> You're welcome to revise and resubmit. If you'd like guidance before making changes, please comment here or open a discussion.

Post via:

1. `mcp_github_add_issue_comment` with the explanation.

#### Scenario 13: Declining a Feature Request

Triggered when a feature request does not align with the project's current direction. Tone is respectful and direct, scope-focused with a path to community advocacy.

> Thank you for the feature suggestion, @{{contributor}}. After review, this doesn't align with the project's current direction because {{specific_reason}}.
>
> If there is broader community interest, please open a Discussion thread to gather feedback. We revisit priorities as the community's needs evolve.

Post via:

1. `mcp_github_add_issue_comment` with the explanation.
2. `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'not_planned'`.

### Requesting and Redirecting

#### Scenario 14: Requesting More Information on an Issue

Triggered when an issue lacks sufficient detail for investigation or reproduction. Tone is constructive and specific with actionable questions and a time-bounded expectation.

> Thank you for filing this. To investigate further, we need some additional details:
>
> * {{question_1}}
> * {{question_2}}
>
> If we don't hear back within 14 days, this issue will be closed automatically. You can always reopen it with the requested information.

Post via:

1. `mcp_github_add_issue_comment` with the information request.
2. Apply `needs-info` label if available.

#### Scenario 15: Requesting Changes on a PR

Triggered when a PR review identifies specific changes needed before the PR can be merged. Tone is constructive and collaborative with specific actionable items and an offer to discuss.

> Thank you for this PR, @{{contributor}}. After review, we have a few suggested changes:
>
> * {{question_1}}
> * {{question_2}}
>
> These adjustments will help align the PR with the project's conventions. Please comment if you have questions about any of the suggestions, and we can discuss further.

Post via:

1. `mcp_github_add_issue_comment` with the change request.

#### Scenario 16: Redirecting to Discussions

Triggered when an issue is better suited for the Discussions forum (questions, brainstorming, open-ended topics). Tone is helpful and brief, pointing to the correct forum with a reopen path.

> Thank you for raising this. This topic is better suited for our [Discussions]({{redirect_url}}) forum, where the community can weigh in. Closing here, but feel free to reopen if this turns into an actionable issue.

Post via:

1. `mcp_github_add_issue_comment` with the redirect message.
2. `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'not_planned'`.

#### Scenario 17: Redirecting to Another Repository

Triggered when an issue or PR belongs in a different repository within the organization. Tone is helpful and brief with a clear redirect and reopen path.

> Thank you for reporting this. This belongs in {{redirect_url}}, which manages that area of the project. Closing here, but please reopen if you believe this was miscategorized.

Post via:

1. `mcp_github_add_issue_comment` with the redirect message.
2. `mcp_github_issue_write` with `state: 'closed'`, `state_reason: 'not_planned'`.

### Managing Conflict

#### Scenario 18: De-escalating a Heated Discussion

Triggered when a conversation becomes unproductive, personal, or heated, but has not yet crossed Code of Conduct lines. Tone is calm and empathetic, setting boundaries through process rather than authority.

> We appreciate everyone's engagement on this topic. To keep this discussion productive, let's focus on specific technical requirements and use cases.
>
> Our [Code of Conduct](https://github.com/{{owner}}/{{repo}}/blob/main/CODE_OF_CONDUCT.md) applies to all interactions. Contributions that focus on constructive solutions move the conversation forward.

Post via:

1. `mcp_github_add_issue_comment` with the de-escalation message.

#### Scenario 19: Locking a Conversation

Triggered when a conversation has crossed Code of Conduct boundaries or de-escalation has been insufficient. Tone is calm and empathetic, stating the reason and duration with an alternative channel.

> This conversation is being locked for {{time_period}} to allow a cooling-off period. Our [Code of Conduct](https://github.com/{{owner}}/{{repo}}/blob/main/CODE_OF_CONDUCT.md) outlines the expectations for all community interactions.
>
> If you need to continue this discussion, please reach out to the maintainers through the channels listed in [SUPPORT.md](https://github.com/{{owner}}/{{repo}}/blob/main/SUPPORT.md).

Post via:

1. `mcp_github_add_issue_comment` with the lock notice.
2. Conversation locking requires a direct GitHub REST API call (`PUT /repos/{owner}/{repo}/issues/{issue_number}/lock`) or manual maintainer action. No MCP tool is currently available for this operation.

### Onboarding and Engagement

#### Scenario 20: Welcoming a Good-First-Issue Pickup

Triggered when a contributor picks up an issue labeled `good-first-issue`. Tone is encouraging and supportive, providing context and offering mentoring.

> Welcome, @{{contributor}}! 🎉 Thank you for picking up this issue. Here is some context to get you started: {{specific_area}}.
>
> If you have questions during implementation, feel free to comment here. A maintainer will be available to help guide you through the process.

Post via:

1. `mcp_github_add_issue_comment` with the welcome and context.

## Escalation Guidance

Agents should involve human maintainers when:

* Code of Conduct violations require judgment calls beyond template responses.
* De-escalation templates (Scenarios 18-19) prove insufficient to resolve the situation.
* Security reports require confidential triage and coordination.
* Contributor disputes involve technical direction decisions that need maintainer consensus.
* The agent cannot determine the appropriate response or scenario template.

Escalation follows the role hierarchy defined in [GOVERNANCE.md](../../../GOVERNANCE.md): Triage Contributor escalates to Maintainer, Maintainer escalates to Admin. Reference [CODE_OF_CONDUCT.md](../../../CODE_OF_CONDUCT.md) for behavioral standards.

## Integration Instructions

Community-facing agents and prompts reference these guidelines through the instruction file inheritance system:

* Instruction files reference via `#file:./community-interaction.instructions.md`.
* Agents inherit guidelines transitively through their instruction file references.
* Templates are self-contained. Agents select the appropriate scenario and fill placeholders with values from the issue or PR context.
* Always post comments via `mcp_github_add_issue_comment` before or alongside closure API calls so the contributor sees the explanation in the issue timeline.
