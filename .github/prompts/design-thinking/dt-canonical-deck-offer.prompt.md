---
description: "Offer canonical deck generation after any canonical artifact is written or updated — reads coaching state, checks cooldown, frames the offer in HVE coaching voice, and invokes generate-canonical-deck when confirmed — Brought to you by microsoft/hve-core"
agent: "DT Coach"
argument-hint: "[project-slug=...] [method-context=...] [trigger-context=...] [triggering-artifact=...]"
---

# DT Canonical Deck Offer

Offer the team an opportunity to generate or update the canonical deck after any meaningful canonical artifact is written. Uses HVE Core's observational, option-framing coaching voice.

This prompt fires on **artifact write events** — not method boundaries. A team working in Method 1 for several days will see this offer each time they write a new canonical artifact (Vision Statement, Problem Statement, Scenario, Use Case, Persona), as long as cooldown conditions are satisfied.

Do not invoke this prompt for non-canonical artifacts (stakeholder maps, interview notes, HMW questions, observation logs). Do not invoke during Methods 6-9 unless the team explicitly requests customer card generation.

## Inputs

* `${input:project-slug}`: (Required) Kebab-case project identifier for the active DT project.
* `${input:method-context}`: (Required) Integer 1-5 — the active method at time of invocation.
* `${input:trigger-context}`: (Optional) One of `artifact-write`, `session-start-stale`, `explicit-request`. Controls which voice template is selected and whether cooldown applies. Defaults to `artifact-write`.
* `${input:triggering-artifact}`: (Optional) Path of the canonical artifact that triggered this offer. Used for cooldown tracking. Required when `trigger-context` is `artifact-write`.

## Requirements

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write output outside this directory.
* Respect the team's answer. If they decline, do not re-offer for the same artifact. Move on without comment.
* Use the coaching voice defined in `.github/instructions/design-thinking/dt-canonical-deck.instructions.md`. Do not make the offer sound transactional or automated.
* When `trigger-context` is `explicit-request`, skip all cooldown checks and generate immediately.
* After a successful create or refresh, delegate any PowerPoint follow-up to `dt-build-customer-cards.prompt.md` rather than calling the PowerPoint build script directly from this prompt.
* When commands are required (for example fingerprint/hash checks), explain command intent in plain language before execution so the user does not need to interpret command text.

---

## Required Steps

### Step 1: Read Coaching State and Detect Deck Mode

1. Read `.copilot-tracking/dt/{project-slug}/coaching-state.md`.

2. If `trigger-context` is `explicit-request`: skip cooldown checks in sub-step 3, continue to sub-step 4.

3. Check cooldown conditions. Stop and do not offer if ANY of the following are true:
   - `canonical_deck.session_declined` is `true` — team opted out for this session.
   - `canonical_deck.last_offered_artifact_path` equals `triggering-artifact` — this same artifact already triggered an offer.

4. Detect deck mode by inspecting the `canonical/` directory under the project slug:
   - Check for `canonical/vision-statement.md`, `canonical/problem-statement.md`.
   - Check for files under `canonical/scenarios/`, `canonical/use-cases/`, `canonical/personas/`.
   - Count existing canonical deck entries.
   - If zero entries exist: **deck mode is `create`** — the deck does not exist yet for this project.
   - If one or more entries exist: **deck mode is `update`** — existing entries will be refreshed and new ones added.

5. Identify which source artifacts are available now in the method directories. Compare against the fingerprints stored in `canonical_deck.snapshots.method_{N}.fingerprints` to determine what has changed since the last snapshot.

Before any fingerprint command execution, provide a brief explanation:

1. What is being checked: artifact changes since last snapshot.
2. Why it is needed: refresh only changed deck entries.
3. What happens next: generate or update canonical entries based on comparison results.

If no canonical source artifacts exist yet in any method directory (only non-canonical files or a bare coaching state), respond:

> No canonical artifacts found yet. Once you have a vision statement, problem statement, scenario, use case, or persona, I can start the canonical deck.

Then stop.

### Step 2: Construct the Offer

Select the voice template based on deck mode, `trigger-context`, and the artifact type that just changed. Adapt templates using specific artifact names from the coaching state — never deliver verbatim if context improves it.

#### Create Mode — First Deck Entry

Use create-mode voice when deck mode is `create` (no entries exist yet):

**Vision Statement or Problem Statement:**
> I can rough that into a scope card — a clean header, customer summary, and a few metadata tags. Makes it easy to compare your understanding now versus later. Want me to start the deck?

**Scenario:**
> That scenario is a good first candidate for the canonical deck. I can create the initial structure now — scenario card, required sub-sections, and a readiness flag. Want that?

**Persona:**
> That persona could be the first entry in the canonical deck. I can capture it now, complete with description, goals, and needs. Want me to start?

**Multiple artifacts (3+ available, deck still empty):**
> You have {N} canonical artifacts and no deck yet. I can create the initial deck covering all of them — shows what we have committed to at this stage. Want me to set that up?

#### Update Mode — Refresh Existing Deck

Use update-mode voice when deck mode is `update` (entries already exist):

**Artifact that changed since last snapshot:**
> {artifact-name} changed since the last deck snapshot. I can update that entry and add any new artifacts from this method. Want me to refresh the deck?

**Multiple artifacts changed:**
> {N} artifacts changed since the last deck snapshot. I can refresh those entries to reflect the current state. Want that before we move on?

**`session-start-stale`:**
> A few artifacts changed since the last deck snapshot. Want me to refresh the deck, or are you still mid-revision?

Deliver the offer as a single short message in the current conversation flow. Do not prefix it with phase headers or announcements. It should feel like a natural coaching observation.

### Step 3: Wait for User Response

After delivering the offer, wait for the user's response. Do not proceed until they respond.

Map the response:

| User signal                                       | Interpretation    | Next step                    |
|---------------------------------------------------|-------------------|------------------------------|
| "yes", "sure", "go for it", "do it", "yes please" | Accept            | Step 4: Execute              |
| "no", "not now", "skip it", "later", "move on"    | Decline           | Step 5: Record decline       |
| "what is it?", "explain", "why?"                  | Needs explanation | Explain, then re-offer       |
| "stop asking", "never mind"                       | Session opt-out   | Step 5: Set session_declined |
| Asks about content ("what goes in it?")           | Needs context     | Explain, then re-offer       |

#### Explanation (when requested)

> The canonical deck is a structured markdown capture of each artifact produced so far — vision, problem, scenarios, use cases, personas. Each entry has a customer-facing summary and internal metadata: where it came from, whether the team thinks it is done, and whether it is ready for customer review.
>
> Right now it is a thinking tool — it helps us see what we have committed to and where our understanding is still rough. Later, it becomes the source from which we derive clean customer cards, without manual translation.

After explaining, re-deliver the offer from Step 2 and wait for a response.

### Step 4: Execute — Create or Update

Use the deck mode and method context determined in Step 1 to govern execution.

#### Artifact Maturity by Method

Before invoking `generate-canonical-deck.prompt.md`, determine artifact maturity from the active method:

| Method | `Internal state` for all entries                                               | `Candidate for immediate delivery` |
|--------|--------------------------------------------------------------------------------|------------------------------------|
| 1      | `HVE Core: needs work`                                                         | `no`                               |
| 2      | `HVE Core: needs work`                                                         | `no`                               |
| 3      | `HVE Core: needs work` (or `think done` for artifacts that survived synthesis) | `no`                               |
| 4      | `HVE Core: needs work` (or `think done` for validated artifacts)               | `no`                               |
| 5      | `HVE Core: think done` for validated artifacts; `needs work` for others        | Assess per entry                   |

Pass this maturity context to `generate-canonical-deck.prompt.md` so entries reflect the team's actual confidence level, not a wishful state.

#### Create Path (deck mode is `create`)

Invoke `generate-canonical-deck.prompt.md` with:

- `project-slug`: pass through from input
- `output-dir`: `canonical`
- `method-context`: pass through from input — used to set `Internal state` and `Candidate for immediate delivery` per the maturity table above
- `mode`: `create` — generate all available canonical source artifacts as new deck entries

After generation:

1. Report to the team:
   > Created the canonical deck in `canonical/`. {entry_count} entries — {candidate_count} marked as candidate for immediate delivery.
   >
   > {If method_context <= 4}: All entries are marked as needs work — expected at Method {N}. The deck shows what we have committed to so far.
   >
   > {If candidate_count > 0}: {candidate_count} entries look customer-ready. We can revisit those before Method 8 testing.

2. Update the coaching state (create the `canonical_deck` block first if it does not exist, following the schema in `dt-canonical-deck.instructions.md`):
   - Set `canonical_deck.snapshots.method_{N}.status: generated`
   - Set `canonical_deck.snapshots.method_{N}.timestamp`, `output_path` (always `{project-slug}/canonical`), `entry_count`, `candidate_count`, `fingerprints`
   - Clear `canonical_deck.last_offered_artifact_path` (set to `null`)

3. Invoke `/dt-build-customer-cards` with:
   - `project-slug`: pass through from input
   - `canonical-dir`: `.copilot-tracking/dt/{project-slug}/canonical`
   - `render-dir`: `.copilot-tracking/dt/{project-slug}/render`
   - `trigger-context`: `post-deck-refresh`

#### Update Path (deck mode is `update`)

Invoke `generate-canonical-deck.prompt.md` with:

- `project-slug`: pass through from input
- `output-dir`: `canonical`
- `method-context`: pass through from input — used to set `Internal state` and `Candidate for immediate delivery` per the maturity table above
- `mode`: `update` — refresh entries whose source artifacts changed (fingerprint mismatch); add entries for new artifacts not yet in the deck; do not overwrite entries whose source artifacts are unchanged

After generation:

1. Report to the team:
   > Refreshed the canonical deck. {updated_count} entries updated, {added_count} new entries added — {total_count} total.
   >
   > {If method_context <= 4}: Entries are marked as needs work — expected at Method {N}.
   >
   > {If candidate_count > 0}: {candidate_count} entries are now marked as candidate for delivery.

2. Update the coaching state:
   - Set `canonical_deck.snapshots.method_{N}.status: generated`
   - Set `canonical_deck.snapshots.method_{N}.timestamp`, `output_path`, `entry_count`, `candidate_count`, `fingerprints` (update only the fingerprints for changed and new artifacts)
   - Clear `canonical_deck.last_offered_artifact_path` (set to `null`)

3. Invoke `/dt-build-customer-cards` with:
   - `project-slug`: pass through from input
   - `canonical-dir`: `.copilot-tracking/dt/{project-slug}/canonical`
   - `render-dir`: `.copilot-tracking/dt/{project-slug}/render`
   - `trigger-context`: `post-deck-refresh`

### Step 5: Record Decline

1. Set `canonical_deck.last_offered_artifact_path` to `triggering-artifact` so this artifact does not trigger another offer.
2. If the team said "stop asking", "never mind", or similar opt-out signal, set `canonical_deck.session_declined: true`.
3. Otherwise, do not set session_declined — the team may want the offer again for the next artifact.
4. Do not comment on the decline. Resume coaching normally.

The team can explicitly ask for the canonical deck at any time regardless of session_declined status.
