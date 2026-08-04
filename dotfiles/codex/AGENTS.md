@/Users/sayori/.codex/RTK.md

# Nix-managed workstation

- This macOS workstation is managed declaratively with nix-darwin and Home Manager. The source of truth is `/Users/sayori/Desktop/nix-config`.
- This installed file is managed from `/Users/sayori/Desktop/nix-config/dotfiles/codex/AGENTS.md`. Do not edit `~/.codex/AGENTS.md` directly; change the tracked source through the repository workflow.
- Treat the active Nix generation and the Nix-managed Fish login environment as authoritative for durable workstation tools, command resolution, and stable configuration.
- Never hard-code a hashed `/nix/store/...` derivation path. Use stable profile commands, evaluate the declaration, or resolve the active command from Fish.
- Before changing workstation tooling, read the nix-config repository's `AGENTS.md`, current issue, ownership documentation, and relevant capability module. Preserve its human activation gates.

# Python

- The Nix/Home Manager agent baseline provides `python` at `/etc/profiles/per-user/sayori/bin/python`; `python3` is available from the same profile. Prefer these entries over `/usr/bin/python3` outside a project environment.
- The selected baseline is currently Python 3.14 and is declared by `modules/home/common/cli/agent-python.nix`. Upgrade it through nix-config instead of replacing it imperatively.
- The baseline intentionally has no global `pip` or third-party packages. Do not bootstrap or mutate it with `ensurepip`, `pip install`, `pip install --user`, or `pipx`.
- uv owns project Python selection, virtual environments, dependencies, and lock files. Respect `.python-version`, `requires-python`, `pyproject.toml`, and `uv.lock`; use `uv run`, `uv sync`, or a project dev shell as appropriate.

# Tool ownership and synchronization

- Classify every missing tool before installing it:
  - Project-only dependencies belong in that project's flake/dev shell, package manifest, and lock file.
  - Persistent user-global CLI tools default to a declaration in the appropriate nix-config capability and must be validated, committed, pushed, and reviewed through a dedicated issue and pull request.
  - Temporary one-off tools may use `nix shell`, `nix run`, `uvx`, or `uv run --with` without creating a persistent global installation; normal tool caches may still remain mutable and external.
- Existing ownership remains authoritative: Nix/Home Manager owns the declared durable workstation CLI packages and the agent Python baseline; uv owns project Python environments and dependencies; mise owns Node, Bun, and pnpm runtime selection; approved Homebrew or external owners remain explicit in nix-config inventory.
- Do not create durable, unsynchronized global installations with `nix profile install`, `brew install`, `npm install -g`, `pnpm add -g`, `cargo install`, `pip install --user`, or `pipx`. If an approved external owner is genuinely required, record that ownership in nix-config instead of silently installing it.
- When a user asks to install or upgrade a persistent workstation tool, update and synchronize its declaration in nix-config, including relevant ownership documentation and checks. Building a configuration does not activate it.
- Never run nix-darwin, Home Manager, or NixOS activation commands on the user's behalf. Prepare and verify the change, then give the maintainer the short activation command after explicit review and approval.

# Shell

- Always execute shell commands through the user's Nix-managed Fish login shell: `/etc/profiles/per-user/sayori/bin/fish -lc '<command>'`.
- Treat Fish configuration as the source of truth for `PATH`, aliases, functions, and environment initialization.
- Apply the RTK rules inside Fish. For example: `/etc/profiles/per-user/sayori/bin/fish -lc 'rtk git status'`.
- Do not invoke `zsh`, `bash`, or `sh` for ordinary commands unless Fish is unavailable or the task specifically requires another shell.
