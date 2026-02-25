---
description: 'Manufacturing reference scenario for DT learning — factory floor improvement project used across all 9 curriculum modules'
applyTo: '**/.copilot-tracking/dt/**/curriculum-*'
---

# Manufacturing Reference Learning Scenario

## Scenario Overview

Meridian Components is a mid-size manufacturer producing precision metal parts across three shifts. The plant uses mixed automation and manual processes with 120 operators, 12 shift supervisors, 4 quality engineers, and a plant manager.

*Problem signal*: First-pass yield on the night shift runs 12% below day shift. Defect rates triggered two customer escalations in the past quarter. The plant manager's initial request is "build a quality dashboard."

*Stakeholders*: Line operators (hands-on process), shift supervisors (floor oversight), quality engineers (defect analysis), maintenance engineers (equipment calibration), safety officer (PPE and procedure compliance), plant manager (production targets), union representative (labor agreements), temporary workers (seasonal staffing).

*Complexity dimensions*: Technical (equipment calibration drift, sensor data gaps), human (training inconsistency, fatigue patterns, informal workaround culture), organizational (shift handoff information loss, day-shift management bias), external (customer delivery expectations, regulatory compliance).

## Scenario Progression

The scenario flows through all 9 methods. Each module builds on previous outputs.

### Methods 1-3: Problem Space

Scoping reveals "build a quality dashboard" is a frozen request masking information asymmetry between shifts. Research through Gemba walks, operator shadows, and shift handoff observations uncovers that night-shift operators lack the informal knowledge transfer, rapid-response support, and management oversight day shifts enjoy.
Workers spend 10-15 minutes finding correct manual sections while actual repairs take 5-10 minutes. Synthesis of interview and observation data produces a core theme: operators need immediate access to contextual repair knowledge without leaving their station.

### Methods 4-6: Solution Space

Brainstorming against three constraints (85-90 dB noise, greasy hands, limited floor space) generates four solution themes: hands-free interaction, visual guidance, collaborative knowledge sharing, and proactive assistance.
Concept development focuses on a voice-guided repair system with glove-friendly fallback controls. Lo-fi prototyping reveals touchscreen contamination, QR code lighting failures, and production-timing conflicts — constraints invisible from a desk.

### Methods 7-9: Implementation Space

Hi-fi prototyping compares three microphone options (industrial-grade array, bone-conduction headset, directional lapel mic) in 85-90 dB environments and validates glove-friendly interfaces. Testing across four operator types shows 40% higher adoption with glove-friendly design.
Shift-change periods generate 5x normal query volume. Emergency stop procedures are used 300% above forecast, revealing safety as the highest-value use case. Handoff documentation packages the validated solution with telemetry showing new hires use the system 3x more frequently than experienced operators.

## Interview Excerpts

Present these fictional excerpts during research and synthesis exercises.

*Night-shift operator A*: "When something goes wrong at 2 AM, I radio the supervisor, but they're covering three lines. By the time they get to me, I've already tried two things from memory. Sometimes I fix it, sometimes I make it worse."

*Night-shift operator B*: "The manual is in the break room. I'm not walking 200 feet to look something up while my line is down. Carlos on day shift just asks Mike — Mike's been here 22 years and knows everything."

*Night-shift operator C*: "New people follow the book step by step, which is fine for normal stuff. But when the machine does something weird, the book doesn't cover it. We used to have Gloria on nights who knew every trick. She retired in March."

*Day-shift operator*: "When I get stuck, I tap the person next to me or call over to the senior operator. Usually sorted in two minutes. I heard night shift doesn't have that — their experienced people retired last year."

*Shift supervisor*: "I can see my quality numbers tanking after midnight, but I'm stretched across three production lines. The operators aren't doing anything wrong — they just don't have backup when something unusual happens."

*Quality engineer*: "Calibration drift accounts for maybe 30% of the defect variance. The rest is procedural — the same repair done three different ways depending on who's working. Day shift has more consistent execution because they can ask each other."

*Maintenance engineer*: "Equipment alerts fire constantly — most are false positives from old sensor thresholds. Operators learn to ignore them. The real problems get caught by operators noticing vibration changes or unusual sounds, not by sensor data."

*Safety officer*: "Emergency procedures are documented, but under pressure operators revert to whatever they practiced most recently. If the documented procedure isn't the one they rehearse, they'll improvise. That's where incidents happen."

## Observation Data Points

Use these for Module 3 affinity clustering exercises.

1. Night-shift operators take 10-15 minutes to locate correct manual sections
2. Day-shift operators resolve issues by asking experienced colleagues
3. Senior operator retirements removed institutional knowledge from night shift
4. Supervisors cover three lines simultaneously during off-hours
5. Repair procedures vary by operator — same fix done three different ways
6. Equipment alerts produce frequent false positives from outdated thresholds
7. Operators detect problems through vibration and sound before sensors trigger
8. Break room manual location creates 200-foot round trip from production line
9. Calibration drift accounts for approximately 30% of defect variance
10. Remaining 70% of variance is procedural and knowledge-based
11. Day-shift knowledge transfer happens informally through proximity
12. Night-shift radio communication is delayed by supervisor coverage gaps
13. Experienced operators develop personal repair shortcuts not documented in SOPs
14. New hires follow SOPs strictly but lack context for unusual situations
15. Shift handoff logs capture machine status but not in-progress troubleshooting
16. Greasy hands prevent touchscreen interaction on the production floor
17. Noise at 85-90 dB prevents normal voice conversation
18. Temporary workers are excluded from informal knowledge networks
19. Emergency procedures are accessed more than routine features during pilot testing
20. Shift-change periods generate concentrated information-seeking spikes

## Test Results

Use these fictional results for Module 7-9 exercises.

| Test | Scenario                                                     | Result | Notes                                                        |
|------|--------------------------------------------------------------|--------|--------------------------------------------------------------|
| T1   | Voice command accuracy at 85 dB, industrial array mic        | Pass   | 94% accuracy, exceeds 90% threshold                          |
| T2   | Voice command accuracy at 85 dB, bone-conduction headset     | Pass   | 91% accuracy, operators found it uncomfortable with PPE      |
| T3   | Voice command accuracy at 85 dB, directional lapel mic       | Fail   | 78% accuracy, below 90% threshold                            |
| T4   | Glove-friendly gesture input for repair category selection   | Pass   | Completed selection in under 8 seconds                       |
| T5   | Screen readability at arm's length under production lighting | Fail   | 40% of operators reported difficulty; font size insufficient |
| T6   | System response time during peak production load             | Pass   | Average 2.1 seconds, within 3-second threshold               |
| T7   | Repair category terminology match with operator language     | Fail   | 35% wrong-category selection rate; terminology mismatch      |
| T8   | Emergency procedure lookup under simulated urgency           | Pass   | 95% completion rate, 12-second average; highest satisfaction |

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
