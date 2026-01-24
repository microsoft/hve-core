---
description: "Generate pull request description, discover related work items, identify reviewers, and create Azure DevOps pull request with all linkages."
maturity: stable
---

# Create Azure DevOps Pull Request with Work Item & Reviewer Discovery

Follow all instructions from #file:../instructions/ado-create-pull-request.instructions.md

## Inputs

* ${input:adoProject:hve-core}: Azure DevOps project identifier.
* ${input:repository}: (Optional) Repository name or ID for the pull request. Discover with ado tools if needed.
* ${input:baseBranch:origin/main}: Git comparison base and target branch for the PR.
* ${input:sourceBranch}: Source branch for the pull request (defaults to current branch).
* ${input:isDraft:false}: Whether to create the PR as a draft.
* ${input:includeMarkdown:true}: Include markdown file diffs in pr-reference.xml (passed as --no-md-diff if false to pr-ref-gen.sh).
* ${input:workItemIds}: (Optional) Comma-separated work item IDs to link (skips work item discovery if provided).
* ${input:similarityThreshold:0.2}: Minimum similarity score for work item relevance (0.0-1.0).
* ${input:areaPath}: (Optional) Area Path filter for work item searches.
* ${input:iterationPath}: (Optional) Iteration Path filter for work item searches.
* ${input:workItemStates:New,Active,Resolved}: (Optional) Comma-separated states to include in work item searches.
* ${input:noGates:false}: Skip all confirmation gates and create PR immediately with discovered work items and minimum 2 optional reviewers.

## Instructions

Proceed through the PR creation workflow following all Azure DevOps Pull Request Creation & Workflow instructions.
