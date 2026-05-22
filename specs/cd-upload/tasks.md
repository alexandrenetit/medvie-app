# Tasks — `cd-upload`

**Repo:** `medvie-app`
**Spec:** `spec.md` · **Plan:** `plan.md`
**Convenção:** ordem sequencial salvo `[P]` (paralelo na mesma fase). Cada tarefa cita arquivos exatos. Limite CLAUDE.md: máx 3 arquivos por iteração — agrupar tarefas pequenas, dividir as grandes.

---

## Fase 0 — Setup & ADR

- **T001** Criar branch `feat/cd-upload`.
- **T002** Commit das specs (`spec.md`, `plan.md`, `tasks.md`, `adr/0001-file-picker-exception.md`, `contracts/api-pin.json`).
- **T003** Aprovar ADR-0001 (`file_picker`) com arquiteto. Mergear antes da Fase 2.

## Fase 1 — Models & Constants

- **T010** `lib/core/models/certificado_metadata.dart`: classe imutável + `fromJson`/`toJson` + computed `diasParaVencer` (UTC). Documentação `// lib/core/models/certificado_metadata.dart` na linha 1.
- **T011** EDIT `lib/core/models/medico.dart`: adicionar `StatusCertificado.substituido`, `StatusCertificado.removido`, `StatusCertificado.desconhecido`; ajustar `StatusCertificadoExt` (sem fallback silencioso — `desconhecido` é estado explícito).
- **T012** `lib/core/constants/certificado_error_codes.dart`: map `codigo → mensagem PT-BR` + função `traduzir(codigo, fallback)`.
- **T013** Testes: `test/core/models/certificado_metadata_test.dart` (fromJson/toJson round-trip, computed `diasParaVencer`, parsing UTC estrito). `[P]`
- **T014** Testes: `test/core/constants/certificado_error_codes_test.dart` (todos os códigos mapeados, fallback funciona). `[P]`

## Fase 2 — Service layer

- **T020** EDIT `lib/core/services/medvie_api_service.dart`: adicionar `uploadCertificado(cnpjProprioId, Uint8List bytes, String senha, bool restritoAoCnpj)` usando `http.MultipartRequest` com timeout 30 s.
  - Mapear 200/201/202 → `CertificadoMetadata`.
  - Mapear 4xx → `ApiException(ApiError.from(response))`.
  - `finally`: `bytes.fillRange(0, bytes.length, 0)` (best-effort).
  - Nunca logar `bytes` nem `senha`.
- **T021** EDIT `lib/core/services/medvie_api_service.dart`: adicionar `consultarCertificado(cnpjProprioId)` (GET, 404 → `null`).
- **T022** EDIT `lib/core/services/medvie_api_service.dart`: adicionar `removerCertificado(cnpjProprioId)` (DELETE, 204 OK, 409 → exception).
- **T023** Testes: `test/core/services/medvie_api_service_certificado_test.dart` (mockando `http.Client`). Cobre happy path + 422 cada código + idempotência.

## Fase 3 — Provider

- **T030** `lib/core/providers/certificado_provider.dart`:
  - Sealed class `CertificadoState` = `Idle | Uploading | Success(metadata) | Error(codigo, mensagem)`.
  - Métodos `carregar(cnpjId)`, `enviar(cnpjId, bytes, senha, restrito)`, `remover(cnpjId)`.
  - Assina stream SSE `certificado_alerta` no `enable(sse)` e propaga.
  - Sem dependência de outros providers.
- **T031** EDIT `lib/main.dart`: registrar `ChangeNotifierProvider(create: (_) => CertificadoProvider(api))` no `MultiProvider`.
- **T032** Testes: `test/core/providers/certificado_provider_test.dart` (mockando `MedvieApiService`). Cobre transições de estado, idempotência, propagação de erro com código.

## Fase 4 — SSE

- **T040** EDIT `lib/core/services/sse_service.dart`: adicionar tipo `certificado_alerta` no enum/parse; expor `Stream<CertificadoAlerta>`.
- **T041** Modelo `lib/core/models/certificado_alerta.dart` (`cnpjProprioId`, `diasRestantes`, `recebidoEm`).
- **T042** EDIT `lib/core/providers/certificado_provider.dart`: subscribe + recarrega metadados ao receber.
- **T043** Testes: `test/core/services/sse_service_certificado_test.dart`.

## Fase 5 — Widgets de apoio

- **T050** `lib/features/certificado/widgets/senha_field.dart`: `TextField` `obscureText`, autofill off, ícone toggle.
- **T051** `lib/features/certificado/widgets/arquivo_picker_tile.dart`: tile que abre `file_picker` restrito a `pfx,p12`, mostra nome + tamanho.
- **T052** `lib/features/certificado/widgets/certificado_status_card.dart`: card com semáforo de validade (30/7/0 dias) usando `app_colors`.

## Fase 6 — Telas

- **T060** `lib/features/certificado/screens/certificado_upload_screen.dart`:
  - StatefulWidget.
  - Aplica proteção screenshot (FLAG_SECURE / iOS capture overlay).
  - Form: `ArquivoPickerTile` + `SenhaField` + `SwitchListTile(restritoAoCnpj)` + botão "Anexar".
  - Estado consumido via `Selector<CertificadoProvider, CertificadoState>`.
  - Erros traduzidos via `certificado_error_codes`.
  - Cleanup de bytes/controllers no `dispose`.
- **T061** `lib/features/certificado/screens/certificado_detalhe_screen.dart`: read-only metadados + botões "Atualizar" e "Remover" (confirmação destrutiva).
- **T062** Testes widget: `test/features/certificado/screens/certificado_upload_screen_test.dart` (renderiza estados, dispara provider, exibe erro traduzido).

## Fase 7 — Integração onboarding

- **T070** EDIT `lib/core/providers/onboarding_provider.dart`:
  - Carregar status do certificado ao entrar em step 2b (chamar `CertificadoProvider.carregar`).
  - Expor `bool podeAvancarStep2b` computado.
- **T071** EDIT `lib/features/onboarding/screens/step2b_assinatura_screen.dart`:
  - CTA "Próximo" desabilitado se `!podeAvancarStep2b` e método = A1.
  - Botão "Anexar certificado A1" abre `CertificadoUploadScreen` em modo onboarding.
- **T072** Testes widget: `test/features/onboarding/step2b_certificado_gate_test.dart`.

## Fase 8 — SyncView

- **T080** EDIT `lib/features/syncview/syncview_screen.dart`: inserir `CertificadoStatusCard` no topo.
- **T081** Teste widget: `test/features/syncview/certificado_card_test.dart`.

## Fase 9 — Proteção screenshot

- **T090** Avaliar via spike `flutter_windowmanager` vs platform channel raso. Decidir e documentar no PR.
- **T091** Implementar `enableSecure()` / `disableSecure()` chamados em `initState`/`dispose` das telas sensíveis.

## Fase 10 — Quality gates & smoke

- **T100** `dart analyze` — zero issues.
- **T101** `flutter test` — 0 failed.
- **T102** `./run_dcm.sh` — zero issues.
- **T103** `flutter build apk --debug` — verde.
- **T104** Smoke manual: dispositivo Android real + backend staging. Roteiro:
  1. Login → onboarding step 2b.
  2. Anexar PFX válido → libera próximo step.
  3. Anexar PFX com senha errada → ver mensagem traduzida.
  4. Anexar mesmo PFX → toast idempotência.
  5. Remover certificado → emissão bloqueada.

## Fase 11 — Documentação

- **T110** Atualizar `README.md` do app com seção "Certificado Digital A1".
- **T111** Atualizar `pubspec.yaml` com `file_picker` (versão fixa após avaliação) + `flutter_windowmanager` ou alternativa.
- **T112** Atualizar `MEMORY.md` (se aplicável) com nova regra: "PFX/senha jamais em SharedPreferences/FlutterSecureStorage".

---

## Matriz de Dependências

| Fase | Depende de |
|---|---|
| 1 Models | 0 |
| 2 Service | 1 |
| 3 Provider | 2 |
| 4 SSE | 3 |
| 5 Widgets apoio | 1 |
| 6 Telas | 3, 5 |
| 7 Onboarding | 3, 6 |
| 8 SyncView | 3, 5 |
| 9 Screenshot guard | 6 |
| 10 Quality gates | tudo |
| 11 Docs | 10 |

## Marcadores

- `[P]` = paralelo dentro da mesma fase.
- Limite CLAUDE.md: máx 3 arquivos por iteração — não agrupar tarefas além disso.
