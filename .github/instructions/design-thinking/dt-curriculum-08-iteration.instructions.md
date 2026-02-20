---
description: 'DT Curriculum Module 8: User Testing — concepts, techniques, checks, and exercises'
applyTo: '**/.copilot-tracking/dt/**/curriculum-08*'
---

# DT Curriculum Module 8: User Testing

User testing validates whether the technically feasible solution actually works for the people it serves. This Implementation Space method is the primary trigger for non-linear navigation — test results may require returning to earlier methods rather than proceeding forward. This module teaches learners how to design tests that reveal genuine usage patterns, ask questions that generate actionable insight, and make honest assessments about when findings require iteration.

## Key Concepts

*Leap-enabling vs leap-killing questions* — Leap-killing questions produce yes-or-no responses with no actionable insight ("Do you like this?" → "Yes").
Leap-enabling questions reveal how users actually experience the solution ("Walk me through what happened when the alarm went off"). The distinction is whether the question opens up exploration or shuts it down. Learners commonly default to satisfaction-style questions because they feel polite; these questions produce reassuring but useless data.

*Non-linear iteration loops* — Test results frequently point backward to earlier methods rather than forward to deployment. When users struggle with the fundamental interaction model, that is a Method 4 finding. When users reveal unmet needs not captured in research, that is a Method 2 finding.
When test results show the problem was framed too narrowly, that is a Method 3 finding. Method 8 is where the DT process most often becomes non-linear. Learners resist backward movement because it feels like regression; it is actually the design process working correctly.

*Behavior over opinions* — What users do matters more than what they say. An operator who says "this is great" but consistently reaches for the old manual reveals a gap between stated preference and actual behavior. Observation of task completion, hesitation, workarounds, and abandonment provides more reliable data than satisfaction ratings. Learners tend to prioritize verbal feedback because it is easier to collect and interpret.

*Confirmation bias prevention* — Teams naturally focus on successful test sessions while dismissing failures as edge cases. If 7 of 10 users succeed but 3 abandon the task, those 3 abandonment sessions may reveal critical design flaws that the 7 successes masked by working around. Learners underestimate how powerfully they want their solution to succeed, which distorts how they weigh evidence.

## Techniques

*Leap-enabling question progressions* start with observation ("Walk me through what just happened"), move to experience ("What was going through your mind when you reached that screen?"), and then explore alternatives ("What did you expect to happen instead?"). Each stage builds on the previous answer. Good output is an unexpected insight about user mental models. The pitfall is scripting questions so tightly that users cannot take the conversation in revealing directions.

*Task-based testing* gives users a scenario and goal without instructions on how to achieve it: "You are in the middle of a repair and need to find the torque specification for this bolt. Use the system to find it." Observe their approach — what they try first, where they hesitate, what they misunderstand. Good output is a task-completion map showing success paths, failure points, and workarounds. The pitfall is providing hints or correcting users during the test, which masks usability problems.

*Non-linear loop decision framework* assesses test findings against four possible destinations: proceed to Method 9 (findings are refinements), return to Method 7 (technical approach needs adjustment), return to Method 4-6 (solution concept needs rethinking), or return to Method 2-3 (problem understanding is incomplete). Good output is a clear recommendation with evidence. The pitfall is defaulting to "minor refinements" when findings actually indicate a deeper problem.

## Comprehension Checks

1. Convert this leap-killing question into a leap-enabling question: "Is the voice command system easy to use?" Explain what additional insight the revised question can reveal.
2. During testing, 7 operators completed the task successfully while 3 abandoned it halfway through. A team concludes the solution is 70% effective. What is wrong with this interpretation?
3. An operator says "I like this system" but during observation was seen reaching for the paper manual twice during a single repair. Which data point is more reliable and why?
4. Test results show users can operate the system but consistently misunderstand which repair category to select. Does this finding point to Method 7 (technical adjustment), Method 4-6 (concept rethinking), or Method 2-3 (research gap)? Explain your reasoning.

## Practice Exercises

*Exercise: Question redesign* — Rewrite these five questions for a manufacturing floor test session, converting each from leap-killing to leap-enabling: (a) "Do you find the interface intuitive?" (b) "Is the text readable?" (c) "Would you use this system every day?" (d) "Is the response time acceptable?" (e) "Do you prefer this to the current process?" For each, explain what the revised question can reveal that the original cannot.

*Exercise: Non-linear loop assessment* — A test session revealed three findings: (1) operators can use voice commands effectively in 85 dB noise, (2) operators consistently select the wrong repair category because the terminology does not match how they describe problems, (3) operators ignore the system during emergencies and revert to shouting for help. For each finding, identify which DT method it points back to and what specific investigation or change is needed.

## Learner Level Adaptations

Beginners should focus on the leap-killing vs leap-enabling distinction and practice converting questions.

Intermediate learners benefit from analyzing observation data for behavioral contradictions (what users say vs what they do) and understanding the non-linear loop decision framework.

Advanced learners should explore how testing protocol design introduces bias (participant selection, scenario framing, facilitator presence), analyze when a series of backward loops signals a fundamental misframing of the original problem, and critique the ethical dimensions of observing workers' struggles during testing.
