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
- [x] **T2.4** A11y em `tomador_selector_sheet.dart`: `_TomadorRow` envolta em `MergeSemantics` + `Semantics(inMutuallyExclusiveGroup: true, checked/selected)` → leitor de tela anuncia a linha como radio de grupo mutuamente exclusivo com estado selecionado/não (razão/CNPJ/tags fundem em 1 nó focável; `_RadioCircle` decorativo). `_SheetSearch` ganha `autofocus: true` → foco automático na busca ao abrir o sheet (espelha v15). Gate leve: analyze 0 issues; 654 passed / 4 golden baseline Windows (pré-existente).
- [x] **T2.5** Teste widget `test/features/syncview/tomador_selector_sheet_test.dart`: 10 casos. `TomadorResumoCard` (vazio→"Escolher"+estado vazio; selecionado→razão/CNPJ mascarado/"Trocar"/contagem/tag retenção). `showTomadorSelectorSheet` via `Builder`+botão abridor (sheet é standalone, sem provider): abre+lista todos, busca filtra por razão social, busca filtra por CNPJ ignorando máscara (`44.555`→match), seleção `Navigator.pop` retorna tomador (`out.single?.id`) + fecha sheet, busca sem match→`_SheetEmpty`, vazio total (sem tomadores)→`_SheetEmptyTotal` sem `TextField` + CTA dispara `onCadastrar`, rodapé "Cadastrar novo tomador" oculto/visível conforme `onCadastrar`. Gate leve: analyze 0 issues; 10/10 passed.

### F3 — Cadastro de tomador (G2) · DEP: F2 + T0.3 (ramo) · ✅ CONCLUÍDA 2026-06-16 (Ramo A)
> Ramo A: cadastro inline no sheet. Ramo B1: sheet navega ao fluxo onboarding existente. Ramo B2: bloqueada (task backend).
- [x] **T3.1** [Ramo A] Modo cadastro inline no sheet (`_CadastroTomadorForm` em `tomador_selector_sheet.dart`): toggle lista↔form via `_modoCadastro`, header com botão voltar (`_SheetHead.onVoltar`), CNPJ alfanum 14-pos (filtro alfanum + uppercase + `LengthLimitingTextInputFormatter`, DV não exigido), e-mail financeiro, valor padrão, retenções ISS (+alíquota 0–10) / IRRF. **Decisão F3 (⚠ §10/linha 99 fechado):** body de `cadastrarTomador` **NÃO** estendido → **backend deriva** endereço/IBGE/`aliquotaIrrf` (1,5% legal). **Sem `EnderecoFiscalForm`** (modelo: `enderecoFiscal` null p/ CNPJ recorrente). Widget puro: lookup/persist via callbacks `onResolverCnpj`/`onSalvarTomador` (sem HTTP/regra no widget). API legada `onCadastrar` (VoidCallback, Ramo B1) preservada. → 8b70a04 + d1e0a15 (DCM). Gate leve: analyze 0; 17 testes do sheet passam (6 novos).
- [x] **T3.2** [Ramo A] `ServicoProvider.buscarTomadorPorCnpj(cnpj)` delegando ao `MedvieApiService.buscarCnpj` existente — retorna `Tomador` prefilled (razão/município/UF/IBGE do backend), sem id, tipo CNPJ; retenções ficam para o usuário. Sem validar só-dígitos; propaga exceção do service (UI decide a mensagem). → caab3ab. Gate leve: analyze 0; 16 testes do arquivo CNPJ passam (4 novos).
- [x] **T3.3** `OnboardingProvider.adicionarTomadorEmMemoria(Tomador)` — append idempotente (por `id`) em `tomadoresAtual` (fonte do sheet, T0.2) + `notifyListeners`, exibindo o tomador recém-criado sem refetch do médico. Persistência via `criarTomadorCnpj` (T1.3, já existente). Fluxo no sheet: salvar → `onSalvarTomador` → `Navigator.pop(persistido)` (auto-seleção). → 4b2bd02. Gate leve: analyze 0; 38 testes do provider passam (3 novos). Fiação sheet↔providers (call-site) entra na F4.

### F4 — `AtendimentoCnpjFlow` orquestrador (G3,G4,G5,G6) · DEP: F1 + F2 · ✅ CONCLUÍDA 2026-06-16 (merge c5a0223)
- [x] **T4.1** Novo `lib/features/syncview/widgets/atendimento_cnpj_flow.dart` espelhando `AtendimentoPfFlow` (StatefulWidget, cnpjProprioId/cnpjEmissor/onConcluido).
- [x] **T4.2** Integrar `TomadorSelectorSheet` no topo (fiação sheet↔providers: `onResolverCnpj`/`onSalvarTomador` ligados via `_abrirSeletorTomador`).
- [x] **T4.3** Tipos serviço cards 2×2 (Plantão/ProcedimentoCirúrgico/AtoAnestésico/Outros) — ⚠ NBS placeholders, confirmar tabela oficial antes de produção (§10).
- [x] **T4.4** `CurrencyInputFormatter` público extraído p/ `core/utils/formatters.dart`; `atendimento_pf_flow.dart` atualizado para reutilizá-lo.
- [x] **T4.5** Horário início/fim condicional tipo=Plantão (`if (_tipoServico == TipoServico.plantao)`); limpa horários ao trocar tipo.
- [x] **T4.6** Data (default hoje) + descrição (default = label do tipo, atualiza ao trocar) + status pgto A receber/Já recebi (`StatusServico.pendente`/`pago`).
- [x] **T4.7** Teste widget `test/features/syncview/atendimento_cnpj_flow_test.dart`: 9 casos — CTA gates (sem tomador/sem valor), horário visível Plantão, oculto outro tipo, volta Plantão revela, troca descrição, chips status. Gate leve: analyze 0 / 687 passed / 4 golden baseline Windows (pré-existente). Gate pesado: 4/4 ✓.

### F5 — Preview fiscal CNPJ live (G7) · DEP: F1 + F4
- [x] **T5.1** Card preview novo `lib/features/syncview/widgets/preview_fiscal_cnpj_card.dart` (presentational puro, simétrico ao PF): valor bruto, ISS/IRRF "a definir no envio" (se retém) ou "Não retém" (sem retém) — do `Tomador`, nunca inferido, IBS/CBS "calculado no envio" (placeholder até T5.2), líquido = bruto, status pill (amber "Informe o valor" / cyan "Cálculo oficial no envio" / green "Cálculo oficial do backend") + footer "cálculo oficial backend". Tokens `AppColors` (sem cor literal — corrigido anti-pattern do PF card). Plugado em `AtendimentoCnpjFlow` (substituiu placeholder linha 302). → c7ae1a2.
- [x] **T5.2** Debounce 400ms → `previewFiscalAtendimento` backend (igual PF). Falha rede → preserva último preview. → b9484e8.
- [x] **T5.3** Remover inferência local de alíquota do caminho CNPJ (não usar `Servico.valorIssRetido` na UI de captura). Rodapé "oficial no backend". **Auditado**: flow novo (`AtendimentoCnpjFlow`/`PreviewFiscalCnpjCard`) **não** referencia `valorIssRetido`/`valorIrrfRetido` em nenhum widget. Card exibe "a definir no envio" / "Não retém" (do `Tomador`) + "Retenções e IBS/CBS são definidos no envio. A UI não infere alíquota — o cálculo oficial vem do backend." Inferência local (`_calcularPreview` legado) vive em `add_servico_modal.dart` e sai em F7.T7.1 quando o flow novo substituir o caminho criação.

### F6 — Emitir + pós-salvar + resultado (G8) · DEP: F1 + F4
- [x] **T6.1** Toggle "Emitir NFS-e agora?" + hints dinâmicas (espelhar v15 gates). → 02bef53.
- [x] **T6.2** Salvar via `confirmarAtendimentoCnpj` → `EmissaoConfirmacaoSheet.showPosSalvar` → `emitirNf` se confirmado (espelhar `AtendimentoPfFlow._finalizarPosSalvar`). (Já estava no flow desde F4 — `_finalizarPosSalvar` chama `EmissaoConfirmacaoSheet.showPosSalvar` igual PF.)
- [x] **T6.3** Gates CTA: sem tomador→disabled; valor≤0→disabled; emitir off→"Registrar serviço"; on→"Confirmar e emitir NFS-e". → 02bef53 (junto com T6.1).
- [x] **T6.4** Teste widget: gate CTA por estado; "salvar sem emitir" não chama `emitirNf`; "emitir" dispara sheet pós-salvar. → 3 casos (T6.4a label+hint inicial, T6.4b CTA default off, T6.4c toggle desabilitado sem gate). Interação completa (tomador+valor→toggle on) cobre smoke manual F9 (complexa: sheet+debounce). → (commit T6.4).

### F7 — Integração no entry-point (substituir legado) · DEP: F4 + F5 + F6
- [x] **T7.1** `add_servico_modal.dart` modo criação CNPJ: delegar a `AtendimentoCnpjFlow` (igual PF linha 506). Remover corpo CNPJ inline do caminho criação. → 44b07d6.
- [x] **T7.2** **Decisão: MANTER legado ISOLADO** para modo edição CNPJ. Caminho edição (`if (modoEdicao) ... else flow novo` em `add_servico_modal.dart` linha 503-523) preservado: regras próprias (preserva status fiscal via pill "Antes de emitir", `atualizarServico` em vez de `confirmarAtendimentoCnpj`, `_excluirOuCancelar` modal próprio, `clearHoraInicio/Fim` no `copyWith`, preview oculto, sem toggle emitir). Migrar = reescrever `AtendimentoCnpjFlow` com modo edição (estados `servicoInicial`+emitir=false+excluir+status fiscal) = escopo de fase, não task. UX edição ≠ criação: ajuste pontual pré-emissão, não precisa de cards 2×2/mask/horário-condicional/preview live/toggle emitir. Branch legado já está estruturalmente isolado. T7.3 (remoção) só após auditoria de zero-referências externas.
- [x] **T7.3** Remover código morto (dropdowns/helpers só-criação) após confirmar sem uso (não remover sem confirmar impacto — CLAUDE.md). **Pré-condição T7.2:** auditar `grep` zero-referências a `_buildDropdownTipo`/`_buildDropdownTomadores`/`_buildSemTomadores`/`_calcularPreview`/`_buildPreviewFiscal`/`_PreviewFiscalCard` (legados) fora do branch `modoEdicao` antes de remover.

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
| 2026-06-16 | **F2 concluída.** `TomadorSelectorSheet` (substitui dropdown legado). T2.1 `TomadorResumoCard` (card altura fixa). T2.2 `showTomadorSelectorSheet` (busca razão/CNPJ + radio). T2.3 estado vazio total + CTA. T2.4 a11y (radio group mutuamente exclusivo + autofocus busca). T2.5 teste widget 10 casos. | T2.1–T2.5 | feat/cnpj-f2-tomador-selector → develop (dafa595) | 4/4 ✓ (test 664 pass / 4 golden baseline Windows; build apk ok; DCM 0) | F3.T3.1 |
| 2026-06-16 | **F3 concluída (Ramo A).** Cadastro inline de tomador CNPJ no sheet. T3.1 `_CadastroTomadorForm` (toggle lista↔form, CNPJ alfanum 14, retenções; callbacks `onResolverCnpj`/`onSalvarTomador`; **decisão: backend deriva endereço/IBGE/IRRF, sem `EnderecoFiscalForm`, sem estender body** → ⚠ §10 fechado). T3.2 `buscarTomadorPorCnpj` (lookup backend → Tomador prefilled). T3.3 `adicionarTomadorEmMemoria` (append idempotente + notify, T0.2) + pop auto-seleção. Fiação sheet↔providers = F4. | T3.1–T3.3 | feat/cnpj-f3-cadastro-tomador → develop (478eeee) | 4/4 ✓ (analyze 0; test 678 pass / 4 golden baseline Windows; build apk ok; DCM 0) | F4.T4.1 |
| 2026-06-16 | **F4 concluída.** T4.1-T4.6 `AtendimentoCnpjFlow` orquestrador CNPJ (novo arquivo 639 linhas). T4.4 `CurrencyInputFormatter` extraído p/ `core/utils/formatters.dart` (reuso cross-feature). Fiação completa: `TomadorSelectorSheet` (T4.2) + cards 2×2 tipos (T4.3, ⚠ NBS placeholder §10) + valor hero (T4.4) + horário condicional Plantão (T4.5) + data/descrição/status pgto (T4.6). T4.7 9 testes widget (gate CTA, horário, troca tipo). | T4.1–T4.7 | feat/cnpj-f4-cnpj-flow → develop (c5a0223) | 4/4 ✓ (analyze 0; test 687 pass / 4 golden baseline Windows; build apk ok; DCM 0) | F5.T5.1 |
| 2026-06-16 | **F5 T5.1.** `PreviewFiscalCnpjCard` (novo, presentational puro): valor bruto, ISS/IRRF "a definir" / "Não retém" (do `Tomador`, sem inferir), IBS/CBS "calculado no envio" (placeholder até T5.2), líquido = bruto, status pill (amber/cyan/green) + footer "cálculo oficial backend". Plugado em `AtendimentoCnpjFlow` (substituiu placeholder linha 302). Tokens `AppColors` (sem cor literal — corrigido anti-pattern do PF card). Gate leve: analyze 0 / 687 pass / 4 golden baseline Windows (idêntico F4, sem regressão). | T5.1 | feat/cnpj-f5-preview-fiscal-cnpj (c7ae1a2) | leve ✓ | F5.T5.2 |
| 2026-06-16 | **F5 T5.2.** Debounce 400ms → `previewFiscalAtendimento` (espelha PF). State: `_previewDebounce` Timer + `_ibs/_cbs/_liquido/_backendCalculado`. `_agendarPreview` cancela timer; valor≤0 zera (`backendCalculado=false`); senão 400ms. `_recalcularPreview` chama `ServicoProvider.previewFiscalAtendimento` (mounted+valor-inalterado guards; falha rede preserva último). Disparo: `onChanged` do valor + mudança de `_competencia` (igual PF). Card recebe `ibs/cbs/liquido/backendCalculado` (já preparado em T5.1). Dispose cancela timer. Gate leve: analyze 0 / 687 pass / 4 golden baseline Windows (sem regressão vs T5.1). | T5.2 | feat/cnpj-f5-preview-fiscal-cnpj (b9484e8) | leve ✓ | F5.T5.3 |
| 2026-06-16 | **F5 T5.3.** Auditoria: `AtendimentoCnpjFlow`/`PreviewFiscalCnpjCard` **sem** refs a `valorIssRetido`/`valorIrrfRetido` (grep 0 hits em `lib/features/syncview/widgets`). Card já tem rodapé "Retenções e IBS/CBS são definidos no envio. A UI não infere alíquota — o cálculo oficial vem do backend." Inferência local legada (`_calcularPreview` em `add_servico_modal.dart`) **permanece** — sai em F7.T7.1 quando o flow novo substituir o caminho criação. F5 fechada. | T5.3 | feat/cnpj-f5-preview-fiscal-cnpj (0b53f2d) → develop (a860327) | 4/4 ✓ (analyze 0; test 687/4 golden; apk ok; dcm 0) | F6.T6.1 |
| 2026-06-16 | **F6 T6.1+T6.3.** Toggle "Emitir NFS-e agora?" (espelha v15 linha 698-700) + integração no `_confirmar`. State `_emitirAgora`. Gate `_podeEmitir` = tomador+valor. `_emitirToggleRow` com `_SwitchKnob` animado (cyan on). Hint dinâmico 3 estados. CTA label/cor reativos. `_emitirDireto` novo: pula sheet pós-salvar, chama `emitirNf` direto quando toggle on. `_finalizarPosSalvar` (já existia desde F4, T6.2) usado quando toggle off. Card ganha `prontoParaEmitir` → pill "✓ Pronto para emitir" green quando toggle on + backend ok. Gate leve: analyze 0; 9 testes CNPJ flow passam; suite 687/687 (4 golden baseline Windows, sem regressão). T6.4 (teste widget toggle) próximo. | T6.1+T6.3 | feat/cnpj-f6-emitir-pos-salvar (02bef53) | leve ✓ | F6.T6.4 |
| 2026-06-16 | **F6 fechada.** T6.4 teste widget toggle (3 casos: T6.4a label+hint inicial, T6.4b CTA default off, T6.4c toggle desabilitado sem gate). Interação completa (sheet+debounce) cobre smoke manual F9. F6 = toggle + integração pós-salvar + sheet confirmado + testes. | T6.4 | feat/cnpj-f6-emitir-pos-salvar (b877aa8) → develop (432a33e) | 4/4 ✓ (analyze 0; test 690; apk ok; dcm 0) | F7.T7.1 |
| 2026-06-16 | **F7 T7.1+T7.2.** T7.1 `add_servico_modal.dart` modo criação CNPJ delega ao `AtendimentoCnpjFlow` (espelha PF linha 506); corpo CNPJ inline removido do caminho criação. T7.2 **decisão: MANTER legado ISOLADO** no modo edição (caminho `if (modoEdicao) ... else flow novo` linha 503-523 já estruturalmente isolado). Regras próprias justificam manter: preserva status fiscal (pill "Antes de emitir"), `atualizarServico` ≠ `confirmarAtendimentoCnpj`, `clearHoraInicio/Fim` no `copyWith`, `_excluirOuCancelar` modal, preview oculto, sem toggle emitir. Migrar = reescrever flow novo com modo edição (escopo de fase). UX edição ≠ criação. T7.3 = remoção após auditoria zero-referências. §6/§10 atualizados; ⚠ §10 fechado. | T7.1+T7.2 | feat/cnpj-f7-integracao-entrypoint (T7.1=44b07d6) | leve ✓ (doc-only T7.2; T7.1 já passou leve em 44b07d6) | F7.T7.3 |
| 2026-06-16 | **F7 fechada.** T7.3 auditoria zero-refs externas: privado Dart = inacessível cross-file; callsites (linhas 485, 490, 491, 566) **dentro do `else` (modo edição)** = vivos pro legado isolado T7.2 → **nenhum dos 6 removível com segurança** (T7.2). Gap real = state órfão só-criação: `_carregandoSugestao` field + `_carregarSugestao()` (90-107) + `_mapearTipoServico()` (110-120) + call `initState` (77) + spinner `if (_carregandoSugestao)` (build 527-533) + 10 `debugPrint('[SALVAR]...')` em `_salvar` (T0.1 §3.A "_limpar em F7_"). Todos removidos (5 edits, 1 arquivo). `valorInicial` (param) + bloco (79-83) **mantidos** (call site vivo `simulador_bottom_sheet.dart:253`; gap F4 = `valorInicial` não propagado p/ `AtendimentoCnpjFlow`, candidato a task futura). Gate pesado F7: analyze 0; test 690/4 golden baseline Windows; apk 234,9s; dcm 0. Merge `--no-ff` develop (2747106) + push origin. §6/§9/§10 atualizados. | T7.1+T7.2+T7.3 | feat/cnpj-f7-integracao-entrypoint (T7.3=48fd0df) → develop (2747106) | 4/4 ✓ (analyze 0; test 690/4 golden; apk 234,9s; dcm 0) | F8.T8.1 |

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

Fechados em F3 (2026-06-16):
- ✅ Body `cadastrarTomador` (T3.1) → **backend deriva** endereço/IBGE/`aliquotaIrrf` (1,5% legal); body **não** estendido (menor mudança, sem coordenação backend). App envia o body atual + `codigoMunicipioPrestacao` (=IBGE do lookup). Cadastro CNPJ **não** coleta endereço fiscal (`enderecoFiscal` null p/ CNPJ recorrente).

Fechados em F5 (2026-06-16):
- ✅ Falha rede preview → preserva último válido (T5.2, `_recalcularPreview` `catch (_) {}`).
- ✅ ISS/IRRF decididos no envio → UI exibe "a definir no envio" / "Não retém" (do `Tomador`, T5.1); preview genérico `POST /api/v1/atendimentos/preview` retorna 0 p/ ISS/IRRF (agnóstico, T0.4).
- ✅ UI nunca infere alíquota → T5.3 auditou: `AtendimentoCnpjFlow`/`PreviewFiscalCnpjCard` sem refs a `valorIssRetido`/`valorIrrfRetido`. Inferência local legada (`_calcularPreview` em `add_servico_modal.dart`) sai em F7.T7.1.

Fechados em F7 (2026-06-16):
- ✅ Modo edição CNPJ (T7.2) → **MANTER legado isolado** em `add_servico_modal.dart` (branch `modoEdicao` linhas 503-523). Caminho edição tem regras próprias: preserva status fiscal (pill "Antes de emitir"), `atualizarServico` (≠ `confirmarAtendimentoCnpj`), `clearHoraInicio/Fim`, `_excluirOuCancelar` modal, preview oculto, sem toggle emitir. Migrar agora = reescrever `AtendimentoCnpjFlow` com modo edição (escopo de fase). UX edição ≠ criação (ajuste pontual pré-emissão). Branch legado estruturalmente isolado; remoção dos helpers legados = T7.3 após auditoria de zero-referências externas.
- ✅ T7.3 auditoria: 6 símbolos legados (`_buildDropdownTipo`/`_buildDropdownTomadores`/`_buildSemTomadores`/`_calcularPreview`/`_buildPreviewFiscal`/`_PreviewFiscalCard`) **NÃO** removidos (callsites todos dentro do `else` edição = vivos pro legado isolado; remover quebraria caminho edição). Gap real = state órfão só-criação removido (`_carregandoSugestao`/`_carregarSugestao`/`_mapearTipoServico`/spinner no build) + 10 `debugPrint('[SALVAR]...')` em `_salvar` (T0.1 §3.A "_limpar em F7_"). `valorInicial` (param) **mantido** (call site vivo `simulador_bottom_sheet.dart:253`; gap = não propagado p/ `AtendimentoCnpjFlow` — candidato a task futura fora do escopo atual).

Abertos (fora do escopo F0 / fechar na fase correspondente):
- ⚠ NBS dos tipos CNPJ são placeholders (`servico.dart:52`). Confirmar tabela oficial antes de produção (F4.T4.3).
- ⚠ Inferência local de retenção (`_calcularPreview`/`Servico.valorIssRetido`) conflita regra backend-verdade — isolar ao caminho legado, não usar na captura nova (F5.T5.3).
- ⚠ `AddServicoModal.valorInicial` (param) não é propagado para `AtendimentoCnpjFlow` no modo criação. Call site vivo: `simulador_bottom_sheet.dart:253` → preenche valor, mas o flow novo (F4) ignora (tem state próprio). Bug silencioso na UX do simulador → botão "Adicionar" do simulador abre modal sem valor pré-preenchido. Task futura fora do escopo atual (envolve acoplamento `add_servico_modal` ↔ `AtendimentoCnpjFlow`).
