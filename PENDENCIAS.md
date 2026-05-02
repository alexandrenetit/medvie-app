# PENDENCIAS.md — Medvie App

> Auditoria técnica completa realizada em 2026-05-01.
> Última atualização: 2026-05-02.
> Cobertura: 100% de `lib/` + `test/` (~6.600 linhas, 48 arquivos Dart).

---

## Legenda

| Símbolo | Significado |
|---------|-------------|
| ✅ | Concluído |
| ⏳ | Pendente |
| 🔴 | Crítico — crash, perda de dados, vulnerabilidade |
| 🟠 | Alto — comportamento errado ou risco de produção |
| 🟡 | Médio — degradação de UX ou manutenibilidade |
| 🟢 | Baixo — qualidade, boas práticas, cosmético |

---

## 🔴 CRÍTICO

| # | Status | Item | Arquivo | Observação |
|---|--------|------|---------|-----------|
| C-01 | ✅ | `?especialidadeId` — falso positivo | `medvie_api_service.dart` | Syntax válida Dart 3.11 (null-aware map entry) |
| C-02 | ✅ | `Future.delayed` sem `mounted` check | `servico_provider.dart` | Flag `_mounted` adicionada |
| C-03 | ✅ | `debugPrint` com dados sensíveis em produção | `medvie_api_service.dart`, `onboarding_provider.dart` | Todos guardados com `if (kDebugMode)` |
| C-04 | ✅ | Refresh token em `SharedPreferences` sem criptografia | `medvie_api_service.dart` | Migrado para `flutter_secure_storage` |
| C-05 | ✅ | Email derivado deterministicamente do CPF | `medvie_api_service.dart` | UUID aleatório gerado no cadastro e persistido |

---

## 🟠 ALTO

| # | Status | Item | Arquivo | Observação |
|---|--------|------|---------|-----------|
| A-01 | ✅ | URLs hardcoded sem config dev/prod | `medvie_api_service.dart` | `--dart-define=API_BASE_URL` e `GOTRUE_URL` com fallback local |
| A-02 | ✅ | N+1 queries no onboarding | `onboarding_provider.dart` | `buscarCnpj` paralelizado com `Future.wait` |
| A-03 | ✅ | Sem timeout HTTP | `medvie_api_service.dart` | `.timeout(10s)` em `_send()` |
| A-04 | ✅ | SSE sem heartbeat | `sse_service.dart` | Watchdog de 45s — reconecta se sem dados |
| A-05 | ✅ | Buffer SSE corrompível | `sse_service.dart` | Parser já estava correto — confirmado sem alteração |
| A-06 | ✅ | God object com 3 fontes de verdade para `medicoId` | `onboarding_provider.dart` | Getter `medicoId` unificado: `medico?.id ?? medicoIdSalvo` |
| A-07 | ✅ | `_skipNext` frágil com concorrência | `dashboard_provider.dart` | Trocado por contador inteiro `_skipCount` |
| A-08 | ✅ | Emissão sem validar `tomadorId` | `servico_provider.dart` | Valida `null` e `isEmpty` antes do POST |
| A-09 | ✅ | Patches `FIX 1..4` frágeis | `onboarding_provider.dart` | FIX 2 refatorado com `Future.wait`; FIX 3 e 4 documentados |

---

## 🟡 MÉDIO

| # | Status | Item | Arquivo | Observação |
|---|--------|------|---------|-----------|
| M-01 | ✅ | `Column` + `.map()` em vez de `ListView.builder` | `servico_list.dart` | Migrado para `ListView.builder` com `shrinkWrap` |
| M-02 | ⏳ | Cobertura de testes ~3% | `test/` | Requer fixtures e mocks — sprint dedicada |
| M-03 | ⏳ | Erros genéricos (`throw Exception(string)`) | `medvie_api_service.dart` | Criar sealed class `ApiFailure` — impacto amplo |
| M-04 | ⏳ | `AgendaScreen` com 1400+ linhas | `agenda_screen.dart` | Extrair `AgendaCalendarWidget`, `PlantaoTile`, `AgendaController` |
| M-05 | ⏳ | `ServicoProvider` acoplado a `NotaFiscalProvider` | `servico_provider.dart` | Desacoplar via `ChangeNotifierProxyProvider` ou stream |
| M-06 | ⏳ | Roteamento complexo em `main.dart` | `main.dart:101-174` | Extrair `AppRouter` ou adotar `go_router` |
| M-07 | ✅ | CPF/CNPJ formatados em 3+ lugares | múltiplos | `lib/core/utils/formatters.dart` com `extension StringFormatters` |
| M-08 | ✅ | Especialidade ID 29 hardcoded | `onboarding_provider.dart` | Constante `_kEspecialidadeOutraId = 29` |
| M-09 | ⏳ | `OnboardingProvider` God Object (1200+ linhas) | `onboarding_provider.dart` | Dividir em `OnboardingFlowState` + `OnboardingService` + orquestrador |
| M-10 | ✅ | Sem paginação em `listarServicos()` | `medvie_api_service.dart`, `servico_list.dart` | Scroll infinito com `carregarMais()` no provider |
| M-11 | ⏳ | `Tomador.id` com default `''` — risco silencioso | `medvie.dart` | Tornar nullable — muitas dependências downstream |
| M-12 | ⏳ | Sem retry com backoff em erros transitórios | `medvie_api_service.dart` | 3 tentativas com delay 1s→2s→4s para 5xx e timeout |

---

## 🟢 BAIXO

| # | Status | Item | Arquivo | Observação |
|---|--------|------|---------|-----------|
| B-01 | ✅ | `flutter_animate` dependência morta | `pubspec.yaml` | Removida |
| B-02 | ⏳ | Dependências desatualizadas | `pubspec.yaml` | Rodar `flutter pub upgrade` e validar breaking changes |
| B-03 | ⏳ | `SyncViewCard` rebuild total em qualquer notificação | `syncview_card.dart` | Usar `Selector<T>` para rebuild granular |
| B-04 | ⏳ | Duração de serviço assume cruzamento de meia-noite | `servico.dart:227` | Adicionar validação explícita no input (fim > início) |
| B-05 | ✅ | DevTools acessível em produção | `app_header.dart` | Botão já estava dentro de `if (kDebugMode)` — confirmado |
| B-06 | ✅ | `widget_test.dart` vazio | `test/widget_test.dart` | Substituído por placeholder `void main() {}` |
| B-07 | ⏳ | Model == DTO (sem separação de camadas) | `lib/core/models/` | Criar camada `dto/` ou `fromApiJson`/`toApiJson` explícitos |
| B-08 | ⏳ | Navegação imperativa espalhada, sem rotas nomeadas | `main.dart` + screens | Adotar `go_router` com guards declarativos |
| B-09 | ✅ | Sem CI/CD | — | `.github/workflows/ci.yml` criado |
| B-10 | ✅ | Sem lints extras | `analysis_options.yaml` | `avoid_print`, `prefer_const_constructors` adicionados + `dart fix --apply` |

---

## Resumo de Progresso

| Prioridade | Total | Concluídos | Pendentes |
|---|---|---|---|
| 🔴 CRÍTICO | 5 | 5 | 0 |
| 🟠 ALTO | 9 | 9 | 0 |
| 🟡 MÉDIO | 12 | 5 | 7 |
| 🟢 BAIXO | 10 | 6 | 4 |
| **Total** | **36** | **25** | **11** |

---

## Backlog Pendente — Próximas Sprints

### Alta prioridade
- **M-03** — Sealed class `ApiFailure`: diferencia erros de rede, 401, 400, 5xx na UI
- **M-04** — Refatorar `AgendaScreen` (1400+ linhas): extrair widgets e controller
- **M-09** — Dividir `OnboardingProvider` (1200+ linhas): Service + State + orquestrador

### Média prioridade
- **M-02** — Testes: login, ciclo NFS-e, onboarding steps, validação CPF/CNPJ
- **M-05** — Desacoplar `ServicoProvider` de `NotaFiscalProvider`
- **M-06** — Extrair `AppRouter` de `main.dart`
- **M-12** — Retry com exponential backoff para erros 5xx e timeout

### Baixa prioridade
- **M-11** — `Tomador.id` nullable (muitas dependências — avaliar impacto)
- **B-02** — `flutter pub upgrade` (rodar e validar breaking changes)
- **B-03** — `Selector` granular no `SyncViewCard`
- **B-04** — Validação de cruzamento de meia-noite no modelo `Servico`
- **B-07** — Separar Model de DTO (`lib/core/dto/`)
- **B-08** — Adotar `go_router`

---

*Auditoria: 2026-05-01 · Última atualização: 2026-05-02*
