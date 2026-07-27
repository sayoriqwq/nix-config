```markdown
# nix-config Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches you the core development patterns and conventions used in the `nix-config` repository, a TypeScript codebase with a focus on clarity and maintainability. You will learn about file organization, import/export styles, commit message conventions, and testing patterns. While no explicit automation workflows were detected, this guide provides best practices and suggested commands for common tasks.

## Coding Conventions

### File Naming
- Use **kebab-case** for all file names.
  - Example:  
    ```
    user-config.ts
    system-settings.test.ts
    ```

### Import Style
- Use **relative imports** for referencing modules.
  - Example:
    ```typescript
    import { getUserConfig } from './user-config';
    ```

### Export Style
- Use **named exports** for all exported functions, types, or constants.
  - Example:
    ```typescript
    // user-config.ts
    export function getUserConfig() { ... }
    export type UserConfig = { ... };
    ```

### Commit Message Conventions
- Use **Conventional Commits** with the `feat` prefix for new features.
- Commit messages are concise, averaging 52 characters.
  - Example:
    ```
    feat: add user configuration loader
    ```

## Workflows

### Adding a New Feature
**Trigger:** When implementing a new feature or module  
**Command:** `/add-feature`

1. Create a new file using kebab-case (e.g., `new-feature.ts`).
2. Implement your feature using named exports.
3. Use relative imports to include any dependencies.
4. Write a corresponding test file (e.g., `new-feature.test.ts`).
5. Commit your changes using a conventional commit message:
    ```
    feat: describe your new feature
    ```

### Writing and Running Tests
**Trigger:** When validating new or existing functionality  
**Command:** `/run-tests`

1. Create a test file named with the pattern `*.test.ts` (e.g., `user-config.test.ts`).
2. Write your tests using the preferred (unspecified) testing framework.
3. Run your test suite using the project's test runner (consult project docs if needed).

## Testing Patterns

- Test files use the `*.test.ts` naming convention.
- The specific testing framework is not specified; follow existing patterns in the repository.
- Place test files alongside or near the modules they test.

**Example:**
```
user-config.ts
user-config.test.ts
```

## Commands

| Command       | Purpose                                |
|---------------|----------------------------------------|
| /add-feature  | Scaffold and commit a new feature      |
| /run-tests    | Run the project's test suite           |
```
