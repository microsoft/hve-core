---
name: research
description: Initiates research for implementation planning based on user requirements. Dispatches task-researcher-subagent instances and synthesizes findings into research documents.
maturity: stable
context: fork
agent: task-researcher
argument-hint: "[topic]"
disable-model-invocation: true
---

# Task Research

Research the following topic for implementation planning:

$ARGUMENTS

Discover applicable `.github/instructions/*.instructions.md` files based on file types and technologies involved, and proceed with the Required Phases.
