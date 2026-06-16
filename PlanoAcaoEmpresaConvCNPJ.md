# Plano Ação — Atendimento Empresa / Convênio (Tomador CNPJ)

> Modo: **caveman ultra**. Prosa comprimida. Nomes de símbolo/arquivo/comando = exatos, nunca abreviados.
> Doc vivo. Cada sessão: ler §1, executar, atualizar §6 checkboxes + §9 log.
> NÃO é greenfield. Ramo CNPJ JÁ existe (dropdown legado). Tarefa = **elevar ao nível protótipo v15** + paridade c/ `AtendimentoPfFlow`.

---

## 0. Objetivo

Ramo CNPJ do registro de atendimento → paridade c/ PF (feature 017) + UX protótipo `prototipo_pf/medvie-atendimento-cnpj-v15.html`.
Backend .NET = fonte única verdade. Flutter só renderiza. UI nunca calcula retenção/alíquota/IBS/CBS.
Entregável final: fluxo Empresa/Convênio production-final (seleção tomador escalável, serviço, valor, preview fiscal live, emitir opcional).

---

## 1. PROTOCOLO DE INÍCIO DE SESSÃO (rodar SEMPRE, em ordem)

Execução obrigatória no começo de toda sessão de implementação deste plano:

1. Ler `C:\Projects\medvie\medvie-app\CLAUDE.md` (regras inegociáveis do projeto).
2. Ler este arquivo inteiro. Localizar §6 → primeira task com `[ ]`. Identificar a **fase** dela. Branch = por fase, não por task (ver §7.A).
3. Posicionar branch da fase:
   - Fase nova → `git checkout develop && git pull origin develop && git checkout -b feat/cnpj-fN-<slug>`.
   - Fase em andamento (branch já existe) → `git checkout feat/cnpj-fN-<slug>` e seguir.
   - Exceção F0 (discovery/doc): SEM branch — commit do `.md` direto na develop (§7.D).
4. Confirmar codegraph vivo: `codegraph_status`. Se índice defasado, aguardar ~1s (watcher).
5. Ancorar contexto da task via UMA chamada `codegraph_explore` com os símbolos/arquivos citados (Read-equivalente; não reabrir arquivos já retornados).
6. Antes de editar: escrever protocolo de 2-3 linhas (o que / arquivos / risco). Aguardar `pode ir` do usuário.
7. Editar com `str_replace` (Edit). `sed -i` proibido. Máx 3 arquivos por iteração.
8. **Gate leve** (§7.B) ao fim da task → verde → commit na branch da fase. Marcar task `[x]`.
9. Ao fechar a ÚLTIMA task da fase: **gate pesado** (§7.C) → verde → merge `--no-ff` na develop → push. Append no §9 log (branch + hash + gate).

Regra anti-desperdício de token: NÃO reexplorar área já documentada em §3/§4. Usar codegraph (índice pronto), não grep+read manual em loop.

---

## 2. Estado verificado (âncoras reais — verificado 2026-06-16)

| Camada | Arquivo:linha | Estado |
|---|---|---|
| Model serviço | `lib/core/models/servico.dart:207` `Servico` | suporta CNPJ: `tomadorCnpj/tomadorNome/tomadorId/aliquotaIss/issRetido/retemIrrf/aliquotaIrrf`. `toJson`/`fromJson` ok. |
| Model serviço | `lib/core/models/servico.dart:316` | `valorIssRetido/valorIrrfRetido/valorLiquidoEstimado` — **UI infere alíquota local** ⚠ (conflita regra "backend calcula"). |
| Enum | `lib/core/models/servico.dart:8` `TipoServico` | plantao/atoAnestesico/laudo/procedimentoCirurgico/consulta/outros + `backendEnumName` + `codigoNbs`. |
| Model tomador | `lib/core/models/medico.dart:345` `Tomador` | CNPJ completo: tipo, cnpj, razaoSocial, retemIss/Irrf, aliquotas, enderecoFiscal. |
| Model | `lib/core/models/medico.dart:451` `CnpjComTomadores` / `:519` `Medico.todosTomadores` | lista de tomadores em memória pós-login. |
| Enum | `lib/core/models/medico.dart:243` `TipoTomador {cpf,cnpj}` | + `EnderecoFiscalTomador:262`. |
| Provider | `lib/core/providers/servico_provider.dart:119` `adicionarServico` | cria serviço CNPJ (tomadorCnpj/Nome/Id) via `criarServico`. Não emite. |
| Provider | `servico_provider.dart:425` `confirmarAtendimentoPf` | **template a espelhar p/ CNPJ**. |
| Provider | `servico_provider.dart:493` `previewFiscalPf` | preview backend (valor+competencia+cnpjProprioId). Candidato a generalizar p/ CNPJ. |
| Provider | `servico_provider.dart:408` `buscarEnderecoFiscal` / `:278` `emitirNf` | CEP autofill / emissão (genérico). |
| Service | `lib/core/services/medvie_api_service.dart:589` `criarServico` `:637` `criarAtendimentoPf` `:660` `previewAtendimentoPf` `:511` `buscarCep` `:1051` `emitirNota` `:692` `lookupTomadorPorCpf` `:294` `cadastrarTomador` (POST `/api/v1/servicos/tomadores`) | endpoints. ✅ F0: `cadastrarTomador` standalone CNPJ existe (Ramo A). |
| UI orquestrador PF | `lib/features/syncview/widgets/atendimento_pf_flow.dart:32` `AtendimentoPfFlow` | **modelo de referência** p/ `AtendimentoCnpjFlow`. `_CurrencyInputFormatter:547` (máscara centavos, reaproveitar). |
| UI entry-point | `lib/features/syncview/widgets/add_servico_modal.dart:49` `_segmentoPf` / `:818` botão "Empresa / Convênio" / `:506-513` delega PF→`AtendimentoPfFlow` / `:514-770` corpo CNPJ inline legado | segmento já existe. CNPJ ainda inline+dropdown. |
| UI reuso | `endereco_fiscal_form.dart` · `preview_fiscal_pf_card.dart` · `notas/widgets/emissao_confirmacao_sheet.dart` (`showPosSalvar`) | reaproveitáveis. |
| UI tomador existente | `features/profile/editar_tomador_screen.dart` · `features/onboarding/screens/step3_tomadores_screen.dart` | cadastro tomador já existe (referência p/ form). |
| Protótipo aprovado | `prototipo_pf/medvie-atendimento-cnpj-v15.html` | UX alvo: resumo+bottom sheet busca, cadastro inline, cards 2x2, valor hero, horário só plantão, status pgto, preview fiscal, emitir toggle. |

> Codegraph indexa o **backend .NET** (não o Flutter) — usar p/ confirmar contrato (entities `Servico`/`Tomador`, enums, request DTOs). Flutter: usar Read/Grep/Glob.

---

## 3. Contrato backend (verificado via codegraph — entities .NET)

`Servico` (Medvie.Domain): `CnpjProprioId, TomadorId, RequisicaoId, TipoServico, CodigoNbs, Discriminacao, Valor(>0), Competencia, Status`. `Create` valida valor>0, ids não-vazios, discriminação obrigatória.

`Tomador` (Medvie.Domain): `CnpjProprioId, TipoTomador(0=CNPJ,1=CPF), Cnpj?, Cpf?, RazaoSocial, EmailFinanceiro?, CodigoMunicipioPrestacao, ValorPadrao?, RetemIss, AliquotaIss?, RetemIrrf, AliquotaIrrf, InscricaoMunicipal?, EnderecoFiscalStatus`. Getter `EnderecoFiscalCompleto`.

Implicações UI:
- Tomador CNPJ já modelado backend → cadastro inline = POST tomador (confirmar endpoint F0).
- `RequisicaoId` = idempotência. Gerar `Uuid().v4()` por submit (igual PF/plantonista).
- Retenção/alíquota vêm do tomador (cadastro). Preview oficial = backend. UI exibe "a definir no envio" / "Não retém", nunca calcula.

---

## 3.A Achados F0 (discovery — verificado 2026-06-16)

### T0.1 — Comportamento real `add_servico_modal.dart` (corpo CNPJ legado)

| Método (linha) | Comportamento real |
|---|---|
| `_buildPreviewFiscal` [138] | `modoEdicao`→oculto. Chama `_calcularPreview` [128] que **infere retenção LOCAL** (`iss=bruto*aliquotaIss/100` se `retemIss`; idem irrf; `liquido=bruto-iss-irrf`). ⚠ viola backend-verdade (G7). **Sem IBS/CBS**, sem "a definir". Rebuild via `ValueListenableBuilder(_valorController)` [608]. |
| `_buildDropdownTipo` [842] | `DropdownButton<TipoServico>` sobre `TipoServico.values`. Item = `icone`+`label`. **Sem NBS** (G3 = cards 2×2). |
| `_buildDropdownTomadores` [879] | `DropdownButton<Tomador>`. Item = `razaoSocial` + (`municipio · R$ valorPadrao` se >0). onChanged → **autofill `_valorController`** se `valorPadrao>0`. ⚠ não escala (G1). |
| `_buildSemTomadores` [936] | Card info estático "Adicione hospitais nas configurações." **Sem CTA cadastrar** (G2 / F2.T2.3). |
| `_salvar` [307] | Guards: tomador null / valor inválido (snackbar). Criação → `adicionarServico(tipo,data,tomadorId,tomadorCnpj,tomadorNome,valor,status,observacao,horaInicio,horaFim,cnpjProprioId)`. **NÃO emite NFS-e** (G8). `requisicaoId` fica no provider. `debugPrint [SALVAR]` pesado — limpar em F7. |
| `_selecionarHora` [185] | `showTimePicker` dark; default 07:00/19:00; `mounted` guard. **Sempre visível**, não condicional a Plantão (G5). Duração inline [648-672] trata virada meia-noite. |

### T0.2 — Fonte de tomadores em runtime
- `onboarding_provider.tomadores` getter [:345] = `tomadoresAtual` (lista **em memória**).
- Populada no restore pós-login [:223-224]: `cnpjsFinalizados.expand((c)=>c.tomadores)`.
- Mutada **localmente** no cadastro (add à lista) + `notifyListeners`. **Sem método de re-fetch dedicado** — só `getMedico` (reload total do médico).
- Implicação F3: após `cadastrarTomador` (retorna `tomadorId`), provider não auto-recarrega → append local do `Tomador` na lista + `notifyListeners`, depois auto-selecionar.

### T0.3 🔑 — DECISION GATE → **RAMO A** (endpoint existe)
- Flutter: `cadastrarTomador(String cnpjProprioId, Tomador)` [medvie_api_service.dart:294] → `POST /api/v1/servicos/tomadores`, retorna **201** + `{tomadorId}`.
- Backend: `ServicoController.CadastrarTomador` [src/Medvie.Api/Controllers/ServicoController.cs:241], **coberto por** `tests/Medvie.Tests/Api/ServicoControllerTests.cs`.
- Body enviado: `cnpjProprioId, cnpj, razaoSocial, emailFinanceiro, codigoMunicipioPrestacao(=codigoIbge), valorPadrao, retemIss, aliquotaIss, retemIrrf`.
- ⚠ Body NÃO envia `aliquotaIrrf`, `inscricaoMunicipal`, nem endereço fiscal completo. **F3 decidir**: estender body do `cadastrarTomador` (preferir, alinhar contrato) ou backend derivar. Registrar em F3.T3.1.
- Consequência: **F3 = Ramo A normal** (cadastro inline → POST). F1.T1.3 = provider `criarTomadorCnpj` wrapping `cadastrarTomador`.

### T0.4 — Preview fiscal: genérico, reusar
- `previewAtendimentoPf({cnpjProprioId, valor, competencia})` [medvie_api_service.dart:660] → `POST /api/v1/atendimentos/preview`.
- Backend `AtendimentoController.PreviewAtendimento` [src/Medvie.Api/Controllers/AtendimentoController.cs:147]: corpo `{cnpjProprioId, valor, competencia}` — **agnóstico a tomador**. Calcula IBS/CBS por regime+competência. **ISS/IRRF retornam 0** (endpoint não recebe tomador). Response `AtendimentoPreviewDto(Bruto, IssRetido, IrrfRetido, Ibs, Cbs, LiquidoEstimado, ProntoParaEmitir)`.
- **Decisão**: generalizar `previewFiscalPf`/`previewAtendimentoPf` → nome neutro (`previewFiscalAtendimento`), reusar **mesmo endpoint**. NÃO criar `previewFiscalCnpj`.
- Coerência v15 (G7): ISS/IRRF do tomador → UI exibe "a definir no envio" / "Não retém" (endpoint não traz); IBS/CBS/líquido = backend live. ✅ endpoint atual atende F5.

---

## 4. Gap protótipo v15 ↔ código atual (corpo CNPJ add_servico_modal)

| # | Item v15 | Código atual | Gap |
|---|---|---|---|
| G1 | Seleção tomador = resumo (1 card) + bottom sheet busca | dropdown `_buildDropdownTomadores` (linha 535) | **substituir** — não escala (reclamação original). |
| G2 | Cadastro tomador inline no sheet | só em onboarding/profile | **novo** `TomadorSelectorSheet` modo cadastro. |
| G3 | Tipo serviço = cards 2×2 (Plantão/Procedimento/Cirurgia/Honorário) + NBS mono | dropdown `_buildDropdownTipo` | substituir por grid (espelhar `AtendimentoPfFlow._seletorServico`). |
| G4 | Valor hero + máscara centavos pt-BR | `TextField` filtro `[0-9.,]` cru | reusar `_CurrencyInputFormatter`. |
| G5 | Horário início/fim só quando Plantão | `_HorarioBtn` sempre visível | condicional ao tipo=Plantão. |
| G6 | Status pagamento A receber/Já recebi | chips existem (linha 680-688) | manter; ok. |
| G7 | Preview fiscal: ISS/IRRF "a definir" + IBS/CBS backend + líquido | `_buildPreviewFiscal` infere alíquota local ⚠ | trocar p/ preview backend (não inferir). |
| G8 | Toggle "emitir agora" + sheet pós-salvar + resultado | só "Registrar serviço" (`adicionarServico`) | adicionar fluxo emissão (espelhar PF `_finalizarPosSalvar` + `EmissaoConfirmacaoSheet`). |
| G9 | A11y (foco, semantics, contraste) | parcial | aplicar (do protótipo v14/v15). |

Decisão arquitetural: **extrair `AtendimentoCnpjFlow`** (widget próprio, espelha `AtendimentoPfFlow`). `add_servico_modal` no modo criação só decide segmento e delega (PF→`AtendimentoPfFlow`, CNPJ→`AtendimentoCnpjFlow`). Modo edição CNPJ legado preservado até F7. Mantém modal enxuto, testável, simétrico.

---

## 5. Princípios (best-practice dev guiado por IA)

- Fase pequena, verificável, 1 conceito. Máx 3 arquivos/iteração (CLAUDE.md).
- Cada task: arquivo-alvo + ação + critério de pronto explícito.
- Reuso > reescrita. Espelhar PF onde possível (paridade reduz risco).
- Backend = verdade. Lookup CNPJ/CEP/preview/retenção → sempre backend.
- Sem hardcode (cor/URL/NBS/alíquota). NBS via `TipoServico.codigoNbs`.
- Gate leve por task (§7.B: `dart analyze`+`flutter test`); gate pesado por fase (§7.C: `+build apk`+`dcm`).
- **1 fase = 1 branch = 1 merge develop.** Tasks = commits dentro da branch da fase. Develop só recebe fase que passou no gate pesado → develop sempre verde.
- Fase = incremento coeso e demonstrável (não micro-commit isolado). Build APK pesado roda 1×/fase, não 1×/task.
- Commit por task (pt-br, `feat:`, sem Co-Authored-By). Mensagem do merge resume a fase.

---

## 6. FASES + TASKS (controle — marcar `[x]` ao concluir)

> Branch por FASE (§7.A). Task `[x]` = commit na branch da fase com gate leve §7.B verde. Fase `[x]` (todas as tasks) → gate pesado §7.C → merge develop. F0 = exceção §7.D (doc, sem branch/build).
> Dependências entre fases explícitas abaixo (DEP:). Fase sem dependência pendente pode ser paralelizada.

### F0 — Discovery / fechar lacunas ⚠ (pré-requisito) · exceção §7.D (doc, sem branch/build) · ✅ CONCLUÍDA 2026-06-16
- [x] **T0.1** `add_servico_modal.dart` 6 métodos documentados (→ §3.A). Comportamento real: preview infere retenção local ⚠, tipo/tomador via dropdown, horário sempre visível, salvar não emite NFS-e.
- [x] **T0.2** Fonte tomadores runtime documentada (→ §3.A). `onboarding_provider.tomadores` [:345] = lista memória `tomadoresAtual`; sem re-fetch dedicado (só `getMedico` reload total).
- [x] **T0.3** 🔑 DECISION GATE → **RAMO A**. Endpoint existe: `cadastrarTomador` [medvie_api_service.dart:294] → `POST /api/v1/servicos/tomadores` → backend `ServicoController.CadastrarTomador` [:241], testado. F3 = cadastro inline → POST normal.
- [x] **T0.4** Preview **genérico** (não PF-específico). `POST /api/v1/atendimentos/preview` corpo = `{cnpjProprioId, valor, competencia}`, agnóstico a tomador. **Decisão: generalizar/reusar**, não criar `previewFiscalCnpj`.
- [x] **T0.5** §3/§4 atualizados; ⚠ fechados (→ §3.A, §10).

### F1 — Camada provider/service (dados) · DEP: F0 · ✅ CONCLUÍDA 2026-06-16 (merge 171c78c)
- [x] **T1.1** Provider `confirmarAtendimentoCnpj` em `servico_provider.dart` espelhando `confirmarAtendimentoPf` (tomador JÁ existe → usa `tomadorId`; sem criar tomador). Idempotente (`requisicaoId`). `emitirAgora=false`. → `feat/cnpj-f1-provider-service` (7453a38). Retorna `Servico` persistido; retenções vêm do `Tomador` (não infere). Gate leve: analyze 0 issues; testes lógica passam (4 golden falham = baseline Windows, pré-existente).
- [x] **T1.2** Preview fiscal CNPJ: provider `previewFiscalPf`→`previewFiscalAtendimento` (nome neutro, agnóstico a tomador) em `servico_provider.dart:493`; doc atualizada (ISS/IRRF vêm do cadastro, não do preview — G7). Retorno `AtendimentoFiscalPreview` já carrega IBS/CBS/líquido do backend → "UI consome backend" satisfeito sem nova lógica. Call-site PF `atendimento_pf_flow.dart:130` atualizado. Service `previewAtendimentoPf` (plumbing interno) mantido — reusa mesmo endpoint `POST /api/v1/atendimentos/preview`. Gate leve: analyze 0 issues; 642 passed; 4 golden falham = baseline Windows (pré-existente).
- [x] **T1.3** (Ramo A, T0.3) Provider `criarTomadorCnpj({cnpjProprioId, tomador})` em `servico_provider.dart` delegando ao `cadastrarTomador` existente [medvie_api_service.dart:294] — endpoint já existe, sem novo. Retorna `Tomador` com o `id` do backend (auto-seleção F3); provider NÃO guarda lista de tomadores (vive no `OnboardingProvider`, T0.2). Guards: api null, CNPJ vazio, backend sem `tomadorId`. Adicionado `Tomador.copyWith` em `medico.dart` (idiomático, espelha `EnderecoFiscalTomador`/`Servico`). 5 testes (sucesso/cnpj vazio/sem id/erro service/api null). ⚠ body de `cadastrarTomador` ainda não envia `aliquotaIrrf`/`inscricaoMunicipal`/endereço (§10) — fechar em F3.T3.1. Gate leve: analyze 0 issues; 12 testes do arquivo CNPJ passam.
- [x] **T1.4** Teste unitário provider (mock api): `test/core/providers/servico_provider_atendimento_cnpj_test.dart`, espelhando o teste PF. 7 casos: sucesso (servicoId do backend, tomadorTipo=CNPJ, retenções vindas do `Tomador` sem inferência, não emite NFS-e), cnpjProprioId como 1º arg posicional, idempotência (mesmo servicoId → não duplica), resposta sem servicoId (mantém id local), tomador sem id (rejeita, não chama service), erro do service (propaga, lista intacta), api não injetado (lança). Gate leve: analyze 0 issues; 649 passed; 4 golden falham = baseline Windows (pré-existente, widget rendering — não afetado).

### F2 — Widget `TomadorSelectorSheet` (G1) · DEP: F0 · independe de cadastro (T0.3)
- [x] **T2.1** Novo `lib/features/syncview/widgets/tomador_selector_sheet.dart`: `TomadorResumoCard` (StatelessWidget) — sigla (iniciais até 3 palavras, fallback "TM"), razão (Outfit ellipsis), CNPJ mono (`formatCnpj()` reuso), tags retenção (Retém ISS amber / Retém IRRF indigo / Sem retenção green), botão "Trocar"/"Escolher" (`onTrocar`), estado vazio, contagem auxiliar. Altura fixa (G1). Tokens `AppColors` + `withValues(alpha:)`; sem cor literal. Retenções vêm do `Tomador` (cadastro/backend), nunca inferidas. Gate leve: analyze 0 issues; 654 passed / 4 golden baseline Windows (pré-existente). Sheet busca/seleção = T2.2.
- [x] **T2.2** `showTomadorSelectorSheet()` em `tomador_selector_sheet.dart`: `showModalBottomSheet` dark (surface, top-radius 22, barrier 0.55), handle, head+X, busca `TextField` filtra por razão (substring) **ou** CNPJ (alfanum, ignora máscara — `_filtrar`), lista rolável `ListView.builder` de `_TomadorRow` (reusa `_Logo`/`_Info`/`_siglaFrom`/`_tagsRetencao` do T2.1) + `_RadioCircle` (verde+check), empty state "nenhum encontrado". `selecionadoId` marca linha; tap → `Navigator.pop(tomador)`. Rodapé `_SheetFoot` "Cadastrar" via `onCadastrar` opcional (gancho — fluxo F3); empty-vazio total + foco campo = T2.3/T2.4. Sem cor literal (tokens `AppColors`). → daa515a. Gate leve: analyze 0 issues; 654 passed / 4 golden baseline Windows (pré-existente).
- [x] **T2.3** Estado vazio total (médico sem nenhum tomador, ≠ busca sem match) em `tomador_selector_sheet.dart`: branch `semTomadores` em `_TomadorSelectorSheetState.build` esconde busca + rodapé e ocupa o corpo com `_SheetEmptyTotal` (ícone, "Nenhum tomador cadastrado", subtexto, CTA primário verde `_CadastrarPrimaryButton` → `onCadastrar`). Sem `onCadastrar` (gancho ainda não ligado — F3), cai para texto informativo "nas configurações" (sem CTA). Tokens `AppColors`, sem cor literal. `Semantics(button)` no CTA. Gate leve: analyze 0 issues; 654 passed / 4 golden baseline Windows (pré-existente).
- [ ] **T2.4** A11y: `Semantics` radio/selected, foco no campo busca ao abrir.
- [ ] **T2.5** Teste widget `test/.../tomador_selector_sheet_test.dart`: abre sheet, busca filtra (nome+CNPJ), seleção retorna tomador, empty state. Alimenta gate `flutter test`.

### F3 — Cadastro de tomador (G2) · DEP: F2 + T0.3 (ramo) · pode ser `[blocked]` (ver T0.3)
> Ramo A: cadastro inline no sheet. Ramo B1: sheet navega ao fluxo onboarding existente. Ramo B2: bloqueada (task backend).
- [ ] **T3.1** [Ramo A] Modo cadastro dentro do sheet (lista ↔ form, botão voltar). Campos: CNPJ (máscara alfanum 14-pos), razão, e-mail financeiro, endereço (`EnderecoFiscalForm` reuso), retenções ISS/IRRF. [Ramo B1] botão "Cadastrar" abre `editar_tomador_screen` e retorna o tomador criado.
- [ ] **T3.2** [Ramo A] Lookup CNPJ real (backend) — preenche razão/endereço/IBGE. Sem validar só-dígitos (alfanum jul/2026). DV não exigido no app.
- [ ] **T3.3** Salvar → POST tomador (T1.3 / Ramo A) ou retorno do onboarding (B1) → auto-seleciona + fecha sheet + toast.

### F4 — `AtendimentoCnpjFlow` orquestrador (G3,G4,G5,G6) · DEP: F1 + F2
- [ ] **T4.1** Novo `lib/features/syncview/widgets/atendimento_cnpj_flow.dart` espelhando `AtendimentoPfFlow` (StatefulWidget, cnpjProprioId/cnpjEmissor/onConcluido).
- [ ] **T4.2** Integrar `TomadorSelectorSheet` no topo.
- [ ] **T4.3** Tipos serviço cards 2×2 (Plantão `40104`?/Procedimento/Cirurgia/Honorário) — confirmar NBS oficial em `TipoServico.codigoNbs` (placeholders hoje; marcar "confirmar tabela").
- [ ] **T4.4** Valor hero + `_CurrencyInputFormatter` (extrair p/ `core/utils/formatters.dart` se reuso cross-feature).
- [ ] **T4.5** Horário início/fim condicional tipo=Plantão.
- [ ] **T4.6** Data (default hoje) + município prestação + descrição (default por tipo) + status pgto (A receber/Já recebi).
- [ ] **T4.7** Teste widget `atendimento_cnpj_flow_test.dart`: tomador+tipo+valor>0 → CTA habilita; tipo=Plantão revela horário; troca tipo oculta. Alimenta gate.

### F5 — Preview fiscal CNPJ live (G7) · DEP: F1 + F4
- [ ] **T5.1** Card preview (reusar/adaptar `preview_fiscal_pf_card.dart` → genérico ou novo `preview_fiscal_cnpj_card.dart`): valor bruto, ISS "a definir no envio"/"Não retém", IRRF idem, IBS/CBS "calculado no envio", líquido estimado = bruto.
- [ ] **T5.2** Debounce 400ms → `previewFiscalAtendimento` backend (igual PF). Falha rede → preserva último preview.
- [ ] **T5.3** Remover inferência local de alíquota do caminho CNPJ (não usar `Servico.valorIssRetido` na UI de captura). Rodapé "oficial no backend".

### F6 — Emitir + pós-salvar + resultado (G8) · DEP: F1 + F4
- [ ] **T6.1** Toggle "Emitir NFS-e agora?" + hints dinâmicas (espelhar v15 gates).
- [ ] **T6.2** Salvar via `confirmarAtendimentoCnpj` → `EmissaoConfirmacaoSheet.showPosSalvar` → `emitirNf` se confirmado (espelhar `AtendimentoPfFlow._finalizarPosSalvar`).
- [ ] **T6.3** Gates CTA: sem tomador→disabled; valor≤0→disabled; emitir off→"Registrar serviço"; on→"Confirmar e emitir NFS-e".
- [ ] **T6.4** Teste widget: gate CTA por estado; "salvar sem emitir" não chama `emitirNf`; "emitir" dispara sheet pós-salvar. Alimenta gate.

### F7 — Integração no entry-point (substituir legado) · DEP: F4 + F5 + F6
- [ ] **T7.1** `add_servico_modal.dart` modo criação CNPJ: delegar a `AtendimentoCnpjFlow` (igual PF linha 506). Remover corpo CNPJ inline do caminho criação.
- [ ] **T7.2** Preservar modo edição (decidir: migrar p/ flow novo ou manter legado isolado). Registrar decisão.
- [ ] **T7.3** Remover código morto (dropdowns/helpers só-criação) após confirmar sem uso (não remover sem confirmar impacto — CLAUDE.md).

### F8 — A11y / polish (G9) · DEP: F4–F7
- [ ] **T8.1** Semantics em toggles/cards/radio; foco visível; contraste (tokens — `textFaint` legível).
- [ ] **T8.2** Estados: vazio/foco/válido/erro/loading/sucesso tratados.

### F9 — Regressão final na develop (gate de entrega) · DEP: F1–F8
> Cada fase já passou pelo gate pesado §7.C no merge. F9 = regressão da develop integrada (todas as fases juntas).
- [ ] **T9.1** Na develop atualizada: `dart analyze` — zero issues.
- [ ] **T9.2** `flutter test` — 0 failed (inclui testes T1.4/T2.5/T4.7/T6.4).
- [ ] **T9.3** `./run_dcm.sh` em `/mnt/c/Projects/medvie/medvie-app` (WSL Ubuntu) — zero issues.
- [ ] **T9.4** `flutter build apk --debug` — sucesso.
- [ ] **T9.5** Verificar critérios de aceite §8 um a um (smoke manual do fluxo CNPJ).

---

## 7. Workflow Git + Gate de validação (2 níveis)

Regra mestra: **nenhuma fase chega na develop sem o gate pesado (§7.C) verde.** Develop = sempre buildável.
Modelo: **branch por fase**. Tasks viram commits na branch da fase (cada um passa no gate leve §7.B). Fase fechada → gate pesado → merge develop.
Racional de arquiteto: build APK + DCM são caros (minutos). Rodá-los por micro-task desperdiça tempo/tokens. Rodar 1×/fase = incremento coeso validado, develop estável, custo amortizado.

### 7.A Ciclo Git por FASE

```bash
# abrir a fase (§1 passo 3): partir da develop atualizada
git checkout develop
git pull origin develop
git checkout -b feat/cnpj-fN-<slug>        # ex: feat/cnpj-f2-tomador-selector

# ── por TASK dentro da fase ──
#   implementar task → GATE LEVE (§7.B) → verde → commit
git add -A
git commit -m "feat: <task em pt-br>"       # 1 commit por task; sem Co-Authored-By

# ── ao fechar a ÚLTIMA task da fase ──
#   GATE PESADO (§7.C) → 4/4 verdes → merge
git checkout develop
git pull origin develop
git merge --no-ff feat/cnpj-fN-<slug> -m "feat: <fase> — atendimento CNPJ"
git push origin develop
# próxima fase parte da develop atualizada (§1 reinicia)
```

### 7.B GATE LEVE (por task — rápido, segundos)

```bash
dart analyze        # zero issues
flutter test        # 0 failed
```
Falhou → corrigir antes de commitar. Não acumular débito entre tasks.

### 7.C GATE PESADO (por fase — antes do merge na develop)

Ordem. Falhou um → NÃO mergear. Corrigir na branch da fase, revalidar.

```bash
dart analyze                                              # 1. zero issues
flutter test                                              # 2. 0 failed
flutter build apk --debug                                 # 3. sucesso
cd /mnt/c/Projects/medvie/medvie-app && ./run_dcm.sh      # 4. zero issues (WSL Ubuntu)
```
Critério: 4/4 verdes = fase pode ir pra develop. Qualquer issue = reprovado.

### 7.D Exceção F0 (discovery / doc)

F0 não produz código Flutter (só lê e atualiza este `.md`). Sem branch, sem gate de build.
Commit do `.md` direto na develop: `git commit -m "docs: F0 — descoberta atendimento CNPJ"`. Marcar tasks F0 `[x]` ao documentar (não exige merge de feature).

### 7.E Notas de ambiente

- git é o do **Windows** — nunca commitar flip de CRLF (commit onde insertions==deletions só por EOL = barrar).
- Reportar erro do gate: comando + erro essencial + arquivo:linha + sugestão. Nunca colar log completo.
- Conflito no merge develop: resolver na branch da fase (`git merge develop` → resolver → revalidar gate pesado), então mergear.

---

## 8. Definição de pronto (critérios de aceite)

- [ ] Selecionar tomador CNPJ via resumo + bottom sheet busca (escala p/ N tomadores sem poluir).
- [ ] Cadastrar tomador inline (lookup CNPJ + endereço + retenções) → auto-seleciona.
- [ ] Tipo serviço sem preço; valor bruto manual c/ máscara pt-BR; chips frequentes não travam.
- [ ] Horário só em Plantão.
- [ ] Preview fiscal live do backend; UI não infere alíquota; nota "oficial no backend".
- [ ] Gates CTA corretos; emitir opcional via sheet pós-salvar; resultado c/ CNPJ mascarado.
- [ ] Paridade visual c/ protótipo v15; dark theme via tokens; mono nos valores.
- [ ] `dart analyze` + `flutter test` + `./run_dcm.sh` 100% limpos.

---

## 9. Log de progresso (append-only — uma linha por sessão)

| Data | Sessão fez | Task(s) | Branch → merge (hash) | Gate 3/3 | Próxima |
|---|---|---|---|---|---|
| 2026-06-16 | Plano criado. Estado verificado (§2), contrato backend (§3), gap v15 (§4) mapeados. Workflow git+gate (§7). Nada implementado. | — | — | — | F0.T0.1 |
| 2026-06-16 | **F0 concluída.** T0.1 6 métodos legados documentados (§3.A). T0.2 fonte tomadores (memória, sem re-fetch). T0.3 🔑 Ramo A (`cadastrarTomador` existe). T0.4 preview genérico (reusar). ⚠ fechados (§10). Doc only. | T0.1–T0.5 | develop (doc §7.D) | n/a (F0) | F1.T1.1 |
| 2026-06-16 | **F1 concluída.** T1.1 `confirmarAtendimentoCnpj`. T1.2 `previewFiscalAtendimento` (neutro). T1.3 `criarTomadorCnpj` (wrap `cadastrarTomador`, Ramo A) + `Tomador.copyWith`. T1.4 testes provider (`confirmarAtendimentoCnpj` 7 + `criarTomadorCnpj` 5). | T1.1–T1.4 | feat/cnpj-f1-provider-service → develop (171c78c) | 4/4 ✓ (test 654 pass / 4 golden baseline Windows) | F2.T2.1 |

---

## 10. Riscos / decisões em aberto

Resolvidos nesta revisão (estrutura):
- ✅ G-A (gate pesado por micro-task) → gate 2 níveis: leve/task (§7.B), pesado/fase (§7.C). Branch por fase (§7.A).
- ✅ G-B (F0 sem código vs workflow) → exceção §7.D (doc, sem branch/build).
- ✅ G-C (dependência travável) → decision gate T0.3 (ramos A/B1/B2); F2 desacoplada de cadastro; DEP: explícito por fase.
- ✅ Cobertura teste UI → tasks T2.5/T4.7/T6.4 (widget tests) alimentam o gate `flutter test`.

Fechados em F0 (2026-06-16):
- ✅ Endpoint criação tomador CNPJ standalone (T0.3) → **Ramo A**: `cadastrarTomador` [medvie_api_service.dart:294] → `POST /api/v1/servicos/tomadores`, backend `ServicoController.CadastrarTomador` [:241] testado.
- ✅ `previewFiscalPf` reuso vs novo (T0.4) → **reusar/generalizar** `POST /api/v1/atendimentos/preview` (agnóstico a tomador). Sem método CNPJ novo.

Abertos (fora do escopo F0 / fechar na fase correspondente):
- ⚠ Body `cadastrarTomador` [:297-307] NÃO envia `aliquotaIrrf`/`inscricaoMunicipal`/endereço fiscal — fechar em F3.T3.1 (estender contrato vs backend derivar).
- ⚠ NBS dos tipos CNPJ são placeholders (`servico.dart:52`). Confirmar tabela oficial antes de produção (F4.T4.3).
- ⚠ Inferência local de retenção (`_calcularPreview`/`Servico.valorIssRetido`) conflita regra backend-verdade — isolar ao caminho legado, não usar na captura nova (F5.T5.3).
- Decisão modo edição CNPJ (F7.T2): migrar vs manter legado.
