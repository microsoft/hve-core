---
description: 'Evidence collection and editorial decisions for HVE Core presentations.'
---

# Research and Writing

## Establish What the Talk Must Explain

Turn the brief into answerable questions and a short claim list. Identify the audience's
starting knowledge and what they should understand or do after the talk. Separate required
sections from optional background. A short update, training session and architecture review
need different detail; do not inherit the exemplar's slide count or snack theme.

For each material claim, retain its source, relevant symbol or heading, date/version,
evidence type and limitation. Record whether it is historical, current behavior, a proposal
or an illustrative example. Put public references in the deck's source registry and connect
them to the relevant slides. Keep internal evidence locations out of the shared deck.

## Collect Information

Start with supplied research and the current files that own the behavior. Confirm that their
date and scope still fit. Do not repeat an entire aesthetic or product survey because a new
turn began. Conversely, an old slide or generated answer is not proof of current behavior.

For repository history:

* Use the current checkout and read-only Git history. Trace the artifact path with
  `git log --follow` when appropriate, inspect the actual change with `git show`, and
  compare the parent revision for introduction/removal claims.
* Prefer merged history for public milestones. Use `gh pr view` or equivalent read-only
  GitHub evidence for the PR title, merge date and URL. Distinguish branch experiments
  from the first merged change.
* Preserve date and timezone meaning. Do not fabricate a milestone for each month or
  call a consolidation the first appearance of a capability.
* Use immutable commit links for historical source. A moving default branch supports
  a dated observation, not a reproducible version claim.

For current HVE behavior, read the owning skill, agent and relevant references/templates.
Explain the current contract rather than recreating an older remembered template.
When discussing RPI, distinguish the standalone phase skills from the optional RPI Agent;
manual advancement, automatic progression, retained decisions and stop boundaries differ.
When discussing HVE Builder, distinguish source review, frozen-version behavior evidence
and primary-assistant correction. Verify these claims again when their as-of date changes.

For client behavior, use official documentation and released source where available.
For VS Code UI, inspect the relevant `microsoft/vscode` component and supplied screenshots.
Name preview/development features and host/profile/environment conditions. A source-file
read establishes what the code says, not a performed installation or live interaction.

When sources disagree, record the conflict and prefer the relevant authoritative/versioned
source. If neither settles an essential claim, retain the gap. A user screenshot establishes
that depicted state, not a universal inventory, model choice or version guarantee.

## Write for the Presenter and Audience

Give each slide one main point with the minimum supporting text needed to understand it.
Put explanations that the presenter can say aloud in notes; keep the visible evidence or
diagram readable. Notes still ship with the deck and must be safe to share.

Use headings that name the topic, decision or action. Prefer concrete actors and verbs:
"The planning assistant resolves the findings" over "parent-owned convergence" unless that
term itself is being taught. Introduce necessary terminology once, then use it consistently.
Keep exact skill names, UI labels, artifact headings and status vocabularies intact.

Review every visible string, walkthrough step, caption, source note and speaker note for:

* Unsupported promotion or inflated significance. Replace it with the observed change.
* Repeated slogan fragments, forced groups of three or "not X, but Y" constructions.
  State the useful fact directly; keep a contrast when it prevents a real misconception.
* Vague words such as "robust", "seamless" and "powerful". Name the behavior instead.
* Repeated announcements about the presentation or how carefully it was researched.
  Keep concise fidelity labels and actual uncertainty rather than defensive repetition.
* Long noun chains, unnecessary abstraction, unexplained acronyms and verbose verb phrases.
* Source inflation, vague expert attribution or certainty unsupported by the cited source.
* Synonym changes that blur a technical distinction. A completed execution and a passing
  outcome are different; preserve the repository's actual labels for each.

These are editing heuristics, not reliable tests of AI authorship. Do not promise that
rewriting makes text undetectable or infer who wrote it from a style pattern.
Use the repository `writing-style.instructions.md` and `markdown.instructions.md` as the
canonical conventions, including punctuation and current `ms.date` handling.

## Citations and Reuse

Prefer original summaries and diagrams with unobtrusive citations. Do not copy upstream
prose, branding, screenshots or CSS into a distributable deck without the necessary rights
and attribution. Preserve software notices when reusing the deck shell or third-party
library. A public reference link does not grant permission to republish its content.

User screenshots can guide an original reconstruction. Remove private workspace names,
accounts, paths and incidental inventory counts from shared examples; substitute clearly
labelled fictional context. Do not imply a screenshot's selected option is the current
user's decision unless they actually made it.

## Source References

* [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/brand-voice-above-all-simple-human):
  direct, conversational and scannable technical language.
* [Google Technical Writing](https://developers.google.com/tech-writing/one/short-sentences):
  single-idea sentences and removal of unnecessary words.
* [Git log documentation](https://git-scm.com/docs/git-log):
  history inspection; inspect actual changes before making chronology claims.
* [VS Code customization documentation](https://code.visualstudio.com/docs/agent-customization/overview):
  current client concepts and links to owning feature documentation.
