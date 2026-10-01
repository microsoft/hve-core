---
description: "Create an Azure DevOps pull request with generated description, linked work items, and reviewers"
agent: agent
---

# Create Azure DevOps Pull Request with Work Item & Reviewer Discovery

Activate the `backlog-management` skill by name and follow its Azure DevOps pull request reference (`references/ado-pull-request.md`). That reference is packaged with the skill, not with this prompt, so resolve it by name rather than by path.

When the skill does not resolve, warn the user that platform resolution, the autonomy tiers, the content sanitization guards, and the human review triggers are unavailable, and stop before any Azure DevOps call. Do not reconstruct the protocol here.

## Inputs

* ${input:adoProject:hve-core}: Azure DevOps project identifier.
* ${input:repository}: (Optional) Repository name or ID for the pull request. Discover with ado tools if needed.
* ${input:baseBranch:origin/main}: Git comparison base and target branch for the PR.
* ${input:sourceBranch}: Source branch for the pull request (defaults to current branch).
* ${input:isDraft:false}: Whether to create the PR as a draft.
* ${input:includeMarkdown:true}: Include markdown file diffs in pr-reference.xml (passed as --no-md-diff if false to the pr-reference skill).
* ${input:workItemIds}: (Optional) Comma-separated work item IDs to link (skips work item discovery if provided).
* ${input:similarityThreshold:0.2}: Minimum similarity score for work item relevance (0.0-1.0).
* ${input:areaPath}: (Optional) Area Path filter for work item searches.
* ${input:iterationPath}: (Optional) Iteration Path filter for work item searches.
* ${input:workItemStates:New,Active,Resolved}: (Optional) Comma-separated states to include in work item searches.
* ${input:noGates:false}: Skip all confirmation gates and create PR immediately with discovered work items and minimum 2 optional reviewers.

## Instructions

Run the reference's Mandatory Preflight first: activate `backlog-management`, resolve Azure DevOps, confirm the `project` and `repository` destination, establish the autonomy tier, and apply the content sanitization guards to every platform-visible field. `${input:noGates}` skips only the staged Phase 5 presentation after that confirmation; it never bypasses destination confirmation, sanitization, human review triggers, or the Partial and Manual mutation gates.

Then proceed through the seven-phase creation protocol in the reference.
