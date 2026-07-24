# CLAUDE.md — medvie-app (Flutter)

### Session start
Always start the session by configuring:
- caveman ultra

## Execution policy (autonomous by default)
- **Run WSL/shell commands without asking.** No confirmation gate before executing commands or edits. Do not wait for a "go ahead" — act.
- **Interrupt ONLY when:**
  1. There is a real trade-off or architectural decision that changes direction (e.g. switching state manager, breaking the backend contract, deleting working code with unclear impact, adding a dependency).
  2. The prompt explicitly asks you to stop and confirm.
- No "waiting for approval" between steps. Chain exploration → edit → validation in one flow.
- Before an edit, state the intent in 1–2 lines inline (what / files / main risk), then proceed. This is a note, not a blocking gate.
- Report the outcome faithfully: if tests fail, say so; if a step was skipped, say so.

## Context
Flutter client for Medvie — SaaS for tax automation for self-employed (PJ) doctors. The .NET backend is the single source of truth. Flutter only renders. The product is production-final from the first commit — never treat it as an MVP.

## Stack
- Flutter / Dart (null safety)
- State management: **Provider** — no Riverpod, no Bloc, no GetX
- `SharedPreferences` only for JWT and UI preferences. NEVER for business data.
- API client in `lib/core/services/medvie_api_service.dart`

## Architecture
- Layers: UI (`features/*/screens`) → Provider (`core/providers`) → Service (`core/services`) → .NET API
- No business logic in widgets. No HTTP calls in widgets.
- No global singleton without a clear architectural need.
- Active structure: `lib/features/<feature>/screens/`. The `steps/` folder is legacy — ignore it.

## Non-negotiable rules
- **Backend = single source of truth.** Login → backend. SharedPreferences is never the source of truth for doctor, CNPJs, or onboarding state.
- **No direct external calls from Flutter.** IBGE, BrasilAPI, ViaCEP, CNPJ → always via the .NET backend.
- **No hardcoding** of URL, token, color, dimension, business copy, or tax rule.
- **Only official Google/Flutter packages.** Third-party only with 100% certainty and justification.
- **`sed -i` forbidden** — use `str_replace`.
- No temporary solutions. All code is production-final.
- Files are always delivered complete, with the path on line 1: `// lib/features/...`

## Business rules with code impact
- Enum `PerfilAtuacao`: `MédicoClínico`, `ProcedimentalistaAmbulatorial`, `PlantonistaHospitalar`, `CirurgiãoHospitalar`.
- Step 3 (Tomadores) only appears for `PlantonistaHospitalar`.
- Onboarding restoration: `onboarding_completo=true` → SyncView; `false` → `PageController` at index = `onboarding_step`.
- `NotaFiscal.versao` is a getter computed from `updatedAt` via .NET-compatible UTC Ticks: `_ticksAt1970 + utc.microsecondsSinceEpoch * 10`.
- `StatusNota`: compared by string literal matching the backend contract — not a local enum.
- Município: display `municipio_nome`, never the raw IBGE code.

## Design system (dark theme required)
- Background `#07090F` · Surface `#111827` · Brand `#00C98A` · Secondary `#0EA5E9`
- Text: `#FFFFFF` / `#CBD5E1` / `#94A3B8`
- Fonts: **Outfit** (UI) · **JetBrains Mono** (monetary values)
- Always via `core/constants/app_colors.dart` and `core/theme/app_theme.dart`. Never a literal color in a widget.

## Flutter patterns
- `const` wherever possible
- No excessive `setState` in complex screens
- Check `mounted` after any `await` before using `BuildContext`
- Handle loading / success / error / empty
- `ListView.builder` for long lists
- No unnecessary object creation inside `build`
- Serialization: explicit `fromJson`/`toJson`, aligned with the backend contract

## Pre-edit note (non-blocking)
In 2–3 lines, state inline before editing:
1. What you will do
2. Files involved
3. Main risk

Then proceed — do not wait for confirmation (see Execution policy).

## Exploration
1. `find` → structure
2. `grep` → symbol/widget/provider
3. Read ONLY the file for the subtask
4. If scope grows into a real trade-off (e.g. changing architecture or contract) → surface it and decide; otherwise keep going.

Never assume code state. Verify via `cat`/`find`.

## Edit limits
- Surgical. Preserve working code.
- Max 3 files per iteration.
- Do not swap the state manager. Do not swap the architecture.
- Do not remove seemingly unused code without confirming the impact.
- Do not introduce a package without justification.

## Common error resolution
- Import / strange build error: `flutter clean && flutter pub get && flutter run`
- Before claiming a file exists / has content X: `cat` or `find` to confirm.

## Validation
Before finishing:
1. `dart analyze` — zero issues
2. `flutter test` — 0 failed
3. `./run_dcm.sh` in `/mnt/c/Projects/medvie/medvie-app` (WSL Ubuntu) — zero issues
4. `flutter build apk --debug` only at the end of a complete task

A task is only considered done when `dart analyze`, `flutter test`, and `./run_dcm.sh` are 100% clean. Any residual issue = not finished.

Report errors with: command + essential error + file/line + objective suggestion. Never paste the full log.

## Response after execution
1. What changed
2. Files modified
3. How to validate
4. Risks
5. Next step

Confirm with ✅ or report the error with a minimal stack.

## Commits
pt-br, `feat:` prefix. No `Co-Authored-By: Claude`.

## Path
WSL: `/mnt/c/Projects/medvie/medvie-app/`
