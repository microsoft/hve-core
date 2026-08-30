---
description: "Retrieve Azure DevOps build status and logs for a pull request or build number"
agent: agent
---

# ADO Build Info & Log Extraction (Targeted or Latest PR Build)

**MANDATORY**: Activate the `backlog-management` skill by name and follow its Azure DevOps build-info reference (`references/ado-build-info.md`). That reference is packaged with the skill, not with this prompt, so resolve it by name rather than by path.

When the skill does not resolve, warn the user that the build-info protocol is unavailable and stop before any Azure DevOps call. Do not reconstruct it here.

## Inputs

* ${input:project}: Azure DevOps project name should be identified if not provided.
* ${input:pr}: Pull request (number, ID, or generic terms "my pr", "current pr", etc) and can represent the [PR number].
* ${input:build}: Build (number, ID, or generic terms "most recent", "current", "failed, etc) and can represent the [build ID].
* ${input:info:status}: The type of information to retrieve along with considering the user's prompt.

---

If the user provided additional detail then be sure to include them when retrieving build information.

Proceed with build information retrieval by following the Required Protocol.
