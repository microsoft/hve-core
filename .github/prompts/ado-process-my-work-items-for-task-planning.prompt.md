---
description: "Process retrieved work items for task planning and generate task-planning-logs.md handoff file"
maturity: stable
---

# Process My Work Items for Task Planning

Follow all instructions from #file:../instructions/ado-wit-planning.instructions.md for work item planning and planning file definitions.

You WILL process work items from the planning file structure created by `ado-get-my-work-items.prompt.md` and generate a comprehensive task planning handoff file. This creates enriched work item documentation ready for task research and detailed implementation planning.

## General User Conversation Guidance

Keep the user up-to-date while processing work items.

Follow these guidelines whenever interacting with the user through conversation:

* Utilize markdown styling whenever interacting with the user.
* Provide double newlines for each paragraph or new section.
* Use bolding for title words and italics for emphasis.
* For all unordered lists use markdown `*` instead of only using newlines.
* Use emojis to help get your point across.
* Avoid giving the user an overwhelming amount of information.

## Inputs

* ${input:planningDir:`.copilot-tracking/workitems/current-work/my-assigned-work-items/`}: (Required) Path to planning directory containing work-items.md
* ${input:project}: (Required) Azure DevOps project name or ID
* ${input:maxItems:all}: Maximum number of work items to process. Default: all.
* ${input:boostTags}: (Optional) Comma/semicolon separated tags that elevate work items to top recommendation
* ${input:forceTopId}: (Optional) Specific work item ID to force as top recommendation

## 1. Required Protocol

Processing protocol:

* Read planning files from specified directory (`work-items.md`, `artifact-analysis.md`, `planning-log.md`)
* Enrich work items with repository context using semantic search and file analysis
* Generate comprehensive `task-planning-logs.md` handoff file for task research and planning
* Create structured handoff sections ready for `task-researcher.agent.md` and `task-planner.agent.md`
* Update planning-log.md with processing progress and discoveries
* Provide conversational summary of processed work items and handoff file location

## 2. Work Item Enrichment Phase

**Repository Context Enhancement:**

1. Read work items from `work-items.md` planning file
2. For each work item, use semantic search to find related repository files
3. Analyze file contents to understand implementation context
4. Identify key functions, classes, and integration points
5. Document configuration touchpoints and data dependencies
6. Map work item relationships and dependencies

**Azure DevOps Comment Integration:**

Use `mcp_ado_wit_list_work_item_comments` to fetch recent comments for additional context.

Keep only materially useful information: problems, decisions, deployments, errors/stack traces (use fenced `text` block for multi-line), metrics, blockers. Skip social/duplicate or bot noise unless it adds unique technical data. Preserve exact error strings & file/config names.

Format each unit as a bullet starting with `Author - YYYY-MM-DD:`. Split multiple units from one comment into separate bullets. Order by timestamp ascending. Omit section if no retained units.

**Error Handling:**

* Missing planning files: Surface error and guide user to run ado-get-my-work-items first
* Repository context failures: Continue processing with available information
* Azure DevOps API failures: Log errors and continue with planning file data

## 3. Task Planning Log Generation

### 3.1 Create task-planning-logs.md Structure

Generate comprehensive handoff file: `${input:planningDir}/task-planning-logs.md`

### 3.2 Top Work Item Recommendation

Select top priority work item based on:

1. `${input:forceTopId}` if specified and valid
2. Work items with `${input:boostTags}` (highest tag density)
3. First work item by priority/stack rank order

Provide detailed analysis including:

* Repository context with top 10 most relevant files
* Implementation detail leads and integration points
* Ready-to-research prompt seed for task planning
* Comprehensive metadata and current state analysis

### 3.3 Additional Work Item Handoffs

For remaining work items (up to `${input:maxItems}`):

* Condensed handoff sections with key repository context
* Top 5 most relevant files per work item
* Implementation leads and blockers analysis
* Ready-to-research seeds for each item

## 4. Handoff Content Requirements

Each work item section in task-planning-logs.md MUST include:

**Metadata:**

* Work Item ID, Type, Title, State, Priority, Stack Rank
* Parent relationships, Tags, Assigned To, Last Changed Date

**Context Analysis:**

* 2-5 sentence narrative summary of intent and desired outcome
* Description and Acceptance Criteria (from planning files)
* Blockers, risks, and current state assessment

**Repository Integration:**

* Top Files (≤10 for primary recommendation, ≤5 for others) with implementation rationale
* Related file patterns and broader codebase areas
* Key functions, classes, and integration touchpoints
* Configuration files, environment variables, and data dependencies
* Related work item connections with relationship rationale

**Task Planning Seeds:**

* Objective: Clear goal statement
* Unknowns: Key questions requiring research
* Candidate Files: Primary files for investigation
* Risks: Technical and implementation risks
* Next Steps: Immediate actions for task research/planning

## 5. Output Requirements

**Generated Files:**

1. `${input:planningDir}/task-planning-logs.md` - Comprehensive task planning handoff
2. Updated `${input:planningDir}/planning-log.md` - Processing progress and discoveries

**task-planning-logs.md Structure:**

```markdown
# Work Items - Task Planning Handoff (YYYY-MM-DD)

## Top Recommendation - WI {id} ({WorkItemType})
[Detailed analysis with all sections]

## Additional Work Item Handoffs
### WI {id} - {Title}
[Condensed analysis sections]

## Progress Summary
Processed: X / Total: Y work items
Top Recommendation: WI {id}
Additional Items: [WI IDs]

## Task Researcher Handoff Payload
* Planning Directory: {planningDir}
* Top Recommendation ID: {id}
* All Processed IDs: [comma-separated list]
* Processing Date: YYYY-MM-DD
* Ready for: task-researcher.agent.md, task-planner.agent.md
```

**Conversation Summary:**

* Count of work items processed and enriched
* Top recommendation selection rationale
* Task planning handoff file location
* Summary of repository context discoveries
* Guidance for next steps with task research/planning tools

## 6. Processing Protocol

Processing protocol steps:

1. **Load Planning Files**: Read work-items.md, artifact-analysis.md, and planning-log.md from specified directory
2. **Validate Structure**: Ensure planning files contain valid work item definitions
3. **Select Top Recommendation**: Apply forceTopId, boostTags, or priority-based selection
4. **Repository Context Research**: Use semantic search and file analysis for each work item
5. **Comment Integration**: Fetch Azure DevOps comments for additional context
6. **Generate task-planning-logs.md**: Create comprehensive handoff file with all sections
7. **Update planning-log.md**: Document processing progress and discoveries
8. **Provide Summary**: Conversational update with handoff file location and next steps

**Resumable Behavior:**

* If task-planning-logs.md already exists, parse existing sections to determine processed work items
* Append only missing work items while preserving existing content
* Never duplicate work item sections, maintain original order for existing sections
* Update Progress Summary section with latest processing status

**Error Handling:**

* Missing planning directory: Guide user to run ado-get-my-work-items first
* Invalid work-items.md format: Surface specific validation errors
* Repository context failures: Continue with available planning file information
* Azure DevOps API errors: Log issues and proceed with offline analysis

## 7. Handoff Examples

**Top Recommendation Section Structure:**

```markdown
## Top Recommendation - WI 1234 (Bug)

### Summary
User sessions intermittently expire due to race condition in token refresh pipeline causing authentication failures.

### Metadata
| Field     | Value            |
|-----------|------------------|
| State     | Active           |
| Priority  | 1                |
| StackRank | 12345            |
| Parent    | 1200 (Feature)   |
| Tags      | auth;performance |

### Description & Acceptance Criteria
[Content from work-items.md planning file]

### Blockers / Risks
* Potential data loss if refresh fails mid-transaction
* Customer impact during peak hours

### Comments Relevant
* John Doe - 2025-08-20: Observed 401 spike after latest deployment
* Jane Smith - 2025-08-22: Stack trace shows race in refresh logic

### Repository Context

**Top Files**
1. src/auth/refresh.ts - Token refresh implementation with suspected race condition
2. src/middleware/session.ts - Session management consuming refreshed tokens
3. src/config/auth.ts - Authentication configuration and timeout settings

**Implementation Detail Leads**
* Add mutex/lock around token refresh sequence
* Implement retry logic with exponential backoff
* Review session validation timing

**Data / Config Touchpoints**
* ENV TOKEN_REFRESH_TIMEOUT_MS
* config/auth.json - Token settings
* Redis session store configuration

**Related Items**
* WI 1250 (Task) - Add integration tests for auth flow
* WI 1260 (Bug) - Related session timeout issues

### Ready-to-Research Prompt Seed
**Objective:** Eliminate race condition in token refresh to prevent session invalidation
**Unknowns:** Exact concurrency trigger mechanism; Downstream cache impact
**Candidate Files:** src/auth/refresh.ts; src/middleware/session.ts; src/config/auth.ts
**Risks:** Session expiry cascades; Data loss during refresh
**Next Steps:** Instrument refresh path; Add concurrency controls; Design integration tests
```

**Additional Work Item Section Structure:**

```markdown
### WI 1300 - Refactor logging adapter for async streams

**Summary:** Current logging adapter drops messages under high concurrency; requires refactor for proper backpressure handling.

**Metadata:** State=Active | Priority=2 | StackRank=14000 | Type=Task | Parent=1200

**Key Files:**
1. src/logging/adapter.ts - Main logging implementation dropping messages
2. src/logging/queue.ts - Message queue with latency issues
3. src/config/logging.ts - Buffer size and timeout configurations

**Implementation Detail Leads:**
* Implement bounded channel pattern for message buffering
* Add flush-on-shutdown mechanism
* Review async stream backpressure handling

**Ready-to-Research Prompt Seed:**
**Objective:** Ensure lossless async logging under high load
**Unknowns:** Optimal buffer size; Memory usage patterns
**Candidate Files:** src/logging/adapter.ts; src/logging/queue.ts
**Next Steps:** Benchmark current drop rate; Design backpressure solution
```

---

Proceed with work item processing and task planning handoff generation by following all phases in order
