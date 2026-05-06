# Prototype Workflow

Six-step workflow for building and evaluating a high-fidelity prototype experiment.

## Step 1: Write the Experiment Card

Before any code is written, create `experiment-card.md`:

1. Ask the user for their hypothesis in plain language.
2. Ask what success looks like. Push for measurable criteria, not vibes.
   If the user says "users should like it," respond: "What would users DO
   differently if they liked it? Complete a task faster? Come back again?
   That's your metric."
3. Ask what would prove the hypothesis wrong. This is the hardest question
   and the most important one.
4. Identify which parts will be real and which will be simulated.
5. Define the measurement plan: what telemetry events, how many sessions.
6. Write the experiment card using the [experiment card template](templates.md#experiment-card-template).

**Checkpoint**: `experiment-card.md` exists with hypothesis, success criteria,
failure criteria, simulation inventory, and measurement plan. User has confirmed
it reflects their intent.

## Step 2: Scaffold the Prototype

1. Create the project directory using the prototype name as a kebab-case slug.
2. Detect or confirm the stack preference:
   - Default: plain HTML/CSS/JS (no build step, no framework, open `index.html`).
   - If backend needed: ask `python`, `node`, or `dotnet` and scaffold minimal server.
3. Generate `style.css` with the rough UI constraints pre-applied.
4. Generate `telemetry.js` with the appropriate telemetry level.
5. Create the `sim/` directory with fixture templates matching the simulation
   inventory from the experiment card.
6. Create the `data/` directory with an empty SQLite database or starter JSON
   files.
7. Generate `README.md` with setup and run instructions.

**Checkpoint**: Project runs locally with `open index.html` or a single terminal
command. The experiment banner is visible. Telemetry is capturing events to a
local file.

## Step 3: Build the Core Interaction

Focus exclusively on the interaction that tests the hypothesis. Do not build
features that do not directly contribute to validating or invalidating the
hypothesis.

1. Identify the core user task from the experiment card.
2. Build the minimum UI to support that task:
   - Form inputs, buttons, display areas, and nothing more than needed.
   - Wire up simulation stubs for any components marked as simulated.
   - Connect to SQLite or file storage for any state that must persist.
3. Add telemetry events for:
   - Task start and completion.
   - Each meaningful interaction point.
   - Error cases.
4. If an LLM is used for simulation, implement the call with:
   - A system prompt in `sim/prompts/` describing expected behavior.
   - Visible `[SIMULATED]` badge on any LLM-generated output.
   - Fallback to a canned response if the LLM is unavailable.

**Checkpoint**: A user can walk through the core task end-to-end. Simulated
parts are visibly labeled. Telemetry events fire correctly (verify by checking
the telemetry output file).

## Step 4: Add Secondary Views

If the hypothesis requires context beyond the core interaction:

1. Add navigation between views (plain `<a>` links or minimal routing).
2. Build supporting views: dashboards, lists, detail pages, all rough.
3. Populate with realistic sample data from `sim/fixtures/`.
4. Do not exceed 5 total views. If you need more, your hypothesis is too broad.

**Checkpoint**: All views needed to test the hypothesis are navigable. No view
exists that does not directly support the experiment.

## Step 5: Run a Test Session

Guide the user through running a test session:

1. Open the prototype in a browser.
2. Follow a task script derived from the experiment card's success criteria.
3. After the session, generate a Markdown report in `reports/session-{n}.md`
   using the [session report template](templates.md#session-report-template).

**Checkpoint**: Session report exists. Telemetry data is captured and parseable.

## Step 6: Generate the Experiment Report

After the target number of sessions, produce a summary report:

1. Aggregate telemetry data across all sessions.
2. Evaluate each success criterion against collected evidence.
3. Declare the hypothesis supported, weakened, or invalidated.
4. Document what was learned regardless of outcome.
5. Recommend next steps: iterate (refine and retest), pivot (new hypothesis),
   or proceed (move toward production).

Write to `reports/experiment-summary.md` using the
[experiment summary template](templates.md#experiment-summary-template).

**Checkpoint**: Experiment summary exists with evidence-backed verdict. Team
has a clear next step.
