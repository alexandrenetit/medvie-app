# medvie-app

Cliente Flutter do Medvie — SaaS de automação fiscal para médicos PJ. Backend .NET é fonte única da verdade; Flutter renderiza estado e dispara mutações.

## Stack
- Flutter / Dart (null safety)
- State management: Provider
- API client: `lib/core/services/medvie_api_service.dart`
- Persistência local: SharedPreferences (somente JWT + preferências UI) + FlutterSecureStorage (somente credenciais)
- Dark theme obrigatório — paleta em `lib/core/constants/app_colors.dart`

## Estrutura
- `lib/core/` — modelos, providers, services, theme, constantes
- `lib/features/<feature>/screens/` — telas por feature
- `lib/features/<feature>/widgets/` — widgets compostos da feature
- `lib/core/platform/` — wrappers de platform channel (ex.: `ScreenshotGuard`)

## Certificado Digital A1
- **Fluxo:** upload PFX/P12 → validação criptográfica no backend → cifra em vault → provisiona NFS-e provider.
- **Contrato consumido:** `specs/cd-upload/contracts/api-pin.json` (commit-pinned `medvie-api`).
- **Endpoints:** `POST/GET/DELETE /api/v1/cnpjs/{id}/certificado`.
- **Telas:** `CertificadoUploadScreen`, `CertificadoDetalheScreen`.
- **Onboarding:** step 2b bloqueia avanço sem certificado ativo quando método = A1 (gate em `OnboardingProvider.podeAvancarStep2b`).
- **SyncView:** `CertificadoStatusCard` no topo exibindo validade com semáforo 30/7/0 dias.
- **SSE:** evento `certificado_alerta` recarrega metadados automaticamente.
- **Segurança:**
  - PFX e senha nunca persistidos local (nem SharedPreferences, nem FlutterSecureStorage).
  - Bytes zerados pós-upload via `fillRange(0, len, 0)`.
  - Senha vive apenas em `TextEditingController`, descartada no `dispose`.
  - Screenshot bloqueado em telas sensíveis: Android via `FLAG_SECURE` (`MainActivity.kt`), iOS via overlay opaco em background (`ScreenshotGuardPlugin.swift`).

## ADRs
- `specs/cd-upload/adr/0001-file-picker-exception.md` — exceção pacote comunidade `file_picker` (justificada, pin `8.3.7`).
- `specs/cd-upload/adr/0002-screenshot-guard.md` — estratégia de bloqueio de screenshot (platform channel próprio, sem dependência externa).

## Comandos
- `flutter pub get` — instalar dependências.
- `flutter run` — executar app.
- `dart analyze` — lint (zero issues obrigatório).
- `flutter test` — suite (`0 failed` obrigatório).
- `./run_dcm.sh` — Dart Code Metrics (zero issues; WSL Ubuntu).
- `flutter build apk --debug` — build Android validador.

## Convenções
- Caminho do arquivo na linha 1 como comentário: `// lib/features/...`.
- Sem hardcode de URL, token, cor, dimensão, texto de negócio.
- Apenas pacotes oficiais Google/Flutter (terceiros só via ADR de exceção).
- Commits pt-BR, prefixo `feat:` / `fix:` / `docs:` / `chore:` / `test:`.
