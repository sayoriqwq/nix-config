# Agent Protocol

This file is the **normative instruction set** for AI agents working in this repository. The maintainer-facing Chinese translation is in [`docs/agents/protocol.zh-CN.md`](docs/agents/protocol.zh-CN.md). If the two versions differ, this file controls; report and fix the translation mismatch in the same pull request.

## 1. Mission

Build and maintain one auditable, reproducible Nix configuration repository for:

- one macOS workstation managed by `nix-darwin`;
- one NixOS workstation;
- one Ubuntu server during transition, then a NixOS server;
- a portable user environment managed by Home Manager.

The repository manages **configuration**, not mutable application data or backups.

## 2. Required reading order

Before changing files, read:

1. this `AGENTS.md`;
2. the current GitHub issue, including comments and approval gates;
3. [`CONTEXT.md`](CONTEXT.md);
4. the relevant files under `docs/architecture/`;
5. every applicable ADR under `docs/adr/`;
6. the current phase in `docs/plans/migration-roadmap.md`.

If no implementation issue exists, do not start implementation. Limit work to inspection, planning, or creating a properly scoped issue.

## 3. Language policy

- Normative agent constraints are written in English for precision.
- Maintainer-facing documentation, issue bodies, pull-request descriptions, validation reports, and operational instructions must be written in Chinese.
- Code identifiers and ordinary code comments should be English unless Chinese materially improves maintainability.
- Any change to normative rules in this file must update `docs/agents/protocol.zh-CN.md` in the same pull request.

## 4. Work model

- Implement exactly one migration phase or one narrowly scoped maintenance issue per pull request.
- Use a dedicated branch. For planned phases, prefer `agent/phase-<number>-<short-name>`.
- Open a **draft pull request** by default.
- Never push implementation changes directly to `main`.
- Never merge, enable auto-merge, or mark a draft ready without explicit maintainer approval.
- Do not begin the next phase until the current phase's completion criteria and human validation are recorded.
- Do not perform unrelated cleanup, dependency upgrades, renames, or framework migrations.
- Respect the issue's “allowed changes” and “forbidden changes” sections literally.
- When a machine fact is unknown, gather evidence or leave a documented placeholder. Never guess usernames, architecture, hostnames, disks, boot mode, interfaces, `stateVersion`, service inventory, or network settings.

## 5. Architecture invariants

- Use one top-level Flake as the source of truth.
- Use Home Manager for the portable user layer.
- Use `nix-darwin` for macOS system configuration.
- Use NixOS modules for NixOS system configuration.
- Use standalone Home Manager on Ubuntu only as a transition mechanism.
- Keep host and hardware facts under `hosts/<host>/`.
- Keep reusable macOS system modules under `modules/darwin/`.
- Keep reusable NixOS system modules under `modules/nixos/`.
- Keep reusable user modules under `modules/home/`.
- `modules/home/common.nix` must remain platform-neutral and suitable for headless hosts.
- Desktop-only, Darwin-only, Linux-only, and server-only user configuration must remain in separate modules.
- Prefer existing Home Manager, NixOS, and nix-darwin options over custom activation scripts or generated shell code.
- Put project-specific development dependencies in each project's dev shell, not in the global user profile.
- Git synchronizes declarations. Mutable data, databases, browser profiles, service state, and backups require separate data-management procedures.

See `docs/architecture/module-boundaries.md` for path-level rules.

## 6. Safety rules

The following actions are forbidden without an explicit, current human approval recorded in the issue or pull request:

- activating a macOS, NixOS, or Home Manager configuration on a real machine;
- changing bootloader, partition, filesystem, encryption, mount, remote network, DNS, firewall, or SSH-access configuration;
- running `disko`, `nixos-anywhere`, formatting commands, destructive migrations, or production restore commands;
- rebooting, shutting down, or replacing a remote server;
- migrating or deleting production data.

Additional hard rules:

- Never commit plaintext secrets, tokens, passwords, private keys, recovery codes, decrypted SOPS output, or private `.env` files.
- Never change an existing `system.stateVersion` or `home.stateVersion` merely to match the current release.
- Never edit generated hardware configuration without evidence from the target machine and explicit issue scope.
- Never weaken SSH access or firewall safety to make a deployment easier.
- Never introduce `flake-parts`, Blueprint, Clan, deploy-rs, Colmena, impermanence, ZFS, LUKS, or another major framework/storage design without a dedicated issue and accepted ADR.
- Never run remote installation or destructive commands as part of unattended agent work.

## 7. Evidence and inventory

Before writing host-specific configuration, collect the evidence listed in `docs/runbooks/host-inventory.md`.

- Record only non-secret facts required for reproducibility.
- Redact public IPs, account identifiers, tokens, serial numbers, private hostnames, and other sensitive values unless the maintainer explicitly approves storing them.
- Preserve original NixOS `hardware-configuration.nix`, boot configuration, and state-version values during adoption.
- For server work, document backup location, restore test, rescue-console availability, target disk, boot mode, network model, and SSH recovery path before any destructive step.

## 8. Validation contract

Run the narrowest relevant checks and report exact commands and results.

### Documentation-only changes

- Review links, headings, terminology, and agreement between English normative rules and Chinese documentation.
- Do not claim Nix evaluation passed when no Nix implementation exists.

### Flake or Nix changes

When available and relevant:

```bash
nix fmt -- --check .
nix flake check
```

Build the affected output without activating it:

```bash
# macOS
nix build .#darwinConfigurations.<host>.system

# NixOS
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# standalone Home Manager
nix build .#homeConfigurations."<user>@<host>".activationPackage
```

Use the actual output names defined by the issue. A build is not permission to activate it.

If a check cannot run, state exactly why, what evidence was obtained instead, and what remains for the maintainer or a machine-local Codex session.

## 9. Pull-request contract

Every pull request must contain a Chinese description with:

- the linked issue and migration phase;
- what changed and why;
- files and hosts affected;
- explicit out-of-scope items;
- validation commands and results;
- risks and rollback procedure;
- manual actions and human approval gates;
- unresolved facts or follow-up issues.

Keep the pull request in draft until the maintainer has reviewed the diff and completed any required real-machine validation.

## 10. Definition of done

A phase is complete only when:

- its issue completion criteria are satisfied;
- required documentation and ADRs are current;
- relevant evaluations/builds pass or blockers are documented;
- required real-machine validation is recorded by the maintainer;
- rollback steps are known;
- the pull request is merged by a human;
- the phase issue is closed with a completion summary.

## 11. Supporting process documents

- Issue workflow: `docs/agents/issue-tracker.md`
- Label vocabulary: `docs/agents/triage-labels.md`
- Domain-document rules: `docs/agents/domain.md`
- Chinese protocol translation: `docs/agents/protocol.zh-CN.md`
- Architecture: `docs/architecture/overview.md`
- Migration plan: `docs/plans/migration-roadmap.md`
