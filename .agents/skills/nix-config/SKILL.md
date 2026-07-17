```markdown
# nix-config Development Patterns

> Auto-generated skill from repository analysis

## Overview

This skill teaches the core development patterns, coding conventions, and collaborative workflows used in the `nix-config` repository. The project is written in TypeScript, with a strong emphasis on clear documentation, architectural decision tracking, and standardized project processes. While no specific framework is detected, the repository emphasizes maintainability and clarity through consistent code style and documentation practices.

## Coding Conventions

- **File Naming:**  
  Use **kebab-case** for all file names.  
  _Example:_  
  ```
  user-profile.ts
  config-manager.test.ts
  ```

- **Import Style:**  
  Use **relative imports** for referencing modules within the project.  
  _Example:_  
  ```typescript
  import { getConfig } from './config-manager';
  ```

- **Export Style:**  
  Use **named exports** for all modules.  
  _Example:_  
  ```typescript
  // config-manager.ts
  export function getConfig() { ... }
  export function setConfig() { ... }
  ```

- **Commit Messages:**  
  Follow **conventional commit** style, with prefixes like `docs:`.  
  _Example:_  
  ```
  docs: update architecture overview
  ```

## Workflows

### Add Architecture Decision Record
**Trigger:** When someone wants to document a significant architectural or design decision.  
**Command:** `/new-adr`

1. Create a new markdown file in `docs/adr/` with a sequential number and descriptive name.  
   _Example:_  
   ```
   docs/adr/003-use-typescript.md
   ```
2. Write the ADR content explaining the context, decision, and consequences.
3. Commit the new ADR file with a descriptive commit message.  
   _Example:_  
   ```
   docs: add ADR for TypeScript adoption
   ```

---

### Add or Update Domain Documentation
**Trigger:** When someone wants to define, update, or translate domain-specific documentation.  
**Command:** `/update-domain-docs`

1. Create or update a markdown file in one of:
   - `docs/agents/`
   - `docs/architecture/`
   - `CONTEXT.md`
   - `AGENTS.md`
2. Write or revise the documentation content.
3. Commit the changes with a descriptive message.  
   _Example:_  
   ```
   docs: update agent protocol documentation
   ```

---

### Add Project Workflow or Template
**Trigger:** When someone wants to formalize or update project workflows, templates, or operational runbooks.  
**Command:** `/add-template`

1. Create or update a markdown file in one of:
   - `.github/ISSUE_TEMPLATE/`
   - `.github/PULL_REQUEST_TEMPLATE.md`
   - `docs/runbooks/`
2. Write or revise the template or runbook content.
3. Commit the changes with a descriptive message.  
   _Example:_  
   ```
   docs: add runbook for deployment process
   ```

## Testing Patterns

- **Test File Naming:**  
  Test files use the pattern `*.test.*`.  
  _Example:_  
  ```
  config-manager.test.ts
  ```

- **Testing Framework:**  
  The specific testing framework is not detected, but tests are colocated with source files and follow standard TypeScript testing conventions.

- **Test Example:**  
  ```typescript
  // config-manager.test.ts
  import { getConfig } from './config-manager';

  describe('getConfig', () => {
    it('returns default config', () => {
      expect(getConfig()).toEqual({ ... });
    });
  });
  ```

## Commands

| Command             | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| /new-adr            | Create a new Architecture Decision Record                      |
| /update-domain-docs | Add or update domain-specific documentation                    |
| /add-template       | Add or update workflow templates or operational runbooks       |
```
