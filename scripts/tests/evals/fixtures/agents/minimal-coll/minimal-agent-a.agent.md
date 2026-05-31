---
description: Minimal fixture agent A for surface-signature and dep-map tests.
model: claude-opus-4.7
instructions:
  - .github/instructions/minimal.instructions.md
---

# Minimal Agent A

Fixture agent. Writes only into `.copilot-tracking/minfix/`.

Subagent reference: #file:.github/agents/minimal-coll/subagents/minimal-subagent.agent.md

Markdown link: [minimal instructions](.github/instructions/minimal.instructions.md)

Glob subagent reference: .github/agents/minimal-coll/subagents/*.agent.md

Broken reference: [missing](.github/instructions/does-not-exist.instructions.md)

Start responses with: `## ✨ Minimal Agent A: [Task]`
