```markdown
# nix-config Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the core development patterns and conventions used in the `nix-config` repository, a TypeScript-based project. You'll learn about file naming, import/export styles, commit conventions, and how to write and run tests. The guide also provides suggested commands for common workflows.

## Coding Conventions

### File Naming
- Use **camelCase** for file names.
  - Example: `myModule.ts`, `userSettings.ts`

### Import Style
- Use **relative imports** for referencing other modules.
  - Example:
    ```typescript
    import { myFunction } from './utils';
    ```

### Export Style
- Use **named exports** for functions, classes, or constants.
  - Example:
    ```typescript
    // In utils.ts
    export function myFunction() { /* ... */ }
    export const MY_CONST = 42;

    // In another file
    import { myFunction, MY_CONST } from './utils';
    ```

### Commit Messages
- Follow **conventional commit** format.
- Use the `feat` prefix for new features.
- Keep commit messages concise (average 52 characters).
  - Example:
    ```
    feat: add user authentication module
    ```

## Workflows

### Feature Development
**Trigger:** When adding a new feature  
**Command:** `/feature-development`

1. Create a new TypeScript file using camelCase naming.
2. Implement the feature using named exports.
3. Import dependencies using relative paths.
4. Write a test file following the `*.test.*` pattern.
5. Commit your changes using the `feat:` prefix and a concise description.

### Code Import/Export
**Trigger:** When sharing code between modules  
**Command:** `/import-export`

1. Use relative imports to reference other files.
2. Export functions, constants, or classes using named exports.
3. Import only what you need in each file.

### Commit Workflow
**Trigger:** When committing code changes  
**Command:** `/commit`

1. Write a commit message using the conventional format.
2. Use the `feat` prefix for new features.
3. Keep the message under 52 characters if possible.

## Testing Patterns

- Test files follow the pattern: `*.test.*` (e.g., `userSettings.test.ts`).
- The testing framework is not specified; check project documentation or existing test files for details.
- Place test files alongside the modules they test or in a dedicated `tests` directory.

  Example test file:
  ```typescript
  // userSettings.test.ts
  import { getUserSettings } from './userSettings';

  test('should return default settings', () => {
    expect(getUserSettings()).toEqual({ theme: 'light' });
  });
  ```

## Commands
| Command               | Purpose                                 |
|-----------------------|-----------------------------------------|
| /feature-development  | Start a new feature using conventions   |
| /import-export        | Add or update imports/exports           |
| /commit               | Commit changes with proper conventions  |
```
