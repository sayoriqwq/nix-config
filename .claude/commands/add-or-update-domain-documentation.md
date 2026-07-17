---
name: add-or-update-domain-documentation
description: Workflow command scaffold for add-or-update-domain-documentation in nix-config.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /add-or-update-domain-documentation

Use this workflow when working on **add-or-update-domain-documentation** in `nix-config`.

## Goal

Adds or updates documentation files that define protocols, context, architecture, or boundaries for the project.

## Common Files

- `docs/agents/*.md`
- `docs/architecture/*.md`
- `CONTEXT.md`
- `AGENTS.md`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Create or update a markdown file in docs/agents/, docs/architecture/, or root documentation files.
- Write or revise the documentation content.
- Commit the changes with a descriptive message.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.