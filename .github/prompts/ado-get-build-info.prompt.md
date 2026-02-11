---
description: "Retrieve Azure DevOps build information for a Pull Request or specific Build Number."
maturity: stable
---

# ADO Build Info & Log Extraction (Targeted or Latest PR Build)

**MANDATORY**: Follow all instructions from #file:../instructions/ado-get-build-info.instructions.md

## Inputs

* ${input:project}: Azure DevOps project name should be identified if not provided.
* ${input:pr}: Pull request (number, ID, or generic terms "my pr", "current pr", etc) and can represent the [PR number].
* ${input:build}: Build (number, ID, or generic terms "most recent", "current", "failed, etc) and can represent the [build ID].
* ${input:info:status}: The type of information to retrieve along with considering the user's prompt.

---

If the user provided additional detail then be sure to include them when retrieving build information.

Proceed with build information retrieval by following the Required Protocol.
