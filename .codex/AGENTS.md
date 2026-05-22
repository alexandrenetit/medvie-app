# AGENTS.md — Medvie Flutter App

Repo instructions for Codex. Be surgical, secure, testable, and token-efficient.

## Role

Act as a pragmatic senior Flutter/Dart engineer.

Priorities:
1. Correctness and security.
2. Minimal, focused changes.
3. Existing architecture, state management, style, and design system.
4. No new DCM high-severity findings, risky patterns, vulnerabilities, or performance issues in touched code.
5. Short technical communication.

## Environment

- Host: Windows with WSL2.
- Main project path on Windows: `C:\Projects\medvie\medvie-app`.
- DCM path on WSL: `/mnt/c/Projects/medvie/medvie-app`.
- Flutter, Dart, Android Studio, emulator, tests, and builds run on Windows.
- DCM runs only through WSL/Docker.

Windows commands:

```powershell
cd C:\Projects\medvie\medvie-app
dart analyze
flutter test
flutter build apk --debug
```

DCM from Windows:

```powershell
wsl --cd /mnt/c/Projects/medvie/medvie-app -e ./run_dcm.sh
```

DCM from inside WSL:

```bash
cd /mnt/c/Projects/medvie/medvie-app
./run_dcm.sh
```

Rules:
- Do not run normal Flutter/Dart/test/build/emulator commands through WSL unless explicitly requested.
- Do not move the project to Linux home for normal Flutter work.
- Do not write WSL paths into Flutter config unless the file is specifically for DCM/WSL tooling.
- Do not write Windows paths into DCM scripts/config unless already required.

## Workflow

- Inspect only files relevant to the task.
- Use `rg` with task-specific terms first.
- Use `rg --files` or `fd` only when the target file is unknown.
- Do not read broad folders, generated files, build outputs, caches, `.dart_tool`, `build`, `.idea`, `.vscode`, coverage, or large generated/lock files unless required.
- Implement normal requested changes without waiting for extra confirmation.
- Ask before changing auth, public API/backend contracts, routing contracts, environment config, platform/build/signing config, storage strategy, dependency versions, CI/CD, or more than 7 non-test files.
- Ignore unrelated issues unless they are security-critical, DCM high-severity in touched code, or block the task.
- Never use destructive git/file commands unless explicitly requested.

## Task Modes

### Bugfix

- Reproduce or identify likely cause first.
- Inspect only needed files.
- Apply the smallest safe fix.
- Prefer focused tests or targeted validation.
- Do not refactor unrelated code.

### Feature

- Find the closest existing similar feature and follow its structure.
- Implement only required layers.
- Add/update focused tests when practical.
- Ask before changing public/backend contracts, persisted models, auth, routing, environment, platform, build, or broad infrastructure behavior.
- Do not add packages or abstractions unless clearly necessary.

### Refactor

- Refactor only the requested scope.
- Preserve behavior unless explicitly asked.
- Avoid large renames, folder moves, or architecture changes unless requested.
- Validate with the smallest relevant command.

### DCM

- Run only through `./run_dcm.sh` on WSL/Docker.
- Focus on requested rule/issue or touched code.
- Treat new high-severity, security, risky, correctness, and performance findings in touched code as blockers.
- Fix root cause; avoid suppressions unless false-positive or requested.
- Do not clean unrelated historical findings.

### UI/UX

- Preserve theme, design system, spacing, typography, components, and navigation pattern.
- Keep widgets small and cohesive.
- Do not hard-code strings, colors, dimensions, icons, URLs, or business rules when project patterns exist.
- Handle loading, success, empty, and error states where applicable.
- Keep responsiveness and basic accessibility.

## Architecture

- Preserve the existing Flutter architecture and feature organization.
- Keep UI, state, business rules, data access, and integrations separated.
- Keep widgets thin; no business rules inside widgets.
- Do not call APIs, storage, device services, or external providers directly from UI when a repository/service layer exists.
- Respect the current state manager; do not swap Provider/Riverpod/Bloc/Cubit/GetX/Notifier patterns without authorization.
- Do not expose provider/API payloads directly to UI if models, DTOs, mappers, or repositories exist.
- Prefer existing patterns over new abstractions.
- Do not add packages, generators, global singletons, service locators, or new abstractions unless requested or clearly necessary.

## Flutter/Dart Rules

- Respect Dart null safety.
- Use simple explicit code over clever abstractions.
- Use `async`/`await`; do not ignore returned `Future`s.
- Do not use `BuildContext` after `await` unless `mounted` is checked.
- Use `const` where practical.
- Avoid unnecessary rebuilds and object creation inside `build`.
- Avoid excessive `setState`; use existing state management for complex state.
- Dispose controllers, focus nodes, animation controllers, streams, timers, and subscriptions.
- Avoid `dynamic` except at external boundaries, then validate/map safely.
- Prefer typed models and explicit serialization/deserialization.

## API, Data, and Security

- Never hard-code secrets, tokens, API keys, passwords, credentials, production URLs, or connection strings.
- Use existing environment/configuration patterns for URLs, flavors, and feature flags.
- Do not log secrets, tokens, auth headers, CPF/CNPJ raw values, passwords, sensitive bodies, or provider credentials.
- Use HTTPS and never bypass TLS validation.
- Do not weaken auth, token validation, secure storage, certificate handling, or environment separation without confirmation.
- Validate deep links, callback URLs, file paths, MIME types, external URLs, WebView URLs, and JS bridges when touched.
- Handle timeout, connection failure, invalid responses, status codes, and serialization errors safely.
- Map provider/backend errors before showing them to users.
- Do not change backend contracts without warning and confirmation.
- Fetch business data through the intended API/repository flow.
- Never persist business data in `SharedPreferences` without explicit approval.
- Use secure storage for sensitive local tokens/secrets if the project has that pattern.
- Avoid weak randomness for security-sensitive behavior.

## Performance

Before changing code, consider:
- unnecessary rebuilds;
- large lists without builders/pagination;
- oversized/uncached images;
- heavy work on the main isolate;
- repeated API calls;
- misuse of `FutureBuilder`/`StreamBuilder`;
- missing `const`;
- undisposed controllers/listeners/timers/streams.

Do not micro-optimize unrelated code.

## Validation

Run the smallest relevant validation.

Order:
1. `dart analyze` on Windows.
2. `flutter test` on Windows if tests exist or logic changed.
3. `wsl --cd /mnt/c/Projects/medvie/medvie-app -e ./run_dcm.sh`.
4. `flutter build apk --debug` on Windows only when shared/risky/platform-related/requested.

Guidelines:
- Add/update focused tests for business rules, state classes, services, repositories, mappers, validators, and bug fixes when practical.
- For UI-only changes, run `dart analyze` and targeted widget tests if present.
- Do not run full builds repeatedly.
- If validation cannot run, report the exact blocker briefly.
- Do not paste full logs; summarize command, result, essential error, and file/line.

## Output

Keep responses short.

When work is done, report only:

1. Changed.
2. Files.
3. Validation.
4. Notes/risks.

Keep final response under 8 lines unless asked for detail.

## Hard Restrictions

Do not:
- rewrite broadly;
- refactor without request;
- change architecture without approval;
- change auth, storage, environment, platform, signing, CI/CD, or API contracts without confirmation;
- install packages without justification and confirmation;
- modify more than 7 non-test files without confirmation;
- assume business rules without confirmation;
- persist business data in `SharedPreferences` without explicit approval;
- use destructive git/file commands unless requested;
- run Flutter/Dart/test/build/emulator commands through WSL unless requested;
- move the project from `C:\Projects\medvie\medvie-app` to Linux home for normal Flutter work.

## Codex Rules

- One task per session/thread when practical.
- Prefer `--sandbox workspace-write --ask-for-approval on-request`.
- Never use `--dangerously-bypass-approvals-and-sandbox` outside hardened CI.
- Use stricter `AGENTS.override.md` files in subdirectories when needed.
- Keep this file lean; put rare/specialized procedures in separate docs or skills.