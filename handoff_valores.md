# handoff_valores.md — Gaps de valores (SyncView ↔ Card ↔ NFS-e)

> Handoff multi-sessão. Cada bloco = 1 sessão coesa. Fonte: análise tributária + code map (fluxo PF `atendimento_pf_flow`).

---

## Protocolo obrigatório por sessão

Iniciar toda sessão com:

```
caveman ultra
```

Ferramentas:
- **serena** — navegação simbólica (`find_symbol`, `find_referencing_symbols`, `replace_symbol_body`). Chamar `initial_instructions` no início.
- **codegraph** — `codegraph_explore` (fonte verbatim), `codegraph_callers`/`callees`/`impact` antes de editar.
- Ler [CLAUDE.md](CLAUDE.md) raiz no início. Backend .NET = fonte única da verdade; Flutter só renderiza.

Antes de editar: protocolo 3 linhas (o quê / arquivos / risco), aguardar `pode ir`.

Validação p/ fechar bloco (100% limpo):
1. `dart analyze` — zero issues
2. `flutter test` — 0 failed
3. `./run_dcm.sh` (WSL Ubuntu-24.04) — zero issues

Máx. 3 arquivos por iteração. Editar via `str_replace`/serena, nunca `sed -i`. Arquivo entregue completo, caminho na linha 1.

---

## Contexto raiz (ler antes de qualquer bloco)

Tela do print = fluxo PF. Prestador = PJ **LucroPresumido**; tomador = paciente PF (não retém fonte).

Duas superfícies leem backends diferentes e discordam:

| Superfície | Fonte | Mostra | Correto? |
|---|---|---|---|
| Card lançamento | `previewFiscalAtendimento.liquidoEstimado` | R$ 30.000 | ❌ = bruto |
| SyncView "LÍQUIDO EST." | `dashboard.carga.liquidoPosImpostos` | — (null) | ❌ null |
| SyncView "A receber" | `dashboard.totalLiquidoEstimado` | R$ 0 | ❌ deveria = bruto |

Líquido real PJ LucroPresumido médico, R$ 30.000/mês (~13,3%):

| Tributo | Base/alíq | Valor |
|---|---|---|
| IRPJ | 32% × 15% | 1.440 |
| CSLL | 32% × 9% | 864 |
| PIS | 0,65% | 195 |
| COFINS | 3% | 900 |
| ISS Resende | ~2% | 600 |
| **Total** | **~13,3%** | **~3.999** |

**Líquido real ≈ R$ 26.001.** (Equiparado hospitalar 8%/12% → ~27.600. Ainda < 30k.)

---

## BLOCO 1 — SyncView caixa imediato (Flutter puro · baixo risco) ⬅ PRÓXIMO

**Objetivo:** "A receber" e refresh in-memory funcionarem sem depender de backend novo.

Gaps: **G2** (A receber R$ 0) + **G4** (fluxos não atualizam dashboard).

Arquivos:
- [lib/features/syncview/widgets/syncview_card.dart](lib/features/syncview/widgets/syncview_card.dart) — `:194` `aReceber = dashboard.totalLiquidoEstimado`
- [lib/core/providers/servico_provider.dart](lib/core/providers/servico_provider.dart) — `confirmarAtendimentoPf` `:460`, `confirmarAtendimentoCnpj` `:560` NÃO chamam `atualizarComTotais` (comparar com `adicionarServico` `:161-170`)

Ação:
1. G4 — em `confirmarAtendimentoPf`/`confirmarAtendimentoCnpj`, ler totais do `response` (`brutoAcumuladoMes`/`liquidoEstimadoMes`/`metaMensal`) e chamar `_dashboardRef?.atualizarComTotais(...)`, igual `adicionarServico`. Confirmar via codegraph que backend retorna esses campos no POST desses fluxos (senão marcar dependência backend).
2. G2 — "A receber" com tomador PF (retenção 0) deve = bruto, não 0. Definir: `totalLiquidoEstimado` do backend está errado, OU o Flutter deve exibir bruto quando não há retenção. Preferir corrigir na origem (backend). Se backend, mover G2 → BLOCO 2 e deixar só G4 aqui.

Risco: duplo-disparo dashboard (`_skipCount`). Verificar contador ao adicionar `atualizarComTotais`.

Aceite: após salvar atendimento PF, "A receber" reflete valor sem retenção; sem GET redundante.

---

## BLOCO 2 — Carga tributária pós-regime (backend .NET = fonte) 🔒 backend

**Objetivo:** SyncView "LÍQUIDO EST." mostrar líquido real pós-impostos (~26k), não "—".

Gaps: **G3** (`carga` null no dashboard) + **G1** (líquido = bruto, ignora regime).

Arquivos Flutter (só contrato/render — NÃO inventar cálculo):
- [lib/core/models/dashboard_response.dart](lib/core/models/dashboard_response.dart) — `CargaTributaria` já existe (`:48`), tolera null
- [lib/features/syncview/widgets/syncview_card.dart](lib/features/syncview/widgets/syncview_card.dart) `:193`
- [lib/features/syncview/widgets/preview_fiscal_pf_card.dart](lib/features/syncview/widgets/preview_fiscal_pf_card.dart) — `liquido` recebido do backend

Dependência: **backend deve popular `carga` no `GET /dashboard`** e `liquidoEstimado` no preview refletindo IRPJ/CSLL/PIS/COFINS/ISS do regime. Flutter só valida `fromJson` + render quando `carga != null`.

Ação Flutter: garantir que quando backend enviar `carga`, o "—" some e mostre `liquidoPosImpostos`; `regimeDescricao` visível. Remover fallback `_liquido == 0 ? _bruto` de [atendimento_pf_flow.dart:341](lib/features/syncview/widgets/atendimento_pf_flow.dart) que mascara "backend não respondeu".

Risco: não hardcodar alíquota no Flutter (viola CLAUDE.md). Bloqueado até backend entregar contrato.

Aceite: LÍQUIDO EST = líquido real do backend; nunca = bruto num PJ LucroPresumido.

---

## BLOCO 3 — Reforma 2026→2027 (competência-aware) 🔒 backend p/ documento

**Objetivo:** IBS/CBS constarem na NFS-e e rótulo não mentir a partir de 2027.

Gap: **G5**.

Arquivos:
- [lib/features/syncview/widgets/preview_fiscal_pf_card.dart](lib/features/syncview/widgets/preview_fiscal_pf_card.dart) `:89` — texto hardcoded *"não reduzem o líquido"*
- [lib/features/syncview/widgets/preview_fiscal_cnpj_card.dart](lib/features/syncview/widgets/preview_fiscal_cnpj_card.dart) `:116` — texto análogo
- Render da NFS-e (localizar via codegraph: campos IBS/CBS no documento)

Regra fiscal:
- 2026 = ano-teste: IBS 0,1% + CBS 0,9% (total 1%), compensável PIS/COFINS → informativo OK.
- **2027+**: CBS extingue PIS/COFINS e reduz líquido. Rótulo travado = bomba-relógio.

Ação: texto do rótulo derivado da competência (backend deve informar fase), não string fixa. IBS/CBS informativos no documento emitido (backend gera; Flutter renderiza se vier no contrato).

Risco: regra fiscal no Flutter proibida. Fase/valores vêm do backend.

Aceite: rótulo correto por competência; IBS/CBS visíveis na NFS-e quando backend enviar.

---

## BLOCO 4 — Classificação fiscal do serviço (Flutter) · médio risco

**Objetivo:** tipo→enum backend→NBS corretos e descrição coerente.

Gaps: **G6** (mapeamento) + **G7** (descrição não acompanha tipo).

Arquivos:
- [lib/core/models/servico.dart](lib/core/models/servico.dart) — `backendEnumName` `:74` (`procedimentoCirurgico`→`'ProcedimentoEndoscopico'` `:83`); `codigoNbs` `:52` (todos `'40119'` `:55,57,61,65`)
- [lib/features/syncview/widgets/atendimento_pf_flow.dart](lib/features/syncview/widgets/atendimento_pf_flow.dart) `:416` — descrição só reescreve `if trim().isEmpty`

Ação:
1. G6 — validar com backend o enum/NBS correto de cada `TipoServico`. `ProcedimentoEndoscopico` p/ "Procedimento Cirúrgico" e NBS único `40119` p/ todos = errado. Corrigir mapeamento (contrato backend = verdade).
2. G7 — ao trocar tipo, atualizar descrição se ela ainda for o label do tipo anterior (não só se vazia). Preservar edição manual do usuário.

Risco: enum divergente do backend quebra emissão. Confirmar contrato antes.

Aceite: 3 telas (card/sheet/NFS-e) mostram o mesmo tipo; NBS correto por serviço.

---

## BLOCO 5 — Município nome na NFS-e (Flutter render) · baixo risco

**Objetivo:** exibir `municipio_nome`, nunca código IBGE cru.

Gap: **G8** (print: "Município prestação 3304201").

Arquivos: render da NFS-e (localizar via codegraph: `municipio`/`codigoIbge`/`3304201`). CLAUDE.md: *"exibir municipio_nome, nunca código IBGE cru"*.

Ação: trocar código IBGE por nome ("Resende/RJ"). Backend deve enviar `municipio_nome`; se não, marcar dependência.

Aceite: documento sem código IBGE cru.

---

## Controle de progresso

Legenda: ⬜ pendente · 🔄 em andamento · ✅ concluído · 🔒 bloqueado (backend)

| Bloco | Gaps | Camada | Status | Sessão/data | Notas |
|---|---|---|---|---|---|
| 1 — SyncView caixa | G4 | Flutter | ✅ | 2026-07-01 | G4-CNPJ feito; G4-PF → 🔒 (contrato `/atendimentos` sem totais); G2 migrou p/ B2 |
| 2 — Carga pós-regime | G1, G2, G3 | Backend+Flutter | 🔒 | — | espera `carga` no `GET /dashboard`; **G2**: `totalLiquidoEstimado`=0 no tomador PF (sem retenção) — corrigir na origem, não forçar `bruto` no Flutter |
| 3 — Reforma 26→27 | G5 | Backend+Flutter | 🔒 | — | rótulo por competência |
| 4 — Classificação | G6, G7 | Flutter | ⬜ | — | confirmar enum/NBS backend |
| 5 — Município | G8 | Flutter | ⬜ | — | confirmar `municipio_nome` no contrato |

**Próximo gap a tratar:** BLOCO 4 (G6/G7 — Flutter, confirmar enum/NBS backend) ou BLOCO 5 (G8 — município). B2/B3 bloqueados por backend.

### Log de conclusão

> Cada sessão: marcar bloco, preencher data + commit hash + o que mudou.

- **2026-07-01 · BLOCO 1 (G4) · commit `be6cf92`** — `lib/core/providers/servico_provider.dart`:
  - **G4-CNPJ (feito):** `confirmarAtendimentoCnpj` lê `brutoAcumuladoMes/liquidoEstimadoMes/metaMensal` do response de `POST /servicos` e chama `atualizarComTotais` (fast-path in-memory + `_skipCount++` suprime GET redundante), igual `adicionarServico`.
  - **G4-PF (🔒 backend):** `confirmarAtendimentoPf` usa `POST /atendimentos`; DTO `AtendimentoPfResponse` NÃO expõe totais mensais. Fast-path não aplicável sem backend incluir totais no contrato. PF segue refrescando via listener (GET) — sem regressão. Dependência documentada inline no provider.
  - **G2 (→ BLOCO 2):** "A receber"=R$0 no tomador PF é `totalLiquidoEstimado` errado na origem (backend). Forçar `aReceber=bruto` no Flutter = regra fiscal no cliente (viola CLAUDE.md). Migrado p/ B2.
  - Validação: `dart analyze` 0, `flutter test` 712 pass, `run_dcm.sh` 0 issues.

---

## Regras de atualização deste arquivo

- Ao concluir bloco: status → ✅, preencher "Log de conclusão" (data, commit, arquivos), atualizar "Próximo gap".
- Descoberta de dependência backend: status → 🔒 + nota do que falta no contrato.
- Novo gap descoberto: adicionar ao bloco coeso existente ou criar bloco novo.
- Não apagar histórico do log.
