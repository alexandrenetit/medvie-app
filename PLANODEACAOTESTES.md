# Relatório de Auditoria de Testes Automatizados

---

## 1. Visão Geral do Projeto

**Tipo de projeto:** Aplicativo mobile Flutter para gestão de serviços médicos e emissão de NFS-e (Nota Fiscal de Serviço Eletrônica).

**Tecnologia principal:** Flutter/Dart com `provider` como solução de state management. HTTP nativo (`http: ^1.6.0`), `shared_preferences` para persistência local e `flutter_secure_storage` para tokens de autenticação.

**Arquitetura aparente:** Arquitetura orientada a features com separação em camadas — `core/` (models, providers, services, utils) e `features/` (auth, agenda, notas, onboarding, profile, relatorios, syncview, welcome). Sem Clean Architecture formal (sem use cases, sem repositórios abstratos). State management via `ChangeNotifier` + `Provider`.

**Organização geral das pastas:**

```
lib/
├── core/
│   ├── constants/    (1 arquivo)
│   ├── models/       (6 arquivos)
│   ├── providers/    (6 arquivos — 2 testados)
│   ├── services/     (2 arquivos)
│   ├── theme/        (1 arquivo)
│   └── utils/        (1 arquivo)
├── features/
│   ├── agenda/       (1 arquivo)
│   ├── auth/         (1 arquivo)
│   ├── notas/        (2 arquivos)
│   ├── onboarding/   (10 arquivos)
│   ├── profile/      (2 arquivos)
│   ├── relatorios/   (1 arquivo)
│   ├── syncview/     (10 arquivos)
│   └── welcome/      (1 arquivo)
├── shared/widgets/   (2 arquivos)
└── main.dart
test/
├── providers/
│   ├── dashboard_provider_test.dart  (110 linhas, 6 testes)
│   └── servico_provider_test.dart    (141 linhas, 6 testes)
└── widget_test.dart                  (placeholder vazio)
.github/workflows/ci.yml              (pipeline CI básico)
```

**Existência de estrutura formal de testes:** Parcial. Há uma pasta `test/` com 3 arquivos, dos quais apenas 2 contêm testes reais (12 testes unitários ao total). Não existe `integration_test/`. Não há arquivos golden. O projeto possui um pipeline CI funcional que executa `flutter test`, mas sem relatório de cobertura.

---

## 2. Resumo Executivo

| Tipo de Teste | Existe? | Qualidade Aparente | Evidências Encontradas | Risco |
|---|---|---|---|---|
| Testes unitários | Parcial | Média | `test/providers/dashboard_provider_test.dart`, `test/providers/servico_provider_test.dart` | Alto |
| Testes de widget | Não | Inexistente | `test/widget_test.dart` (placeholder vazio — `void main() {}`) | Alto |
| Testes de integração | Não | Inexistente | Diretório `integration_test/` inexistente | Alto |
| Testes golden/snapshot | Não | Inexistente | Nenhum arquivo `.png`, nenhuma pasta `goldens/`, nenhum uso de `matchesGoldenFile` | Médio |

**Cobertura geral:** 2 de 49 arquivos Dart testados — **4,08%**.

---

## 3. Diagnóstico dos Testes Unitários

**Existem?** Sim, em escala muito reduzida.

**Onde estão:** `test/providers/dashboard_provider_test.dart` e `test/providers/servico_provider_test.dart`.

**Camadas cobertas:**
- `Providers` — parcialmente: apenas `DashboardProvider` e `ServicoProvider` têm testes.
- `Models` — indiretamente testados via serialização (`DashboardResponse.fromJson`, `Servico.fromJson/toJson`), mas sem testes dedicados.

**Cobertura por subcategoria:**

| Subcategoria | Tem Testes? | Observação |
|---|---|---|
| BLoC/Cubit | N/A | Projeto não usa BLoC/Cubit |
| Providers | Parcial | 2 de 6 providers testados |
| Repositórios | N/A | Sem camada de repositório formal |
| Use Cases | N/A | Sem use cases formais |
| Services/API | Não | `MedvieApiService` (902 linhas) sem nenhum teste |
| Entidades/Models | Não | 6 modelos sem testes dedicados |
| Utils/Formatters | Não | `formatters.dart` sem testes |
| Validadores | Não | Validações de CPF/CNPJ embutidas em providers |

**Dependências usadas:**
- `flutter_test` — framework base de testes
- `mocktail: ^0.3.0` — mocking sem geração de código (apenas em `dashboard_provider_test.dart`)
- `shared_preferences` mock via `SharedPreferences.setMockInitialValues()` (built-in)

**Qualidade dos testes existentes:**
Os 12 testes presentes são bem estruturados. Usam `setUp`, helpers (`_buildServico`, `_encodeServicos`, `_dashboardJson`), cobrem cenários de sucesso, erro, edge case (parâmetro vazio) e notificação de listeners. Nomenclatura descritiva em português. Padrão `when/thenAnswer/thenThrow` aplicado corretamente.

**Lacunas identificadas:**

- `MedvieApiService` (902 linhas) — cliente HTTP centralizado, sem um único teste.
- `ServicoProvider.emitirNf()` — lógica crítica de emissão de NFS-e, sem cobertura.
- `ServicoProvider.adicionarServico()`, `atualizarServico()`, `removerServico()`, `carregarMais()` — mutações e paginação sem testes.
- `OnboardingProvider` — fluxo de autenticação e cadastro, sem testes.
- `NotaFiscalProvider` — integração com SSE (Server-Sent Events), sem testes.
- `RelatorioAnualProvider`, `SimuladorProvider` — sem testes.
- Modelos complexos: `Servico` (374 linhas), `Medico` (~12KB), `NotaFiscal` (150 linhas) — sem testes de serialização/deserialização dedicados.

**Risco técnico:** Alto. A camada de serviços (HTTP) e a lógica de emissão fiscal são os pilares do produto e não possuem qualquer cobertura. Uma regressão nessas áreas não seria detectada automaticamente.

**Classificação: Parcial**

---

## 4. Diagnóstico dos Testes de Widget

**Existem?** Não. O arquivo `test/widget_test.dart` existe mas contém apenas:

```dart
// Placeholder — testes de widget serão adicionados futuramente.
void main() {}
```

**Nenhum uso de `testWidgets`, `WidgetTester`, `pumpWidget`, `find`, `tap` ou `enterText` foi encontrado em qualquer arquivo do projeto.**

**Widgets/telas relevantes sem cobertura:**

| Widget/Tela | Criticidade |
|---|---|
| `auth_screen.dart` | Alta — login/autenticação |
| `onboarding_screen.dart` e seus 5 steps | Alta — cadastro de usuário |
| `syncview_screen.dart` | Alta — tela principal |
| `notas_screen.dart` | Alta — emissão de NFS-e |
| `add_servico_modal.dart` | Alta — formulário de criação |
| `simulador_bottom_sheet.dart` | Média — cálculo de tributos |
| `servico_dia_sheet.dart` | Média — detalhes de serviço |
| `bottom_nav.dart` | Média — navegação global |
| `app_header.dart` | Baixa |
| `mini_calendar.dart` | Baixa |

**Estados visuais sem testes:** loading, error, empty, success em todas as telas.

**Lacunas:** A ausência de testes de widget é total. Não há nenhuma validação automatizada de renderização, interação ou estados visuais em qualquer componente do projeto.

**Classificação: Ausente**

---

## 5. Diagnóstico dos Testes de Integração

**Existe pasta `integration_test/`?** Não.

**Há dependência `integration_test`?** Não declarada no `pubspec.yaml`.

**Fluxos críticos sem cobertura E2E:**

- Fluxo de onboarding (5 steps): dados pessoais → grupo → especialidade → CNPJ → assinatura → confirmação → sucesso.
- Fluxo de autenticação: login com CPF/senha → token → navegação autenticada.
- Fluxo de criação de serviço: preenchimento de formulário → POST na API → atualização da lista.
- Fluxo de emissão de NFS-e: seleção de serviço → emissão → polling de status → feedback ao usuário.
- Fluxo de relatório anual: seleção de ano → carregamento → visualização de PDF.

**Navegação, API, persistência:** Nenhum desses elementos foi coberto por testes de integração.

**Configuração CI/CD para integração:** Inexistente. O `ci.yml` executa apenas `flutter test`, que não alcança testes de integração.

**Lacunas e riscos:** Total ausência de testes E2E significa que regressões em fluxos críticos de negócio (autenticação, emissão fiscal) não são detectadas automaticamente. O risco de deploy com fluxos quebrados é alto.

**Classificação: Ausente**

---

## 6. Diagnóstico dos Testes Golden / Snapshot

**Existem arquivos golden?** Não.

**Uso de `matchesGoldenFile`, `golden_toolkit`, `alchemist`?** Nenhum. Zero ocorrências em toda a base de código.

**Widgets com cobertura visual:** Nenhum.

**Elementos sem cobertura de regressão visual:**
- Tema global (`app_theme.dart`) — cores, tipografia, botões.
- `app_colors.dart` — paleta do design system.
- Telas completas (dashboard, notas, syncview).
- Componentes visuais customizados: `mini_calendar.dart`, `stats_row.dart`, `syncview_card.dart`.
- Estados visuais: loading skeletons, empty states, error cards.

**Risco de regressão visual:** Médio. O projeto usa `google_fonts` e um tema customizado. Mudanças inadvertidas em cores, espaçamentos e tipografia não seriam detectadas automaticamente.

**Classificação: Ausente**

---

## 7. Dependências de Teste Encontradas

| Dependência | Presente? | Uso Provável |
|---|---|---|
| `flutter_test` | Sim (SDK) | Framework base — `test()`, `expect()`, `testWidgets()` |
| `test` | Não declarado explicitamente | Implícito via `flutter_test` |
| `mocktail: ^0.3.0` | Sim | Mocking de `MedvieApiService` em `dashboard_provider_test.dart` |
| `mockito` | Não | Não utilizado |
| `bloc_test` | Não | Não aplicável (sem BLoC/Cubit) |
| `integration_test` | Não | Ausente — nenhum teste E2E |
| `golden_toolkit` | Não | Ausente — nenhum golden test |
| `alchemist` | Não | Ausente |
| `coverage` | Não | Sem análise de cobertura configurada |
| `fake_async` | Não | Ausente — útil para simular timers/delays |
| `build_runner` | Não | Ausente — necessário para mockito com geração de código |

**Observação:** O conjunto de dependências de teste é mínimo. Apenas `flutter_test` e `mocktail` estão disponíveis, o que limita severamente os tipos de teste que podem ser escritos com conforto (ex.: sem suporte a golden files, sem gerador de mocks tipados, sem testes E2E).

---

## 8. Estrutura dos Arquivos de Teste

### Unitários

- `test/providers/dashboard_provider_test.dart` — testa `DashboardProvider`: estado inicial, `carregar()` (sucesso, erro, no-op), listeners, sobrescrita de dados. Usa mock de `MedvieApiService` via mocktail.
- `test/providers/servico_provider_test.dart` — testa `ServicoProvider`: estado inicial, `carregar()` com SharedPreferences vazio e com fixtures, `filtrarPorDia()`, `limparFiltro()`, notificação de listeners.

### Widget

_(nenhum arquivo encontrado)_

### Integração

_(nenhum arquivo encontrado — diretório `integration_test/` não existe)_

### Golden

_(nenhum arquivo encontrado — nenhum `.png` em pastas de teste, nenhum uso de `matchesGoldenFile`)_

### Inconclusivos

- `test/widget_test.dart` — arquivo existe com nome sugestivo de teste de widget, mas contém apenas `void main() {}`. Não executa nenhuma validação. **Não conta como teste.**

---

## 9. Avaliação de Cobertura por Camada

| Camada | Possui Testes? | Evidência | Observação |
|---|---|---|---|
| Entidades/Models | Não | Nenhum arquivo `_test.dart` em `models/` | `Servico` (374 linhas), `Medico` (~12KB), `NotaFiscal` (150 linhas) sem testes de serialização |
| Use Cases | N/A | Sem camada de use cases no projeto | Lógica de negócio está embutida nos providers |
| Repositórios | N/A | Sem camada de repositório formal | Acesso a dados direto nos providers via service |
| Services/API | Não | `medvie_api_service.dart` (902 linhas) sem testes | Cliente HTTP centralizado, renovação de token, todos os endpoints — zero cobertura |
| BLoC/Cubit/State Management | N/A | Projeto usa Provider/ChangeNotifier | Não aplicável |
| Providers | Parcial | `dashboard_provider_test.dart`, `servico_provider_test.dart` | 2 de 6 providers testados; métodos críticos de `ServicoProvider` (emitirNf, adicionarServico) sem cobertura |
| Widgets/Components | Não | `test/widget_test.dart` vazio | Nenhum widget ou componente testado |
| Telas/Pages | Não | Nenhum arquivo em `features/` testado | 29 arquivos de features sem qualquer cobertura |
| Fluxos E2E | Não | Sem `integration_test/` | Nenhum fluxo crítico validado end-to-end |
| Design System/Golden | Não | Sem `goldens/`, sem `matchesGoldenFile` | Regressões visuais indetectáveis automaticamente |

---

# Plano de Ação por Prioridade

---

## BLOCO 1 — Infraestrutura de Testes ✅ CONCLUÍDO (2026-05-02)

**Entregáveis:**
- `pubspec.yaml` — adicionado `fake_async: ^1.3.1`
- `test/test_helpers.dart` — `loadFixture()` e `loadFixtureList()`
- `test/fixtures/` — 6 arquivos JSON de fixtures (servico, servicos_lista, nota_fiscal, nota_fiscal_rejeitada, dashboard, especialidade)
- Estrutura de pastas: `test/models/`, `test/services/`, `test/utils/`, `test/shared/`
- Validação: `dart analyze` — No issues found ✅

---

## Prioridade 1 — Crítica

### Ação 1.1 — Testar `MedvieApiService` ✅ CONCLUÍDO (2026-05-02)

- **Problema identificado:** O cliente HTTP central (`lib/core/services/medvie_api_service.dart`, 902 linhas) não possui nenhum teste. Cobre autenticação, renovação de token, todos os endpoints de serviços, notas fiscais, relatórios e onboarding.
- **Impacto técnico:** Qualquer regressão em requisições HTTP, parsing de JSON, tratamento de erros (401, 500, timeout) ou refresh de token passa despercebida. É a camada com maior superfície de falha do projeto.
- **Ação recomendada:** Criar `test/services/medvie_api_service_test.dart` com mock de `http.Client` usando mocktail. Cobrir: `getJson()` (sucesso e erro), `postJson()`, renovação de token em 401, timeout, respostas malformadas, `login()`, `registrar()`, `emitirNota()`.
- **Camada afetada:** Services/API.
- **Resultado esperado:** Regressões em chamadas HTTP detectadas automaticamente antes do deploy.
- **Executado em:** 2026-05-02
- **Entregáveis:** `test/services/medvie_api_service_test.dart` — 38 testes | `dart analyze` ✅ | `flutter build apk --debug` ✅

---

### Ação 1.2 — Testar `ServicoProvider.emitirNf()`

- **Problema identificado:** O método `emitirNf()` em `ServicoProvider` gerencia a emissão de NFS-e (Nota Fiscal de Serviço Eletrônico) — fluxo crítico e irreversível do produto — sem nenhum teste.
- **Impacto técnico:** Uma regressão nesse método pode gerar falhas silenciosas na emissão de notas, impactando diretamente o faturamento dos médicos usuários do app.
- **Ação recomendada:** Expandir `test/providers/servico_provider_test.dart` com cenários para `emitirNf()`: sucesso com retorno de `notaFiscalId`, falha de API, estado intermediário de loading, atualização do serviço após emissão.
- **Camada afetada:** Providers (ServicoProvider).
- **Resultado esperado:** Lógica de emissão de NF coberta e regressões detectáveis.

---

### Ação 1.3 — Testar `OnboardingProvider` (fluxo de autenticação e cadastro)

- **Problema identificado:** `OnboardingProvider` gerencia o registro de novos usuários, validação de CPF/CNPJ, integração com GoTrue e upload de certificados — tudo sem testes.
- **Impacto técnico:** Falhas no cadastro impossibilitam novos usuários de acessar o sistema. Regressões em validações de documentos (CPF/CNPJ) podem causar erros silenciosos ou dados inválidos persistidos.
- **Ação recomendada:** Criar `test/providers/onboarding_provider_test.dart` cobrindo: `registrar()` (sucesso e erro), `buscarCnpj()` (CNPJ válido/inválido), `adicionarCnpj()`, fluxo de steps (step1 → step5).
- **Camada afetada:** Providers (OnboardingProvider).
- **Resultado esperado:** Fluxo de onboarding protegido contra regressões.

---

### Ação 1.4 — Testar métodos de mutação de `ServicoProvider`

- **Problema identificado:** `adicionarServico()`, `atualizarServico()` e `removerServico()` em `ServicoProvider` não possuem cobertura. São operações de escrita que afetam a lista de serviços e persistência.
- **Impacto técnico:** Perda silenciosa de dados ou inconsistência de estado (lista vs. backend) em operações CRUD básicas.
- **Ação recomendada:** Adicionar testes em `test/providers/servico_provider_test.dart` para cada método de mutação, mockando `MedvieApiService` e verificando estado final da lista e chamadas ao backend.
- **Camada afetada:** Providers (ServicoProvider).
- **Resultado esperado:** Operações CRUD de serviços validadas automaticamente.

---

## BLOCO 2 — Models / Serialização ✅ CONCLUÍDO (2026-05-02)

**Entregáveis:**
- `test/models/servico_test.dart` — 59 testes (TipoServico, StatusServico, fromJson, toJson, helpers, copyWith)
- `test/models/nota_fiscal_test.dart` — 22 testes (StatusNota, fromJson, toJson, round-trip, copyWith)
- `test/models/medico_test.dart` — 46 testes (todos os submodelos + enums do arquivo medico.dart)
- `test/models/remaining_models_test.dart` — 3 testes (DashboardResponse, Especialidade, PerfilAtuacao)
- **Total acumulado:** 130 testes novos | **Suíte total:** 142 testes (12 anteriores + 130)
- Validação: `dart analyze` — No issues found ✅ | `flutter build apk --debug` ✅

---

## Prioridade 2 — Alta

### Ação 2.1 — Testar modelos complexos com serialização ✅ CONCLUÍDO

- **Problema identificado:** `Servico` (374 linhas), `NotaFiscal` (150 linhas) e `Medico` (~12KB) possuem lógica de `fromJson`/`toJson` sem testes dedicados. Alterações em campos ou tipos quebram silenciosamente a comunicação com o backend.
- **Impacto técnico:** Mudanças no contrato de API que alteram a estrutura do JSON podem passar despercebidas até o ambiente de produção.
- **Ação recomendada:** Criar `test/models/servico_test.dart`, `test/models/nota_fiscal_test.dart`, `test/models/medico_test.dart` com fixtures JSON reais (arquivo `.json` em `test/fixtures/`) e assertions de round-trip (`fromJson → toJson → fromJson`).
- **Camada afetada:** Models.
- **Resultado esperado:** Contratos de serialização validados; regressões de API detectadas antes do deploy.
- **Executado em:** 2026-05-02
- **Entregáveis criados:**
  - `test/models/servico_test.dart` — 59 testes (TipoServico, StatusServico, fromJson, toJson, duracaoFormatada, horarioFormatado, discriminacao, copyWith)
  - `test/models/nota_fiscal_test.dart` — 22 testes (StatusNota, fromJson NF autorizada e rejeitada, toJson, round-trip, copyWith)
  - `test/models/medico_test.dart` — 46 testes (Endereco, Tomador, CnpjComTomadores, Medico, todos os enums: RegimeTributario, MetodoAssinatura, StatusCertificado)
  - `test/models/remaining_models_test.dart` — 3 testes (DashboardResponse, Especialidade, PerfilAtuacao)
- **Total de testes do Bloco 2:** 130 novos testes
- **Validação:** `dart analyze` — No issues found ✅ | `flutter build apk --debug` ✅

---

### Ação 2.2 — Testar `NotaFiscalProvider` (integração com SSE)

- **Problema identificado:** `NotaFiscalProvider` integra com Server-Sent Events para atualização em tempo real do status de notas fiscais. Sem testes, qualquer falha na lógica de stream/evento é invisível.
- **Impacto técnico:** Usuários podem receber status desatualizados de notas (processando, aprovada, rejeitada) sem que a regressão seja detectada.
- **Ação recomendada:** Criar `test/providers/nota_fiscal_provider_test.dart` mockando `SseService` e `MedvieApiService`. Cobrir: carregamento inicial, atualização via evento SSE, filtros por status e mês.
- **Camada afetada:** Providers (NotaFiscalProvider).
- **Resultado esperado:** Lógica de tempo real coberta e validada sem depender de conexão real.

---

### Ação 2.3 — Implementar testes de widget nas telas críticas

- **Problema identificado:** Nenhuma tela ou widget possui testes. O arquivo `test/widget_test.dart` é um placeholder vazio desde a criação do projeto.
- **Impacto técnico:** Regressões de renderização, estados visuais (loading, error, empty) e interações básicas (tap, scroll, navegação) não são detectadas.
- **Ação recomendada:** Implementar `testWidgets` para pelo menos: `auth_screen.dart` (renderiza form, valida campos, exibe erro), `syncview_screen.dart` (lista de serviços, empty state), `notas_screen.dart` (lista de notas e estados). Usar `pumpWidget` com `MultiProvider` mockado.
- **Camada afetada:** Widgets/Telas.
- **Resultado esperado:** Estados visuais críticos cobertos; regressões de renderização detectáveis.

---

### Ação 2.4 — Configurar relatório de cobertura no CI/CD

- **Problema identificado:** O pipeline `ci.yml` executa `flutter test` mas não gera relatório de cobertura. A equipe não tem visibilidade sobre a evolução ou regressão da cobertura.
- **Impacto técnico:** Sem métricas, a cobertura pode regredir indefinidamente sem alertas. PRs com código não testado são aprovados silenciosamente.
- **Ação recomendada:** Adicionar ao `ci.yml`: `flutter test --coverage`, instalar `lcov`, gerar relatório HTML e integrar com Codecov ou similar. Adicionar badge de cobertura ao README.
- **Camada afetada:** CI/CD.
- **Resultado esperado:** Cobertura visível, rastreável e comparável por PR.

---

## BLOCO 4 — Services (MedvieApiService) ✅ CONCLUÍDO (2026-05-02)

**Entregáveis:**
- `lib/core/services/medvie_api_service.dart` — injeção de `http.Client` e `FlutterSecureStorage` via construtor para testabilidade; substituição de todos os `http.get/post/put/patch/delete` globais por `_client.*`
- `test/services/medvie_api_service_test.dart` — 38 testes cobrindo: DTOs (BuscarCepResponse, BuscarCnpjResponse, SugestaoFiscalResponse, OnboardingStatusResponse, TomadorResumoResponse), getJson, postJson, login, registrar, emitirNota, refresh automático de token (401 → retry), carregarTokensPersistidos, buscarCep, buscarCnpj, listarServicos, TipoPdf
- **Total acumulado:** 38 testes novos | **Suíte total:** 228 testes
- Validação: `dart analyze` — No issues found ✅ | `flutter build apk --debug` ✅

---

## BLOCO 3 — Utils & Constants ✅ CONCLUÍDO (2026-05-02)

**Entregáveis:**
- `test/utils/formatters_test.dart` — 28 testes (formatCpf, formatCnpj, digitsOnly, round-trips)
- `test/utils/app_colors_test.dart` — 20 testes (valores hex de cada cor + propriedades semânticas: opacidade, luminosidade relativa)
- **Total acumulado:** 48 testes novos | **Suíte total:** 190 testes
- Validação: `dart analyze` — No issues found ✅ | `flutter build apk --debug` ✅

---

## Prioridade 3 — Média

### Ação 3.1 — Testar `RelatorioAnualProvider` e `SimuladorProvider`

- **Problema identificado:** `RelatorioAnualProvider` (agregações anuais de faturamento) e `SimuladorProvider` (cálculo de tributos) não possuem testes.
- **Impacto técnico:** Erros em cálculos financeiros podem gerar valores incorretos exibidos ao usuário, afetando decisões de planejamento fiscal.
- **Ação recomendada:** Criar `test/providers/relatorio_anual_provider_test.dart` e `test/providers/simulador_provider_test.dart`. Cobrir: `carregar()`, `porMes()`, `calcular()` com casos de valor zero, negativo e máximo.
- **Camada afetada:** Providers.
- **Resultado esperado:** Lógica de cálculo financeiro validada automaticamente.

---

### Ação 3.2 — Testar `formatters.dart` e utilitários ✅ CONCLUÍDO

- **Problema identificado:** `lib/core/utils/formatters.dart` provavelmente contém formatadores de moeda, data e documentos usados em toda a UI, sem testes.
- **Impacto técnico:** Formatação incorreta de valores financeiros ou datas pode causar exibição errada sem detecção automática.
- **Ação recomendada:** Criar `test/utils/formatters_test.dart` com testes parametrizados cobrindo: formatação de moeda (BRL), formatação de datas, máscaras de CPF/CNPJ, valores limite (zero, negativo, muito grande).
- **Camada afetada:** Utils.
- **Resultado esperado:** Utilitários de formatação validados para todos os casos de borda.
- **Executado em:** 2026-05-02
- **Entregáveis:** `test/utils/formatters_test.dart` (28 testes) + `test/utils/app_colors_test.dart` (20 testes — regressão visual da paleta de cores)

---

### Ação 3.3 — Testar widgets compartilhados

- **Problema identificado:** `bottom_nav.dart` e `pdf_viewer_sheet.dart` em `lib/shared/widgets/` são componentes usados globalmente, sem testes.
- **Impacto técnico:** Regressões em navegação global ou visualização de documentos afetam toda a aplicação.
- **Ação recomendada:** Criar `test/shared/widgets/bottom_nav_test.dart` com `testWidgets` cobrindo: renderização dos ícones, tab ativa, callback de navegação.
- **Camada afetada:** Widgets compartilhados.
- **Resultado esperado:** Componentes globais protegidos contra regressões.

---

### Ação 3.4 — Adicionar fixtures JSON externas ✅ CONCLUÍDO

- **Problema identificado:** Os testes existentes usam funções helper inline para gerar dados de teste (`_dashboardJson()`, `_buildServico()`). Para modelos complexos, isso torna os testes verbosos e difíceis de manter.
- **Impacto técnico:** Dificuldade de manutenção ao evoluir os modelos; risco de fixtures desincronizadas com o backend real.
- **Ação recomendada:** Criar pasta `test/fixtures/` com arquivos `.json` reais (copiados de respostas do backend em ambiente de dev). Criar helper `loadFixture(String path)` para carregar esses arquivos nos testes.
- **Camada afetada:** Infraestrutura de testes.
- **Resultado esperado:** Fixtures centralizadas, reutilizáveis e sincronizadas com o contrato real da API.
- **Executado em:** 2026-05-02
- **Entregáveis criados:**
  - `test/fixtures/servico.json`
  - `test/fixtures/servicos_lista.json`
  - `test/fixtures/nota_fiscal.json`
  - `test/fixtures/nota_fiscal_rejeitada.json`
  - `test/fixtures/dashboard.json`
  - `test/fixtures/especialidade.json`
  - `test/test_helpers.dart` — helpers `loadFixture()` e `loadFixtureList()`
  - Estrutura de diretórios: `test/models/`, `test/services/`, `test/utils/`, `test/shared/`
  - `fake_async: ^1.3.1` adicionado ao `pubspec.yaml`

---

## Prioridade 4 — Evolutiva

### Ação 4.1 — Implementar testes de integração E2E

- **Problema identificado:** Não existe diretório `integration_test/` nem a dependência correspondente. Nenhum fluxo crítico (login, emissão de NF, onboarding) é testado de ponta a ponta.
- **Impacto técnico:** Regressões em fluxos completos só são descobertas manualmente em QA ou em produção.
- **Ação recomendada:** Criar `integration_test/app_test.dart` e `integration_test/flows/`. Declarar `integration_test` no `pubspec.yaml`. Implementar ao menos: fluxo de login, fluxo de criação de serviço e fluxo de emissão de NFS-e com API mockada (fake server local ou `mockito` + `http_mock_adapter`). Adicionar job `integration-test` ao CI/CD usando emulador Android.
- **Camada afetada:** Fluxos E2E, CI/CD.
- **Resultado esperado:** Fluxos críticos validados automaticamente antes de cada release.

---

### Ação 4.2 — Implementar testes golden para o design system

- **Problema identificado:** O projeto usa `google_fonts`, tema customizado e componentes visuais específicos (`mini_calendar`, `stats_row`, `syncview_card`) sem qualquer proteção contra regressão visual.
- **Impacto técnico:** Mudanças inadvertidas em tema, cores ou layout de componentes críticos não são detectadas automaticamente.
- **Ação recomendada:** Adicionar `golden_toolkit` ou `alchemist` ao `pubspec.yaml`. Criar `test/golden/` com golden files para: `SyncviewCard` (estados normal, loading, erro), `StatsRow`, `MiniCalendar`, `AppHeader` e a paleta de cores do design system. Gerar `.png` de referência e incluir no repositório.
- **Camada afetada:** Design System, Widgets.
- **Resultado esperado:** Regressões visuais detectadas automaticamente no CI.

---

### Ação 4.3 — Estabelecer threshold mínimo de cobertura por camada

- **Problema identificado:** Sem uma política de cobertura mínima, PRs podem reduzir a cobertura progressivamente sem bloqueio.
- **Impacto técnico:** Degradação gradual e silenciosa da qualidade ao longo do tempo.
- **Ação recomendada:** Após atingir cobertura ≥40% (meta intermediária), configurar threshold no CI: `flutter test --coverage && lcov --min-percentage 40`. Evoluir gradualmente para 60% (6 meses) e 80% (12 meses) para código novo.
- **Camada afetada:** CI/CD, processos de engenharia.
- **Resultado esperado:** Cobertura gerenciada e evolutiva; sem regressão silenciosa.

---

### Ação 4.4 — Testar `SseService` (Server-Sent Events)

- **Problema identificado:** `lib/core/services/sse_service.dart` gerencia streams de eventos em tempo real para atualização de status de NF. É uma camada assíncrona complexa sem testes.
- **Impacto técnico:** Falhas no stream (reconexão, parsing de eventos, fechamento) não são detectadas automaticamente.
- **Ação recomendada:** Criar `test/services/sse_service_test.dart` usando `fake_async` para simular eventos no stream. Cobrir: recebimento de evento válido, evento malformado, reconexão após falha, cancelamento do stream.
- **Camada afetada:** Services.
- **Resultado esperado:** Comportamento assíncrono do SSE validado e documentado por testes.

---

### Ação 4.5 — Configurar Melos para orquestração de testes (futuro monorepo)

- **Problema identificado:** O projeto não possui `melos.yaml` nem scripts padronizados para execução de subconjuntos de testes.
- **Impacto técnico:** À medida que o projeto cresce, a ausência de scripts padronizados dificulta a execução seletiva de testes por camada ou feature.
- **Ação recomendada:** Criar `Makefile` ou `tool/run_tests.sh` com targets: `test-unit`, `test-widget`, `test-integration`, `test-coverage`. Avaliar `melos.yaml` se o projeto evoluir para estrutura de packages.
- **Camada afetada:** CI/CD, Developer Experience.
- **Resultado esperado:** Execução de testes rápida, seletiva e padronizada para todos os membros da equipe.

---

## Veredito Final

**O projeto possui testes suficientes?**
Não. Com 4,08% de cobertura (2 arquivos de 49), o projeto está em estágio inicial de qualidade. Os 12 testes existentes são bem escritos e servem como referência de boas práticas, mas não são representativos da complexidade do sistema.

**Quais tipos de teste estão ausentes ou frágeis?**
- **Ausentes completamente:** testes de widget, testes de integração E2E, testes golden/snapshot.
- **Frágeis:** testes unitários existentes cobrem apenas 2 dos 6 providers e não tocam a camada de serviços HTTP, modelos complexos, nem os fluxos de negócio mais críticos (emissão de NF, autenticação).

**Qual é o maior risco atual?**
A ausência de testes para `MedvieApiService` (902 linhas) e para a lógica de emissão de NFS-e (`ServicoProvider.emitirNf()`). Ambas são operações críticas, irreversíveis e financeiramente sensíveis que dependem exclusivamente de validação manual.

**Qual deve ser a primeira ação da equipe?**
Criar `test/services/medvie_api_service_test.dart` com mock de `http.Client` via mocktail, cobrindo pelo menos os endpoints de `login`, `emitirNota` e `getJson` com cenários de sucesso, 401, 500 e timeout. Em paralelo, expandir `servico_provider_test.dart` com testes para `emitirNf()`.

**Qual o nível geral de maturidade da suíte de testes?**
**Nível 1 de 5 — Inicial.** O projeto possui a infraestrutura mínima (flutter_test, mocktail, CI executando `flutter test`), mas a cobertura é simbólica. Os testes existentes demonstram que a equipe conhece as boas práticas, porém ainda não as aplicou de forma sistemática. Para um produto financeiro/fiscal em produção, o nível esperado seria 3 (cobertura unitária consistente das camadas de negócio) como mínimo absoluto.

---

*Auditoria realizada em: 2 de maio de 2026*
*Versão do Flutter declarada no CI: 3.32.x (stable)*
*Total de arquivos Dart analisados: 49*
*Total de arquivos com testes reais: 2*
*Cobertura de arquivos: 4,08%*
*Total de casos de teste válidos: 12*
