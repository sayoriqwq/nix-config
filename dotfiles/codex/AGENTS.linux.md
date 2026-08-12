@/home/sayori/.codex/RTK.md

# Shell

- This NixOS workstation is managed by NixOS and Home Manager. Run shell commands through `/etc/profiles/per-user/sayori/bin/fish -lc '<command>'`; its login environment is the source of truth for `PATH` and command availability.
- When Python is needed outside a project-specific environment, use `/etc/profiles/per-user/sayori/bin/python`.
- Use Fish syntax by default for commands shown to the user. Use another shell only when the task specifically requires it.
- After each command or command block that the user should run, add a one-line description formatted as `<emoji> <brief description>`, using exactly one relevant emoji.
