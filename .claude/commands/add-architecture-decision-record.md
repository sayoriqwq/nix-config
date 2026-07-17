---
name: add-architecture-decision-record
description: Workflow command scaffold for add-architecture-decision-record in nix-config.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-architecture-decision-record

Use this workflow when working on **add-architecture-decision-record** in `nix-config`.

## Goal

Records a new Architecture Decision Record (ADR) to document key technical decisions.

## Common Files

- `docs/adr/*.md`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create a new markdown file in docs/adr/ with a sequential number and descriptive name.
- Write the ADR content explaining the context, decision, and consequences.
- Commit the new ADR file with a descriptive commit message.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.