# ADR-0002: Estratégia de bloqueio de screenshot

## Contexto
- Telas `CertificadoUploadScreen` + `CertificadoDetalheScreen` exibem metadados sensíveis (CNPJ, validade, holder).
- PFX nunca toca disco, mas screenshot expõe senha digitada + metadados.
- CLAUDE.md regra: apenas pacotes Google/Flutter; terceiros só com exceção ADR.

## Opções avaliadas

### A) `flutter_windowmanager` (pub.dev)
Prós:
- API Dart pronta (`addFlags` / `clearFlags`).
- ~3 linhas de integração por tela.

Contras:
- Pacote comunidade (último release estagnado > 12 meses, autor único).
- Cobre SOMENTE Android (`FLAG_SECURE` é Android-only).
- Adiciona 2ª exceção à regra Google/Flutter (já temos ADR-0001 `file_picker`).
- Risco de bitrot Gradle/AGP futuro.
- Vendor lock-in sem benefício.

### B) Platform channel próprio
Prós:
- Zero dependência externa, alinha CLAUDE.md.
- Cobre Android + iOS (overlay opaco em `didEnterBackground`).
- Total controle visual (cor brand `AppColors.bg`, sem flash branco iOS).
- APIs nativas estáveis (`FLAG_SECURE` desde Android 1.0; `UIApplicationDidEnterBackgroundNotification` desde iOS 4).
- ~10 linhas Kotlin + ~30 linhas Swift + Dart wrapper enxuto.

Contras:
- 2 sub-iters (Android + iOS) por limite 3 arquivos/iter.
- Manutenção nativa interna (mas API estável → custo ~zero).

## Decisão
**Opção B.** `MethodChannel` `medvie/screenshot_guard` com métodos `enable` / `disable`.

## Consequências
Positivas:
- Sem nova dependência.
- Paridade Android/iOS.
- Sem dívida ADR-exceção adicional.

Negativas:
- Edits em `MainActivity.kt` e `AppDelegate.swift` (única vez).
- Cobertura iOS via overlay app-switcher (não bloqueia print em foreground iOS — limitação de plataforma, não há API pública iOS para bloquear).

## Plano de implementação (T091 — quebrado por limite 3 arquivos)

### S6.P2a (Dart + Android) — 3 arquivos
1. **NOVO** `lib/core/platform/screenshot_guard.dart`
   - `class ScreenshotGuard`
   - `static const _ch = MethodChannel('medvie/screenshot_guard')`
   - `static Future<void> enable() => _ch.invokeMethod('enable')`
   - `static Future<void> disable() => _ch.invokeMethod('disable')`
2. **EDIT** `android/app/src/main/kotlin/.../MainActivity.kt`
   - `configureFlutterEngine`: `MethodChannel` handler.
   - `'enable'` → `window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)`.
   - `'disable'` → `window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)`.
3. **EDIT** `lib/features/certificado/screens/certificado_upload_screen.dart`
   - `initState`: `ScreenshotGuard.enable()` (fire-and-forget).
   - `dispose`: `ScreenshotGuard.disable()` (fire-and-forget) — antes de `super.dispose()`.

### S6.P2b (iOS + 2ª tela) — 3 arquivos
1. **EDIT** `ios/Runner/AppDelegate.swift`
   - Registrar `MethodChannel` `medvie/screenshot_guard`.
   - `'enable'` → flag interna `= true`; instala observer `applicationDidEnterBackground` → overlay `UIView` fundo `AppColors.bg`.
   - `'disable'` → flag `= false`; remove observer + overlay.
   - `applicationWillEnterForeground` → remove overlay se ativo.
2. **NOVO** `ios/Runner/PrivacyOverlay.swift` (helper para construir overlay).
3. **EDIT** `lib/features/certificado/screens/certificado_detalhe_screen.dart`
   - `initState` / `dispose`: idem upload screen.

## Validação por sub-iter
- `dart analyze` — zero issues.
- `flutter test` — 0 failed.
- Smoke Android: tentar print real → bloqueado; vídeo screen mirror também.
- Smoke iOS: app → background → preview app-switcher mostra overlay opaco.

## Referências
- ADR-0001 (`file_picker` — exceção pacote comunidade).
- `specs/cd-upload/tasks.md` T090–T091.
