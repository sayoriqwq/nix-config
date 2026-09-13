# Agent Protocol

This file is the **normative instruction set** for AI agents working in this repository. The maintainer-facing Chinese translation is in [docs/agents/protocol.zh-CN.md](docs/agents/protocol.zh-CN.md). If they differ, this file controls; fix the translation in the same change.

## 1. Mission

Maintain one auditable, reproducible Nix configuration repository for:

- one primary macOS workstation managed by nix-darwin and Home Manager;
- one secondary NixOS workstation and Linux experiment station;
- one minimal NixOS server whose production capabilities follow current requirements;
- requirement-driven Software owners and Intents explicitly selected by those hosts.

The repository manages selected **configuration declarations**, reusable configuration material and nearby ownership/path documentation. The running environment is the source of truth for actual state. Macwarden provides independent private historical evidence through its own skills; this repository does not govern agents working in other projects or maintain application data and backups.

## 2. Start from the current request

Before changing files, read:

1. this AGENTS.md and the current task request, including its scope and existing authorization;
2. any relevant Issue or PR that exists, including comments, allowed changes and safety conditions;
3. [CONTEXT.md](CONTEXT.md) for domain terms;
4. relevant architecture documents, accepted ADRs and the runbook for an operation you will perform.

A clear current request is sufficient to start work. An Issue is optional; do not create a placeholder Issue to obtain permission to implement.

This protocol governs the collaboration workflow. Older requirements in supporting documents for an Issue, PR, dedicated worktree or merged commit do not restore those as universal gates. Preserve their architecture decisions, evidence requirements and operation-specific safety conditions.

## 3. Routine work

1. Work in the current checkout by default. Use a dedicated branch or worktree when parallel work needs isolation or the user asks for one; prefer `codex/<short-name>`, without a required Issue number.
2. Make the necessary changes within the agreed scope. Preserve unrelated work, including existing uncommitted changes; do not include it in your commit or cleanup.
3. Run the narrowest relevant validation and inspect the final diff.
4. Create a local commit for the completed change unless the user requests otherwise. Report the commit, validation results and any remaining operations or limitations.

Local commits on the current branch, including main, are allowed. Pushing, creating or editing GitHub items, and sending external messages require user authorization; local work does not imply publishing.

Use an Issue when work needs cross-session planning or collaboration, and a PR when review or the user's request calls for it. If PR creation is authorized, start in draft unless the user explicitly requests otherwise. Marking a draft ready, merging and enabling auto-merge each require explicit authorization. Read [issue-tracker.md](docs/agents/issue-tracker.md) when coordinating through Issues or PRs; labels are optional.

Respect real dependencies: complete a prerequisite needed for the next action, rather than waiting for a label, PR merge or Issue closure. Keep unrelated cleanup, upgrades, renames and framework changes out of scope.

## 4. Language

- Normative agent constraints are written in English for precision.
- Maintainer-facing documents, Issue and PR descriptions, validation reports, commit messages and operational instructions are written in Chinese.
- Code identifiers and ordinary code comments are English unless Chinese materially improves maintainability.
- Update the Chinese protocol translation in the same change whenever this file changes.

## 5. Architecture invariants

- Use one top-level Flake as the declaration source of truth.
- Prefer community packages and existing Git/Nix/nh operations for selected long-lived software; choose external ownership when concrete usage or compatibility needs justify it. State each resource's actual write boundary. Before applying or sharing continuously managed settings, inspect relevant live drift and save changes the maintainer wants to retain. Existing community mutable-configuration modules may control selected fields; init-only resources remain independent after creation. See [workstation management](docs/architecture/workstation-management.md).
- Use Home Manager for the portable user layer, nix-darwin for macOS system configuration, and NixOS modules for NixOS system configuration.
- Keep the minimal NixOS server requirement-driven. Add each production capability through an explicitly scoped request; do not restore the retired Ubuntu server layer.
- Keep host and hardware facts under `hosts/<host>/`.
- Keep each software package, stable configuration, service and owner-local asset under `software/<software>/`.
- Keep collectively selected usage requirements under `intents/<intent>/`; Intents use public Software behaviors and explicit dependencies. An Intent need not involve multiple software packages. Do not rely on another Intent incidentally providing a required program.
- Keep only proven reusable System or Home Manager primitives under `modules/`.
- Compose hosts through explicit Intent results, independent Software platform modules and host facts. Imports are the selection mechanism; do not add a global capability registry or automatic discovery.
- Hosts must not import common, desktop, Darwin, Linux or server bundles as substitutes for requirements.
- Create a platform implementation only for a proven behavioral seam. Expose package ownership, managed configuration, mutable-state boundaries, services, network effects and human approval gates.
- Prefer existing Home Manager, NixOS and nix-darwin options over custom activation scripts or generated shell code.
- Put project-specific development dependencies in each project's dev shell, not in the global user profile.
- Git synchronizes declarations. Mutable data, databases, browser profiles, service state and backups require separate data-management procedures.

See [module-boundaries.md](docs/architecture/module-boundaries.md) for path-level rules.

## 6. Safety and authorization

The following actions require explicit, specific user authorization in the current conversation or a relevant Issue or PR:

- activating macOS, NixOS or Home Manager configuration on a real machine;
- changing bootloader, partition, filesystem, encryption, mount, remote network, DNS, firewall or SSH-access configuration;
- running disko, nixos-anywhere, disk-formatting commands, destructive migrations or production restore commands;
- rebooting, shutting down or replacing a remote server;
- migrating or deleting production data.

For these actions, establish the target, exact action, relevant revision or build, execution window, stop conditions, readback and rollback. Reuse authorization while its stated scope and conditions remain valid; ask again only when the proposed action exceeds them. A build, local commit, PR merge or general desire for improvement is not authorization for a different machine action.

Additional hard rules:

- Never commit plaintext secrets, tokens, passwords, private keys, recovery codes, decrypted SOPS output or private .env files.
- Never change an existing `system.stateVersion` or `home.stateVersion` merely to match the current release.
- Edit generated hardware configuration only with target-machine evidence and explicit task scope.
- Never weaken SSH access or firewall safety to make deployment easier.
- Introducing flake-parts, Blueprint, Clan, deploy-rs, Colmena, impermanence, ZFS, LUKS or another major framework/storage design requires explicit scope and an accepted ADR; an Issue is not a required format for that decision.
- Never run remote installation or destructive commands as part of unattended agent work.
- Design maintainer-run commands for human input on the target machine. Never require manually typing hashes, store paths, public keys or long argument lists. When an exact action cannot be a short command, transfer and verify a narrowly scoped temporary helper, expose a short entry command and remove the helper after use.

## 7. Evidence

Before writing host-specific configuration, gather the facts relevant to the change using [host-inventory.md](docs/runbooks/host-inventory.md). Reuse verified facts when still applicable; gather new evidence or document an unknown when they are missing or contradicted. Never guess usernames, architecture, hostnames, disks, boot mode, interfaces, state versions, service inventory or network settings.

- Record only non-secret facts required for reproducibility.
- Redact public IPs, account identifiers, tokens, serial numbers, private hostnames and other sensitive values unless the maintainer explicitly approves storing them.
- Preserve original NixOS hardware configuration, boot configuration and state-version values during adoption.
- Before a destructive server step, document backup location, restore test, rescue-console availability, target disk, boot mode, network model and SSH recovery path.

## 8. Validation and completion

Run the narrowest relevant checks and report exact commands and results:

- Documentation changes: check links, headings, terminology and English/Chinese agreement; do not claim unrun Nix evaluation or build results.
- Nix changes: format the changed files, evaluate affected declarations and run relevant contract checks. Build the affected package or host output when needed to validate its integration. Choose full `nix flake check` or system builds when the affected scope requires them, rather than for every edit.
- Prefer `--no-link` for temporary builds unless a result link is needed. Use output names from the actual declarations. Build and activation are separate actions.
- If a check cannot run, state why, what evidence was obtained instead and what remains unverified.

Completion follows the requested scope, not GitHub state. Record the local commit, validation and relevant risks or rollback. Report unperformed real-machine validation explicitly; when it is part of the requested outcome, keep that part pending until performed. Ordinary local maintenance does not depend on a PR being merged or an Issue being closed.

## 9. Supporting documents

- For optional Issue/PR coordination: [issue-tracker.md](docs/agents/issue-tracker.md).
- When choosing Issue labels: [triage-labels.md](docs/agents/triage-labels.md).
- When changing domain documents or resolving conflicting sources: [domain.md](docs/agents/domain.md).
- For daily workstation management, drift, private records and selective synchronization: [workstation management](docs/architecture/workstation-management.md).
- For topology and composition: [architecture overview](docs/architecture/overview.md).
- For real-machine operations: the applicable file under `docs/runbooks/`.
