---
description: 'Deep expertise for Method 6: Low-Fidelity Prototypes; advanced paper prototyping, service blueprinting, and experience prototyping'
applyTo: ''
---

# DT Method 06 Deep: Advanced Low-Fidelity Prototyping Techniques

On-demand deep reference for Method 6. The coach loads this file when a user encounters interactive or state-based prototyping challenges, needs to map multi-layer service interactions, wants to simulate full experiences through bodystorming or desktop walkthrough, requires structured feedback session designs beyond standard observation, or faces manufacturing-specific prototyping constraints that exceed the method-tier guidance.

## Advanced Paper Prototyping

The method-tier file covers standard paper prototyping for layout and information shape. The techniques below address interactive, stateful, and context-sensitive paper prototypes that reveal richer constraint discoveries while maintaining lo-fi fidelity.

### Interactive Paper Prototyping

Static paper prototypes show layout but miss the experience of navigating through a system. Interactive paper prototypes use movable elements to simulate transitions:

* Overlay sheets simulate state changes: a base layout stays fixed while transparent overlays swap in to show different modes, error states, or confirmation screens.
* Tabbed paper components let users "click" by flipping between stacked pages, each representing a screen or step in a workflow.
* Sliding panels simulate expanding menus, sidebars, or progressive disclosure by physically sliding paper strips across the prototype.
* A human facilitator plays the computer, swapping elements in response to user actions. This Wizard of Oz approach reveals interaction assumptions faster than discussing them abstractly.

Keep materials rough. Construction paper, sticky notes, and hand-drawn elements enforce the lo-fi constraint. The moment someone opens a design tool, fidelity creep begins.

### State-Based Prototyping

Complex systems have multiple states that interact: normal operation, error conditions, loading states, empty states, and permission variations. State-based paper prototyping maps these explicitly:

* Create a state inventory listing every distinct state the prototype can occupy. Most teams undercount states by 50% or more on their first attempt.
* Build a separate paper representation for each critical state. Seeing error states and edge cases as physical artifacts prevents the common pattern of designing only the happy path.
* Walk through state transitions by physically moving between paper representations. Note where transitions feel abrupt, confusing, or missing entirely.

Coaching prompt: "What does this look like when something goes wrong? Build me the error version."

### Contextual Prototyping

Prototypes built at a desk look different from prototypes built for actual use environments. Contextual prototyping sizes and formats prototypes for the conditions where they will operate:

* Build prototypes at the physical scale of the deployment environment. A dashboard prototype for a factory floor needs to be readable from two meters under fluorescent lighting, not from arm's length in a conference room.
* Test prototypes while wearing the protective equipment operators use. Gloved hands, safety glasses, and hard hats change interaction assumptions fundamentally.
* Simulate environmental noise, vibration, or lighting conditions during prototype testing. A quiet conference room hides the constraints that matter most.

## Service Blueprinting

Service blueprinting maps the full system of interactions supporting a user experience. While individual prototypes test single touchpoints, service blueprints reveal how those touchpoints connect, where handoffs break, and where backstage failures surface as user frustration.

### Four-Layer Structure

A service blueprint organizes interactions into four horizontal layers, each representing a different visibility level:

* Customer actions: what the user does at each step, captured from research observations rather than assumed from process documentation.
* Frontstage interactions: what the user sees, hears, or touches. These are the visible interfaces, communications, and human interactions the user directly experiences.
* Backstage processes: activities that support frontstage delivery but remain invisible to the user. Data processing, scheduling, inventory management, and inter-department coordination live here.
* Support systems: infrastructure, policies, training programs, and external dependencies that enable backstage processes. Failures at this layer often take days or weeks to surface as user-facing problems.

Draw the blueprint on large paper (butcher paper or whiteboard) to maintain lo-fi fidelity. Digital service blueprint tools introduce premature precision.

### Failure Point Identification

Mark locations in the blueprint where service delivery commonly breaks:

* Handoff points between layers are the most failure-prone locations. When a backstage process must trigger a frontstage response, the interface between them deserves scrutiny.
* Time-dependent steps where delays cascade into downstream failures need explicit marking. A 10-minute backstage delay may cause a 2-hour customer wait.
* Single points of failure where one person, system, or process handles all traffic for a step expose fragility that individual prototype testing would miss.

Coaching prompt: "Where in this blueprint would a single person calling in sick cause the whole service to break down?"

### Moments of Truth

Certain interactions disproportionately shape the user's overall experience. Identifying these moments focuses prototyping effort on high-impact touchpoints:

* First impressions set expectations for every subsequent interaction. The onboarding experience anchors user perception even when later interactions improve.
* Recovery moments after failures determine whether users forgive or abandon. A well-handled error builds more trust than flawless operation.
* Transition moments between channels (digital to physical, self-service to human support) expose consistency gaps that erode confidence.

### Cross-Channel Alignment

When a service spans physical, digital, and human touchpoints, prototype consistency across channels:

* Information presented in one channel must match information available in others. Users who receive conflicting data from a screen and a person lose trust in both.
* Interaction patterns should feel related across channels even when implementations differ. A voice interface and a screen interface solving the same problem should use consistent vocabulary and sequencing.
* Test channel transitions explicitly by walking through scenarios that cross from one channel to another mid-task.

## Experience Prototyping

Experience prototyping simulates the full user experience rather than testing isolated interface elements. These techniques immerse the design team in the user's context to surface constraints that screen-based or paper-based prototyping cannot capture.

### Bodystorming

Bodystorming physically acts out interactions in the real or simulated environment:

* Move to the actual location where the solution will operate. Stand where the operator stands, reach where they reach, look where they look.
* Act out each step of the proposed interaction using physical props. A cardboard box substituting for a screen, verbal announcements substituting for alerts, hand signals substituting for system responses.
* Note every moment where the physical environment constrains the proposed interaction: insufficient space, wrong hand occupied, noise drowning out feedback, line of sight blocked by equipment.

Bodystorming reveals ergonomic and spatial constraints that no amount of discussion or sketching surfaces. Teams consistently discover 3-5 critical constraints per session that were invisible during desk-based prototyping.

Coaching prompt: "Stand where the user stands and try to do this task. What gets in the way that you didn't expect?"

### Desktop Walkthrough

Desktop walkthrough uses tabletop miniatures or tokens to simulate complex multi-step processes without requiring full physical simulation:

* Create simple tokens (sticky notes, coins, figurines) representing people, materials, information, and equipment moving through a process.
* Map the process flow on a large table surface, physically moving tokens through each step.
* Introduce disruptions (a token representing a breakdown, a missing person, an information delay) and observe how the process adapts or fails.

Desktop walkthrough works well for processes that span large physical areas or multiple shifts, where full bodystorming would be impractical.

### Day-in-the-Life Simulation

Single-session testing captures task completion but misses how a solution integrates across a full work cycle:

* Simulate an entire shift or workday by walking through the sequence of tasks, transitions, and interruptions a user faces.
* Include mundane activities (breaks, shift handoffs, equipment changeover) that often reveal integration friction invisible during isolated task testing.
* Track cognitive load accumulation across the simulated day. A solution that works perfectly in isolation may become burdensome when added to an already full attention budget.

### Emotional Journey Mapping

Track the user's emotional state across prototype interactions to identify friction and delight:

* Plot emotional intensity (positive and negative) at each step of the prototype interaction on a simple curve.
* High negative peaks indicate friction worth addressing. High positive peaks indicate value worth preserving and amplifying.
* Flat emotional lines suggest disengagement, which may indicate that the solution lacks meaningful impact on the user's experience.
* Compare emotional journeys across different user types. The same interaction may delight one stakeholder and frustrate another.

## Advanced Feedback Session Design

The method-tier file provides leap-enabling questions and an observation capture template. The techniques below structure feedback sessions for richer, more actionable data collection while maintaining the lo-fi evaluation frame.

### A/B Prototype Testing

Structured comparison between two prototype variations isolates which elements drive different user behaviors:

* Present two versions that differ in one specific dimension (layout, interaction sequence, information density, feedback timing).
* Ask users to complete the same task with both versions. Observe behavioral differences rather than asking which version they prefer.
* Randomize presentation order across participants to prevent order effects from skewing results.

Keep both prototypes at the same fidelity level. When one version looks more polished, users gravitate toward it regardless of functional merit.

### Think-Aloud Protocols

Having users verbalize their thought process during prototype interaction surfaces mental model mismatches:

* Ask users to narrate their expectations, decisions, and confusion as they interact with the prototype.
* Note gaps between what users expect to happen next and what the prototype provides. These expectation mismatches reveal where the design contradicts users' mental models.
* Silence during think-aloud is diagnostic: it often indicates either deep confusion or automatic understanding. Follow up to determine which.

Coaching prompt: "Tell me what you're looking for right now. What do you expect to happen when you do that?"

### Love/Wish/Wonder Framework

A structured post-interaction debrief collects three distinct response categories:

* Love: what worked well, felt intuitive, or solved a real problem. These elements anchor the next iteration.
* Wish: what the user wanted to change, add, or remove. These represent explicit improvement requests.
* Wonder: open questions, curiosities, or alternative possibilities the user imagines. These often contain the most creative insights.

Capture responses on separate sticky notes (one per thought) to enable later clustering and pattern analysis.

### Hostile User Testing

Deliberately recruiting skeptical, resistant, or edge-case users stress-tests assumptions:

* Identify the user type most likely to reject or resist the proposed solution. Their feedback reveals vulnerabilities that supportive users overlook.
* Include users who have developed strong workarounds for the current process. They will compare the prototype against their optimized status quo, not the unoptimized baseline the design team assumes.
* Include users with accessibility needs, non-standard workflows, or atypical equipment configurations. Edge cases define the boundaries of a solution's viability.

### Feedback Synthesis

Techniques for aggregating observations across sessions into actionable constraint patterns:

* Cluster observations by interaction step rather than by session. This reveals which steps generate consistent friction regardless of the user.
* Distinguish between preference feedback (subjective, varies by user) and usability feedback (objective, consistent across users). Prioritize usability findings.
* Weight behavioral observations over verbal feedback when they conflict. Users who say "this is easy" while making repeated errors are reporting social desirability, not actual experience.

## Manufacturing-Specific Prototyping

Manufacturing environments impose physical, environmental, and workflow constraints that general prototyping techniques underestimate. The patterns below address prototyping within industrial contexts while maintaining lo-fi fidelity.

### Process Flow Prototyping

Map material and information flows through production steps using physical tokens or paper representations:

* Use colored cards or tokens for different flow types: materials (physical items moving through production), information (data, instructions, approvals), and decisions (quality checks, routing choices).
* Walk the actual production floor while mapping flows. Desk-based process mapping omits spatial constraints, distances, and visibility issues that affect every interaction.
* Mark bottlenecks where flows converge or wait. These convergence points are where prototype solutions create the most value or the most disruption.

### Shift Handoff Simulation

Information transfer at shift boundaries is where knowledge loss commonly occurs:

* Simulate a handoff by having one team member brief another on prototype status using only the information artifacts the prototype provides.
* Note what information the incoming person needs but cannot find. These gaps define the prototype's handoff requirements.
* Test handoff under time pressure. Shift changes operate on fixed schedules; a handoff process that requires 15 minutes fails when only 5 minutes are available.

Coaching prompt: "If this person leaves and someone new walks up, what do they need to know that this prototype doesn't tell them?"

### Safety Constraint Testing

Prototype within the safety envelope without compromising it:

* Identify safety zones (clean rooms, PPE-required areas, machine proximity boundaries) where the prototype will operate. The prototype must comply with existing safety requirements, not introduce exceptions.
* Test prototype interactions while wearing required PPE. Hard hats limit upward visibility, safety glasses reduce peripheral vision, ear protection blocks audio feedback, and gloves prevent fine-motor interaction.
* Evaluate whether the prototype introduces new distraction risks. Any interface that diverts operator attention from equipment or environment creates a safety concern worth documenting explicitly.

### Operator Perspective Prototypes

Build prototypes that account for the operator's actual physical and cognitive conditions:

* Contaminated hands (oil, grease, particulates) require touchless or large-target interaction patterns. Prototype and test with simulated contamination.
* Noise levels above 80 dB render audio feedback unreliable. Prototype visual and haptic alternatives.
* Vibration from nearby equipment affects fine motor control and screen readability. Test prototypes mounted on or near vibrating surfaces.
* Limited visibility due to equipment, lighting angles, or protective eyewear constrains display placement and size. Test readability from the operator's actual viewing position, not from a comfortable demo angle.

Coaching prompt: "Put on the gloves and safety glasses. Now try to use this prototype. What changed?"
