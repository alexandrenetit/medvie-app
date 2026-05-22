# Implementation Plan — `cd-upload`

**Repo:** `medvie-app`
**Spec:** `specs/cd-upload/spec.md`
**Contrato:** `medvie-api/specs/cd-provisionamento/contracts/certificado.openapi.yaml` (commit-pinned)
**Constitutional check:** ✅ (ver §7)

---

## 1. Stack

- **Flutter** (Dart 3.11.1, null safety)
- **Provider 6.1.2** (ChangeNotifier) — sem Riverpod/Bloc/GetX
- **http 1.6.0** (já no projeto) — `MultipartRequest`
- **Pacote novo:** `file_picker` (justificativa em ADR-0001)
- **flutter_secure_storage** — **proibido** para senha/PFX
- **Testes:** `flutter_test` + `mocktail` (já no projeto)
- Toolchain de validação obrigatório: `dart analyze` · `flutter test` · `./run_dcm.sh`

---

## 2. Estrutura Detalhada

```
lib/features/certificado/
  screens/
    certificado_upload_screen.dart
      - StatefulWidget
      - Bloqueia screenshot (FLAG_SECURE / isCaptureProtected)
      - Form: ArquivoPickerTile + SenhaField + SwitchListTile(restritoAoCnpj) + Botão "Anexar"
      - Loading state + ErrorBanner
    certificado_detalhe_screen.dart
      - Read-only view dos metadados
      - Botão "Atualizar" + Botão destrutivo "Remover"
  widgets/
    certificado_status_card.dart
      - Mostra dias para vencer (cores semânticas)
      - Tap → abre detalhe
    senha_field.dart
      - TextField obscureText, eye toggle, sem autofill, sem sugestão
    arquivo_picker_tile.dart
      - Tile que abre file_picker; mostra nome + tamanho

lib/core/providers/certificado_provider.dart
  - ChangeNotifier
  - Estados via sealed class: Idle | Uploading | Success(CertificadoMetadata) | Error(codigo, mensagem)
  - Métodos: carregar(cnpjId), enviar(cnpjId, bytes, senha, restrito), remover(cnpjId)
  - Sem dependência de NotaFiscalProvider, OnboardingProvider (passar dados via construtor/método)

lib/core/models/certificado_metadata.dart
  - Imutável + fromJson/toJson explícitos
  - DateTime UTC com parser estrito (FormatException → erro descritivo)
  - Computed: diasParaVencer (UTC)

lib/core/services/medvie_api_service.dart
  - uploadCertificado(cnpjProprioId, Uint8List bytes, String senha, bool restritoAoCnpj)
    - MultipartRequest POST
    - Timeout 30 s
    - Mapeia 200/201/202 → CertificadoMetadata; outros → ApiException
    - finally: bytes.fillRange(0, bytes.length, 0)  // best-effort zeroing
  - consultarCertificado(cnpjProprioId) → CertificadoMetadata | null (404)
  - removerCertificado(cnpjProprioId) → void

lib/core/services/sse_service.dart  (EDIT)
  - Evento certificado_alerta: { cnpjProprioId, diasRestantes }
  - Propaga via novo Stream<CertificadoAlerta> em CertificadoProvider (subscribe na startup)

lib/core/constants/certificado_error_codes.dart
  - const map: { 'Certificado.SenhaInvalida': 'Senha incorreta. Verifique e tente novamente.', ... }
  - Função traduzir(String code, String fallback)
```

---

## 3. Decisões Arquiteturais (App-side)

### 3.1 Sem persistência local de PFX/senha
- Bytes do PFX existem somente como `Uint8List` na pilha da função de upload.
- Após `await client.send(req)`, executar `bytes.fillRange(0, bytes.length, 0)` (best-effort no GC do Dart; não há `SecureString`).
- Senha vive em `TextEditingController.text` enquanto a tela está montada; `controller.dispose()` no `dispose()`.

### 3.2 Bloqueio de screenshot
- Android: `WindowManager.LayoutParams.FLAG_SECURE` via platform channel ou `flutter_windowmanager` (alternativa: pacote oficial-equivalente; decidir no spike de T040).
- iOS: `UIScreen.isCaptured` listener + overlay de blur ao detectar captura.
- Aplicar apenas em `CertificadoUploadScreen` e `CertificadoDetalheScreen`.

### 3.3 Bloqueio de onboarding
- `OnboardingProvider` ganha computed `bool podeAvancarStep2b` que considera:
  - `metodoAssinaturaAtual == MetodoAssinatura.certificadoA1` ⇒ exige `StatusCertificado.ativo`
  - Para outros métodos atuais (não há), permite.
- `Step2bAssinaturaScreen` ouve o provider; CTA "Próximo" disabled enquanto false.

### 3.4 Provider isolado
- `CertificadoProvider` recebe `MedvieApiService` no construtor (igual aos demais providers).
- **NÃO** depende de `NotaFiscalProvider` nem `DashboardProvider` (corrige tech debt mapeado).
- Disponibilizado em `lib/main.dart` via `ChangeNotifierProxyProvider` se precisar reagir a logout.

### 3.5 Tradução de erros
- `certificado_error_codes.dart` é fonte única.
- Snackbars, banners, dialogs sempre via `traduzir(code, fallbackGenerico)`.
- Fallback genérico: "Não foi possível processar seu certificado. Tente novamente."
- **Nunca** exibir `response.body` cru.

### 3.6 SSE
- Evento novo `certificado_alerta` adicionado em `SseEventType`.
- Stream dedicado consumido por `CertificadoProvider`.
- Notificação local: usar pacote já existente (verificar; se não houver, abrir spike menor).

---

## 4. Sequência (Happy Path)

```
Tela CertificadoUploadScreen
  Usuário seleciona PFX (file_picker)
    Result.files.first.bytes → Uint8List
  Usuário digita senha
  Tap "Anexar"
    Provider.enviar(cnpjId, bytes, senha, restrito)
      Service.uploadCertificado(...)
        POST multipart → backend
        201/200 → CertificadoMetadata
      Provider.state = Success(metadata)
      finally: zero bytes
    Tela ouve provider:
      Success → SnackBar verde + Navigator.pop(true)
      Error(codigo) → ErrorBanner com traduzir(codigo)
OnboardingProvider.refreshStep2b() → libera próximo
```

---

## 5. Constitutional Check

| Princípio (CLAUDE.md) | Aderência |
|---|---|
| State manager Provider | ✅ ChangeNotifier puro |
| `SharedPreferences` só JWT/UI prefs | ✅ Nenhum dado de cert vai pra prefs |
| Backend = fonte única | ✅ Provider lê do backend; sem mock local de status |
| Sem chamada externa direta | ✅ Tudo via `MedvieApiService` |
| Sem hardcode | ✅ Cores via `app_colors`, strings via constants |
| Apenas pacotes oficiais | ⚠️ ADR-0001 aprova exceção para `file_picker` |
| Dark theme | ✅ Tela usa `app_theme` |
| Validar `mounted` pós-`await` | ✅ Reforçar em todos os `setState` após upload |
| Sem lógica de negócio em widget | ✅ Tudo no Provider/Service |
| `const` onde possível | ✅ Widgets imutáveis |
| `ListView.builder` para listas longas | N/A (sem listas longas aqui) |
| Serialização explícita | ✅ `CertificadoMetadata.fromJson`/`toJson` |

---

## 6. Validação Final (Quality Gates do CLAUDE.md)

1. ✅ `dart analyze` — zero issues.
2. ✅ `flutter test` — 0 failed.
3. ✅ `./run_dcm.sh` em `/mnt/c/Projects/medvie/medvie-app` (WSL Ubuntu) — zero issues.
4. ✅ `flutter build apk --debug` ao final.

---

## 7. Plano de Rollout

1. **Fase A — Estrutura sem `file_picker`** (mock de bytes via arquivo de teste fixo): permite paralelo com aprovação de ADR.
2. **Fase B — Integração `file_picker` + tela de upload completa**: após ADR aprovada.
3. **Fase C — Integração SSE + status card + bloqueio onboarding**: depende de eventos do backend (Fase A do backend já cobre).
4. **Fase D — FLAG_SECURE / proteção screenshot**: pode entrar como hotfix antes do release público.

---

## 8. Riscos Específicos

| # | Risco | Mitigação |
|---|---|---|
| RT-01 | `file_picker` em web/desktop tem APIs diferentes; foco é mobile | Limitar suporte a Android+iOS por enquanto; assert em platform |
| RT-02 | Spec do backend muda payload | OpenAPI fragment commit-pinned + revisão obrigatória de PR |
| RT-03 | `flutter_windowmanager` não-oficial | Avaliar alternativa via platform channel raso direto no spike de T040 |
| RT-04 | Senha em logs por erro de catch | Test ensures `error.toString()` chamado em SnackBar nunca contém substring da senha digitada |

---

## 9. Definition of Done

- ✅ Todas tarefas em `tasks.md` concluídas.
- ✅ Quality gates §6 verdes.
- ✅ Snapshot de teste do `CertificadoMetadata.fromJson` bate com fixtures do backend.
- ✅ Smoke manual em Android real contra `staging.medvie.com.br`.
- ✅ ADR-0001 mergeada antes de adicionar dependência `file_picker`.
- ✅ `pubspec.yaml` atualizado e `flutter pub get` verde.
