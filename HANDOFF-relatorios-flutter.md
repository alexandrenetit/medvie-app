# Handoff — Alinhar Relatórios do App Flutter ao Protótipo Web

> Criado em 11/07/2026. Objetivo: alinhar `lib/features/relatorios/relatorios_screen.dart`
> à referência já validada no protótipo web (commit `ac84d44` em `develop`).
> Escopo: **apenas a tela de Relatórios do app Flutter**. Não tocar no backend.

---

## 1. Contexto

O protótipo web passou por auditoria fiscal cruzando briefing + contrato do backend .NET
+ fontes oficiais (EC 132/2023, LC 214/2025, LC 224/2025, LC 116/2003). Resultado: o
protótipo virou a **referência mais correta** de apresentação da composição tributária.

O app Flutter e o protótipo **já usam o mesmo contrato de carga do backend**
(`DashboardResponse.carga`). A divergência restante é de **apresentação e texto**, não de
dados — exceto 1 erro factual (Tarefa 1).

**Prioridade**: T1 (alta) → T2 (média) → T3 (média) → T4 (baixa).

---

## 2. Contrato do backend (fonte única — já disponível no app)

`lib/core/models/dashboard_response.dart`:

- **`DashboardResponse.totalIbs` / `totalCbs`** (linhas 6-7) — somatório do **destaque
  IBS/CBS nas notas autorizadas** do mês. **É esta a fonte do "destaque informativo 2026".**
- **`DashboardResponse.carga`** (`CargaTributaria`, linha 106) — carga do regime:
  `irpj, adicionalIrpj, csll, pis, cofins, iss, ibs, cbs, totalImpostos, aliquotaEfetiva,
  liquidoPosImpostos, regimeDescricao`.

### ⚠️ GOTCHA crítico (não errar)
O backend `CargaTributariaCalculator` **zera `carga.ibs` e `carga.cbs` em 2026**
(fase de teste neutra — `AnoTesteIbsCbsNeutro = 2026`). Portanto:

- Para exibir **IBS/CBS destacados (0,1% / 0,9%)** → usar **`dashboard.totalIbs` / `totalCbs`**.
- **NÃO** usar `carga.ibs` / `carga.cbs` para isso — vêm **zero** em 2026.
- `carga.totalImpostos` **não inclui** IBS/CBS em 2026 (correto — são informativos).

---

## 3. Tarefas

### T1 — [ALTA] Corrigir erro factual "IBS/CBS alíquota zero em 2026"

**Arquivo**: `lib/features/relatorios/relatorios_screen.dart:649-655`
(`_InfoRow` dentro de `_BreakdownTributario`).

**Hoje** (ERRADO):
```
'Suas notas já estão em conformidade com a Reforma Tributária (LC 214/2025). '
'IBS e CBS estão com alíquota zero em 2026 — transição gradual a partir de 2027.'
```

**Problema normativo**: em 2026 IBS/CBS **não são "alíquota zero"** — são **IBS 0,1% + CBS
0,9%**, destacados na NFS-e como **informativo**, com **dispensa de recolhimento** cumprindo
as obrigações acessórias (LC 214/2025, arts. 343 e 348, §1º). "Dispensa de recolhimento"
≠ "alíquota zero". O médico lê "zero" e não entende o destaque na nota.

**Fazer**: trocar o texto e mostrar os valores reais destacados (de `totalIbs`/`totalCbs`).
Texto sugerido:
```
'Suas notas já seguem a Reforma Tributária (LC 214/2025). Em 2026, IBS (0,1%) e '
'CBS (0,9%) aparecem na nota apenas como destaque informativo, sem recolhimento — '
'não reduzem o seu líquido. Passam a valer na transição a partir de 2027.'
```
Opcional (recomendado): adicionar um bloco com os valores `totalIbs` / `totalCbs` do mês,
com tag "REFORMA · INFORMATIVO", espelhando o card do protótipo.

**Fonte**: [RFB — Orientações 2026](https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/reforma-tributaria-do-consumo/orientacoes-2026)
· [LC 214/2025](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm).

---

### T2 — [MÉDIA] Agrupar composição por natureza (renda × consumo × reforma)

**Arquivo**: `relatorios_screen.dart:602-674` (`_BreakdownTributario`,
`_itensLucroPresumido` :667-673, `_itensSimplesNacional` :661-665).

**Hoje**: lista **plana** — IRPJ, CSLL, PIS, COFINS, ISS misturados. Não deixa claro o
que a reforma altera.

**Fazer**: agrupar como no protótipo (`prototipo_web/src/pages/Relatorios.tsx`,
`FechamentoMensal` + `GrupoTributo`):

- **Sobre a renda** *(não muda com a reforma)*: IRPJ, CSLL
- **Sobre o consumo** *(substituídos pela reforma)*: ISS (→ IBS até 2033), COFINS e PIS
  (→ CBS em 2027)
- **Reforma · fase de teste 2026** *(bloco separado, tag INFORMATIVO)*: IBS 0,1% + CBS 0,9%
  — de `totalIbs`/`totalCbs`, **fora do total de impostos**

Rótulos por linha (do protótipo):
- IRPJ — "15% s/ 32% da receita"
- CSLL — "9% s/ 32% da receita"
- ISS — "Municipal · vira IBS até 2033"
- COFINS — "Extinta em 2027 · vira CBS"
- PIS — "Extinto em 2027 · vira CBS"

**Fonte carga**: Lei 9.249/1995 (presunção 32%, IRPJ 15%, CSLL 9%), Lei 9.718/1998
(PIS/COFINS cumulativo). Transição: EC 132/2023.

---

### T3 — [MÉDIA] Rever `_CalculoTributario` client-side (briefing §8)

**Arquivo**: `relatorios_screen.dart:20-97` (classe `_CalculoTributario`),
usada em `_calcAliquotaMedia` :1030-1041 (chamadas :1036 e :1039), como **fallback** do
Resumo Anual quando o backend não respondeu.

**Problema**: o briefing §8 veta "Fator R, DAS e Anexo III/V sem escopo e fonte normativa
específicos". A classe calcula Fator R + Anexo III/V + IRPJ presumido **no cliente**. Tem
fonte citada (LC 123/2006, RIR/2018, LC 224/2025), mas o cálculo roda no widget e pode
**divergir do backend**.

**Fazer** (escolher uma):
1. **Preferido**: remover o fallback client-side; sem carga do backend → mostrar estado
   "carregando/indisponível" em vez de número estimado. Backend = fonte única (briefing §4).
2. **Alternativa**: manter, mas rotular explicitamente como **"estimativa offline"** na UI
   sempre que o número não vier do backend, para nunca ser lido como apuração.

**Nota**: no fluxo principal (mensal) os valores JÁ vêm do backend (`carga.*`,
`relatorios_screen.dart:354-357`) — a classe só age no fallback anual. Confirmar que o
resumo anual tem `RelatorioAnualProvider` cobrindo o caso normal antes de remover.

---

### T4 — [BAIXA] Avaliar exibir os dois líquidos (caixa × real)

**Contexto**: o protótipo mostra **dois** líquidos:
- **Líquido após impostos** (`carga.liquidoPosImpostos`) — o que sobra de verdade (herói).
- **Líquido após retenções** (bruto − ISS/IRRF retido) — caixa imediato.

Hoje o app mostra só o "após impostos". **Decisão de produto** — avaliar se vale o segundo
número na tela de Relatórios ou se fica só na captura do atendimento. Baixa prioridade;
não bloqueia T1-T3.

---

## 4. Validação (obrigatória antes de finalizar — CLAUDE.md)

```powershell
# Windows
dart analyze          # zero issues
flutter test          # 0 failed
flutter build apk --debug   # só ao final

# DCM via WSL Ubuntu-24.04
wsl --cd /mnt/c/Projects/medvie/medvie-app -e ./run_dcm.sh   # zero issues
```

Tarefa só concluída com `dart analyze`, `flutter test` e `./run_dcm.sh` 100% limpos.

---

## 5. Riscos / pontos de atenção

- **Não** derivar IBS/CBS de `carga.ibs`/`carga.cbs` (zero em 2026) — usar `totalIbs`/`totalCbs`.
- Preservar o comportamento nullable de `carga`/`pipeline` (backend legado → UI degrada).
- Cores/tipografia via `AppColors` e Outfit/JetBrains Mono — nunca literal (design system).
- Máx. edições cirúrgicas; não trocar Provider nem arquitetura.
- Backend **não** muda nesta tarefa. Se decidir alterar o contrato (ex.: expor IBS/CBS
  destaque dentro de `carga`), isso é tarefa separada (spec + `CargaTributariaDto`).

---

## 6. Checklist de conclusão

- [ ] T1 — texto IBS/CBS corrigido + valores de `totalIbs`/`totalCbs` exibidos
- [ ] T2 — composição agrupada por natureza (renda/consumo/reforma)
- [ ] T3 — `_CalculoTributario` fallback removido ou rotulado "estimativa offline"
- [ ] T4 — decisão sobre dois líquidos (implementar ou registrar "fica para depois")
- [ ] `dart analyze` limpo · `flutter test` 0 failed · `./run_dcm.sh` limpo
- [ ] Comparação visual lado a lado com o protótipo (porta 5175, aba Relatórios)

---

## 7. Referências

- Protótipo (referência): `prototipo_web/src/pages/Relatorios.tsx` (`FechamentoMensal`),
  `prototipo_web/src/data/mock.ts` (bloco carga), `prototipo_web/src/types.ts`
  (`CargaTributaria`). Commit `ac84d44`.
- Backend: `CargaTributariaCalculator` (zera IBS/CBS em 2026), `DashboardHandler`
  (`TotalIbs`/`TotalCbs` = soma do destaque das notas).
- Fontes oficiais: [EC 132/2023](https://www.planalto.gov.br/ccivil_03/constituicao/emendas/emc/emc132.htm)
  · [LC 214/2025](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp214.htm)
  · [LC 224/2025](https://www.planalto.gov.br/ccivil_03/leis/lcp/lcp224.htm)
  · [RFB — Reforma do Consumo](https://www.gov.br/receitafederal/pt-br/acesso-a-informacao/acoes-e-programas/programas-e-atividades/reforma-tributaria-do-consumo/entenda).
