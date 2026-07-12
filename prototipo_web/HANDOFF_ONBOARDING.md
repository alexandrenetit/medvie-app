# Handoff — Onboarding do protótipo web Medvie

> Objetivo: portar o fluxo de onboarding do app Flutter (mobile) para o protótipo
> web (`prototipo_web/`) com a melhor UX web possível, **sem sair dos padrões já
> existentes do protótipo**. 100% simulado (sem backend), como o resto do protótipo.
>
> Este documento é o guia de implementação task a task. Cada task é fechada,
> valida sozinha no dev server, e cabe em ≤3 arquivos por iteração. Ao concluir
> uma task, marque `[x]` no checklist e siga para a próxima.

---

## 1. Contexto

O protótipo web (`prototipo_web/`) é um SPA isolado — Vite + React 18 + TS +
Tailwind + framer-motion + lucide-react + recharts. Dados 100% mockados
(`src/data/mock.ts`). Tema **claro**. Hoje tem 9 telas (Login + 8 telas do app
dentro do `AppShell`). **Não existe onboarding no web ainda** — só no Flutter.

O app Flutter tem o onboarding funcional em `lib/features/onboarding/`, desenhado
para **mobile** (`PageView` de rolagem vertical, AppBar + barra de progresso no
topo). Funciona bem no celular, mas é o padrão errado para desktop web (cramped,
sem orientação espacial, um passo por vez sem visão do todo).

### Fluxo do Flutter (fonte de verdade do conteúdo/campos)

| Página | Título | Conteúdo | Observações |
|--------|--------|----------|-------------|
| 1a | Dados Pessoais | nome, CPF (máscara), CRM + UF (dropdown), e-mail, telefone (máscara), senha (+ indicador de força), confirmar senha | UF: 27 estados. Força: fraca (<8) / média / forte (nº + especial) |
| 1b | Como você atua? | 4 cards de perfil de atuação (radio) | Clínico · Procedimentalista Ambulatorial · Plantonista/Prestador Hospitalar · Cirurgião Hospitalar |
| 1c | Especialidade | busca + lista selecionável | Lista já existe: `especialidades` em `src/data/domain.ts` |
| 2a | Seu CNPJ | input CNPJ + "Consultar" → card resultado (razão social, situação, porte, município/UF, abertura) + Inscrição Municipal + Regime Tributário (dropdown) + card explicador dinâmico do regime | Modo manual (fallback quando RF indisponível). Alerta se situação ≠ ATIVA |
| 2b | Assinatura Digital | 2 cards de método (Certificado A1 / Procuração gov.br) + card explicador dinâmico + botão "anexar certificado A1" (só quando A1) | |
| 3 | Tomadores | **só Plantonista** — form: CNPJ, valor padrão (opcional), e-mail financeiro (opcional), toggle Retém ISS? (+alíquota 0–10%), toggle Retém IRRF? (+alíquota 0,1–5%, padrão 1,5%) + lista de tomadores adicionados com badges de retenção | Emite "buscando na Receita Federal…" ao adicionar |
| 4 | Confirmação | card do médico + 1 card por CNPJ (resumo: cnpj, razão, município, regime, badge do método de assinatura + status, lista de tomadores) + "Adicionar outro CNPJ" + "Concluir" | |
| 5 | Sucesso | ícone check animado (elasticOut) + "Tudo configurado, Dr. {nome}!" + chips de resumo (nº CNPJs, nº tomadores) + "Começar a usar" | |

Regra de negócio-chave: **passo Tomadores (3) só aparece para Plantonista**
(`PerfilAtuacao.plantonistaHospitalar`). Progresso e navegação devem refletir isso.

### Referências de código Flutter (leitura, não portar 1:1)

- Orquestrador: `lib/features/onboarding/onboarding_screen.dart`
- Steps: `lib/features/onboarding/screens/step{1a,1b,1c,2a,2b,3,4,5}_*.dart`
- Widgets: `.../widgets/group_selection_card.dart`, `.../widgets/password_strength_indicator.dart`

---

## 2. Conceito de UX web — "Split Wizard"

Reaproveitar a **assinatura visual do Login** (`src/pages/Login.tsx`): tela
dividida em duas colunas.

- **Coluna esquerda — Rail (dark navy `sidebar` `#0B1524`)**
  - Stepper **vertical persistente**: passos numerados, atual destacado,
    concluídos com check, linha de progresso conectando.
  - Copy curta de reforço/confiança por passo (ex.: "Seus dados fiscais são
    protegidos").
  - Logo Medvie no topo (`<Logo onDark />` ou `<LogoMark />`).
  - **Adapta a contagem**: quando perfil = Plantonista, o passo "Tomadores"
    entra na lista; caso contrário some.
  - Orientação espacial sempre visível = padrão SaaS moderno (Stripe, Linear,
    Vercel). Resolve o principal problema da versão mobile no desktop.

- **Coluna direita — Painel do passo (canvas claro)**
  - Passo ativo, largura confortável (~`max-w-lg`), respiro generoso.
  - 1 CTA primário (`Button`) + secundário "Voltar" (`variant="ghost"`).
  - Transições entre passos com framer-motion (slide + fade), respeitando
    `prefers-reduced-motion`.
  - `Enter` avança quando válido; autofocus no primeiro campo de cada passo.

- **Responsivo**: em telas estreitas (`< lg`), rail vira uma barra de progresso
  horizontal compacta no topo (stepper colapsado), painel ocupa 100%.

### Entrada / saída

- Nova rota **`/onboarding`**, **fora do `AppShell`** (irmã de `/login`).
- Link no Login: "Criar minha conta" / "Primeiro acesso" → `/onboarding`.
- Sucesso ("Começar a usar") → `navigate('/')` (dashboard).

### Estado

- Máquina de estado **local ao `Onboarding.tsx`** (`useState`/`useReducer`) —
  não precisa entrar no `AppState` global. É um fluxo efêmero e simulado.
- Shape sugerido (`OnboardingData`): `{ dados, perfil, especialidade, cnpjs[],
  cnpjEmEdicao }`. Guardar o suficiente para renderizar a Confirmação e o Sucesso.

---

## 3. Padrões do protótipo — NÃO desviar

Design system (ver `tailwind.config.js`, `src/index.css`, `CLAUDE.md` raiz):

- **Tema claro**. `canvas #F6F7F9` · `card #FFFFFF` · rail dark `sidebar #0B1524`.
- **Marca (verde)**: `brand-600 #059669` (ação), escala `brand-50…700`.
- **Info** azul `info-500 #2E8FE6` · **Warn** âmbar `warn-500` · **Danger** `danger-500`.
- **Texto**: `ink` / `ink-soft` / `ink-muted` / `ink-faint`.
- **Fontes**: `font-sans` (Inter) UI · `font-brand` (Outfit) títulos · `font-mono`
  (JetBrains Mono) valores/documentos — usar classe `.num` para números/CNPJ/CPF.
- **Nunca** cor/dimensão/fonte literal fora dos tokens. Nunca `style` com hex
  exceto o gradiente decorativo já usado no Login (padrão existente).

Componentes a **reusar** (não recriar):

- `components/ui/Button.tsx` — `variant: primary|ghost|outline|danger`, `size: sm|md`
- `components/ui/Field.tsx` — `<Field label hint error required>` + `<Input>` + `<Select>`
- `components/ui/Segmented.tsx` — toggles segmentados
- `components/ui/Card.tsx` — `<Card>` + `<CardHeader title subtitle icon action>`
- `components/ui/Progress.tsx` — `<ProgressBar value max>` + `<Delta>`
- `components/ui/StatusChip.tsx` — chips de status por tom
- `components/Logo.tsx` — `<Logo>` / `<LogoMark>` (aceita `onDark`)
- `data/domain.ts` — `especialidades`, `regimeMeta`, `statusCertificadoMeta`, `toneClasses`
- `lib/cn.ts` — `cn()` (merge de classes) · `lib/format.ts` — `money`, `dataBR`

Convenções: framer-motion **sem** `React.StrictMode` (já está off em `main.tsx` —
gotcha do `AnimatePresence` documentado lá; manter assim). HashRouter. Comentários
em pt-BR curtos no topo de cada arquivo, como no resto do projeto.

---

## 4. Estrutura de arquivos alvo

```
src/
  pages/
    Onboarding.tsx                 # orquestrador: state machine + layout split + transições
  components/
    onboarding/
      StepRail.tsx                 # rail dark: stepper vertical + progresso (+ colapsado mobile)
      SelectionCard.tsx            # card radio keyboard-native (perfil, assinatura)
      PasswordStrength.tsx         # indicador de força de senha (web)
      CnpjResultCard.tsx           # card animado do resultado da consulta CNPJ
      steps/
        StepDados.tsx              # 1a
        StepAtuacao.tsx            # 1b
        StepEspecialidade.tsx      # 1c
        StepCnpj.tsx               # 2a
        StepAssinatura.tsx         # 2b
        StepTomadores.tsx          # 3 (condicional)
        StepConfirmacao.tsx        # 4
        StepSucesso.tsx            # 5
  data/
    onboardingMock.ts              # consulta CNPJ fake, perfis de atuação, helpers
```

Editar: `src/App.tsx` (rota `/onboarding`), `src/pages/Login.tsx` (link de entrada).

> Nota: a divisão em `steps/` mantém cada arquivo pequeno e a regra de ≤3 arquivos
> por iteração viável. `Onboarding.tsx` só orquestra; a lógica de cada passo mora
> no seu arquivo.

---

## 5. Tasks

Ordem obrigatória (dependência). Cada task: confirmar `pode ir` → implementar →
validar no dev server → marcar `[x]`.

### [x] T1 — Fundação (rota + mock + shell + entrada) ✅

> Concluída. Arquivos: `data/onboardingMock.ts` (perfis, `consultarCnpjFake`,
> máscaras CNPJ, tipos `OnboardingData`/`CnpjOnb`/`TomadorOnb`, `mostrarTomadores`),
> `pages/Onboarding.tsx` (state machine + split layout + rail placeholder + stubs),
> `App.tsx` (rota `/onboarding` fora do AppShell), `Login.tsx` (link "Criar minha
> conta"). Validado: navegação avançar/voltar, branching Plantonista (rail passa de
> 6→7 passos, Tomadores aparece), link do Login roteia e reseta. tsc + eslint limpos.

- Criar `data/onboardingMock.ts`:
  - `perfisAtuacao`: 4 itens `{ id, titulo, subtitulo, icon }` (usar ícones lucide).
    ids alinhados ao enum Flutter: `medicoClinico`, `procedimentalistaAmbulatorial`,
    `plantonistaHospitalar`, `cirurgiao`.
  - `consultarCnpjFake(cnpj): Promise<CnpjLookup>` — resolve após ~700ms (latência
    simulada, padrão do Login). Retorna razão social, nome fantasia, situação
    (ATIVA), porte, município/UF, abertura. 1–2 CNPJs conhecidos + fallback genérico.
  - Tipos locais do onboarding (`OnboardingData`, `CnpjLookup`, `MetodoAssinatura`,
    `PerfilAtuacaoId`). Reusar `RegimeTributario` de `@/types`.
- Criar `pages/Onboarding.tsx` (shell): state machine com passos, layout split
  (rail placeholder à esquerda + painel à direita renderizando um passo stub),
  navegação `avancar`/`voltar`, cálculo da lista de passos considerando
  Plantonista. Ainda sem os steps reais (stubs "em construção").
- `App.tsx`: adicionar `<Route path="/onboarding" element={<Onboarding />} />`
  fora do `AppShell`.
- `Login.tsx`: adicionar link "Criar minha conta"/"Primeiro acesso" → `/onboarding`.
- **Aceite**: `/#/onboarding` abre; layout dividido; avançar/voltar funciona entre
  stubs; link do Login navega; sem erros no console.

### [x] T2 — StepRail (stepper vertical dark) ✅

> Concluída. Arquivos: `components/onboarding/StepRail.tsx` (aside dark, stepper
> vertical com conector, estados pendente/atual/concluído+check, rail copy só no
> ativo, "Passo X de N", `hidden lg:flex`), `pages/Onboarding.tsx` (substitui rail
> placeholder por `<StepRail>`, barra de progresso do topo vira `lg:hidden` =
> mobile-only). Validado: transição de estado ao avançar (concluído→check, ativo
> revela railCopy), contagem 6↔7 com Plantonista, responsivo confirmado por JS
> (`aside display:none` + `topbar display:block` em 375px). tsc + eslint limpos.
> Nota: um erro transiente de HMR apareceu durante a edição de imports; sumiu no
> reload limpo (render sem erro fresco).

- Criar `components/onboarding/StepRail.tsx`: coluna dark (`bg-sidebar`), Logo no
  topo, stepper vertical (índice, título, estado: pendente/atual/concluído com
  check `brand`), linha conectora com progresso, copy de reforço por passo.
- Recebe `passos`, `indiceAtual` via props. Adapta quando Plantonista (passo
  Tomadores presente/ausente).
- Versão mobile (`< lg`): stepper horizontal compacto no topo (pode ser
  `ProgressBar` + "Passo X de N" + título atual).
- Integrar no `Onboarding.tsx` (substituir placeholder do rail).
- **Aceite**: rail mostra passo atual, concluídos e restantes; muda ao avançar;
  responsivo; contagem correta com/sem Plantonista.

### [x] T3 — Passo Dados + Atuação ✅

> Concluída. Arquivos novos: `components/onboarding/PasswordStrength.tsx` (regra do
> app: <8 fraca / nº+especial forte / senão média), `SelectionCard.tsx` (radio
> acessível role=radio+aria-checked, reusável em Atuação/Assinatura),
> `StepShell.tsx` (contrato `StepProps` + `StepHeader` + `StepFooter` — cada step é
> dono do rodapé e valida antes de `avancar`), `steps/StepDados.tsx` (1a: campos +
> máscaras CPF/telefone inline + validação inline + força de senha + form Enter),
> `steps/StepAtuacao.tsx` (1b: radiogroup de perfis). Editado `pages/Onboarding.tsx`
> (render por switch, `StepProps`, remove StepStub; stubs restantes usam
> StepHeader/StepFooter; sucesso stub com CheckCircle2). Validado no browser:
> validação bloqueia avanço + mostra erros; máscaras (`529.982.247-25`,
> `(11) 98844-2071`); força "Senha Forte"; Plantonista → rail 6→7 + Continuar
> habilita; Voltar preserva todos os dados. tsc + eslint limpos.

- `components/onboarding/PasswordStrength.tsx`: barra + label (Fraca/Média/Forte),
  mesma regra do Flutter (`<8` fraca; nº+especial forte; senão média). Tons
  `danger`/`warn`/`brand`. Anima largura.
- `components/onboarding/SelectionCard.tsx`: card radio acessível (`role="radio"`,
  `aria-checked`, focável, Enter/Space seleciona, hover/focus states), ícone +
  título + subtítulo + indicador de seleção. Reusável em Atuação e Assinatura.
- `steps/StepDados.tsx` (1a): `Field`+`Input` para nome, CPF (máscara), CRM +
  `Select` UF, e-mail, telefone (máscara), senha + `PasswordStrength`, confirmar.
  Validação inline (`Field error`). Máscaras CPF/telefone: helpers simples locais.
- `steps/StepAtuacao.tsx` (1b): grid/coluna de `SelectionCard` para os 4 perfis.
- Ligar no orquestrador; persistir no `OnboardingData`.
- **Aceite**: validação bloqueia avanço; força de senha reage; seleção de perfil
  define se Tomadores aparecerá; dados persistem ao voltar.

### [~] T4 — Passo Especialidade + CNPJ (código pronto; verificação interativa parcial)

> Implementada. Arquivos: `data/onboardingMock.ts` (+`cnpjEmEdicao` no
> `OnboardingData`, +`novoCnpjOnb`), `components/onboarding/CnpjResultCard.tsx`
> (sucesso/alerta/erro, animado, `dataBR`), `steps/StepEspecialidade.tsx` (1c: busca
> + lista filtrável + gating), `steps/StepCnpj.tsx` (2a: `consultarCnpjFake` +
> `CnpjResultCard` + Inscrição Municipal + Regime `Segmented` + explicador dinâmico
> Simples/Presumido c/ IBS/CBS 2026). Wire em `pages/Onboarding.tsx` (switch).
> Validado: build de produção + tsc + eslint limpos; especialidade renderiza live
> (Passo 3/7, busca + 13 itens, Continuar gated). Revisão estática adicional corrigiu
> o resultado/CTA antigos que permaneciam válidos ao editar o CNPJ após a consulta.
> PENDENTE: dirigir filtro/seleção de especialidade e a consulta de
> CNPJ→card→inscrição→regime. Nova tentativa em 12/07/2026 bloqueada porque o runtime
> do browser não expôs nenhum backend disponível (`[]`).

- `components/onboarding/CnpjResultCard.tsx`: card de resultado (verde sucesso)
  com razão social, situação (badge), porte, município/UF, abertura; variante de
  alerta (âmbar) se situação ≠ ATIVA; variante de erro (danger). Anima entrada.
- `steps/StepEspecialidade.tsx` (1c): input de busca + lista filtrável de
  `especialidades` (domain.ts), item selecionável com check. Empty state.
- `steps/StepCnpj.tsx` (2a): input CNPJ (`.num`, máscara) + `Button` "Consultar"
  (loading) → `consultarCnpjFake` → `CnpjResultCard`. Após sucesso: `Field`
  Inscrição Municipal + `Select`/`Segmented` Regime Tributário + card explicador
  dinâmico do regime (Simples/Presumido — copy do Flutter, incluindo IBS/CBS 2026).
- **Aceite**: busca filtra; consulta mostra loading→resultado; regime troca o
  explicador; campos obrigatórios bloqueiam avanço.

### [~] T5 — Passo Assinatura + Tomadores (código pronto; browser pendente)

> Implementada. Arquivos: `steps/StepAssinatura.tsx` (métodos A1/gov.br,
> explicador, upload simulado + toast), `steps/StepTomadores.tsx` (consulta fake,
> valor/e-mail, retenções, lista, remoção e skip) e wire em `pages/Onboarding.tsx`.
> Build de produção + tsc + eslint limpos. Verificação interativa pendente porque
> o runtime do browser não expôs backend disponível.

- `steps/StepAssinatura.tsx` (2b): 2 `SelectionCard` (Certificado A1 / Procuração
  gov.br) + card explicador dinâmico + botão "Anexar certificado A1" (só A1;
  upload **simulado** → toast, padrão de `Perfil.tsx`).
- `steps/StepTomadores.tsx` (3): **renderizado só se Plantonista**. Form: CNPJ,
  valor padrão (opcional), e-mail financeiro (opcional), toggle Retém ISS?
  (+alíquota) e Retém IRRF? (+alíquota, padrão 1,5%) — reusar `Toggle` estilo
  `Perfil.tsx`. "Adicionar tomador" (loading "buscando na Receita Federal…") →
  lista com badges de retenção (`StatusChip`/chip). Remover item. Pode pular.
- **Aceite**: método de assinatura muda explicador; Tomadores só aparece p/
  Plantonista; adicionar/remover tomador funciona; retenções refletidas na lista.

### [~] T6 — Confirmação + Sucesso (código pronto; browser pendente)

> Implementada. Arquivos: `steps/StepConfirmacao.tsx` (médico + CNPJs + assinatura
> + tomadores, multi-CNPJ), `steps/StepSucesso.tsx` (spring, reduced-motion, resumo)
> e consolidação/navegação em `pages/Onboarding.tsx`. Build de produção + tsc +
> eslint limpos. Verificação interativa pendente pelo mesmo bloqueio do browser.

- `steps/StepConfirmacao.tsx` (4): `Card` do médico (nome, CPF mascarado, CRM-UF,
  especialidade) + 1 `Card` por CNPJ (cnpj, razão, município, regime, badge
  método+status, tomadores) + "Adicionar outro CNPJ" (volta ao passo CNPJ) +
  "Concluir".
- `steps/StepSucesso.tsx` (5): ícone check animado (framer-motion, spring) +
  "Tudo configurado, Dr. {primeiroNome}!" + chips de resumo (nº CNPJs, nº
  tomadores) + `Button` "Começar a usar" → `/`. Confetti-lite opcional
  (framer-motion), respeitando reduced-motion.
- **Aceite**: confirmação reflete dados reais do fluxo; adicionar outro CNPJ
  reinicia o mini-fluxo de CNPJ; sucesso navega ao dashboard.

### [~] T7 — Polish (código pronto; browser pendente)

> Implementada em iterações de até 3 arquivos: transições direcionais com
> `AnimatePresence`, `useReducedMotion`, foco pós-transição, Enter contextual,
> autofocus, `aria-live`/`aria-current`, rail sticky, CTAs e retenções responsivos,
> proteção contra overflow horizontal. Build de produção + tsc + eslint limpos.
> Falta somente a auditoria visual/interativa desktop + mobile.

- Transições de passo com `AnimatePresence` (slide+fade direcional avançar/voltar).
- `prefers-reduced-motion`: desliga animações (já há `@media` global em index.css;
  garantir que framer-motion respeita via `useReducedMotion`).
- Teclado: `Enter` avança quando passo válido; foco gerenciado ao trocar passo
  (autofocus primeiro campo); ordem de tab correta; `aria-live` para loading.
- Responsivo final: rail colapsado `< lg`, painel fluido, sem overflow horizontal.
- Revisar contraste (WCAG AA), estados hover/focus/disabled, textos pt-BR.
- **Aceite**: navegação por teclado completa; sem motion se reduzido; mobile e
  desktop limpos; `npm run lint` sem erros novos; `tsc -b` limpo.

---

## 6. Validação (cada task)

Rodar o dev server via ferramenta de preview (nunca `flutter`/backend — é web puro):

```
npm --prefix prototipo_web install   # 1ª vez
# dev server: usar preview_start (.claude/launch.json) apontando p/ vite
```

Checklist por task:
- `/#/onboarding` abre sem erro no console.
- Comportamento da task conferido no browser (interações reais).
- `npm run lint` e `tsc -b` sem erros novos.
- Sem cor/fonte/dimensão hardcoded fora dos tokens.

---

## 7. Gotchas / decisões travadas

- **Sem StrictMode** (main.tsx) — não reintroduzir; quebra ciclo de exit do
  `AnimatePresence`.
- **HashRouter** — rotas via `#/...`. Primeira carga sem hash cai em `#/login`.
- **Tudo simulado** — nenhuma chamada real. Consulta CNPJ e "Receita Federal" são
  `setTimeout`. Upload de certificado é toast, como em `Perfil.tsx`.
- **Tomadores condicional** — regra de negócio real: só Plantonista. Não relaxar.
- **Regime Lucro Real** existe em `regimeMeta` mas o Flutter só oferece Simples/
  Presumido no onboarding — manter só esses dois no seletor.
- **CPF/valores monetários** sempre com `.num` (JetBrains Mono).
- Este arquivo (`HANDOFF_ONBOARDING.md`) é temporário de implementação; pode ser
  removido quando o onboarding estiver concluído e validado.

---

## 8. Progresso

- [x] T1 — Fundação ✅
- [x] T2 — StepRail ✅
- [x] T3 — Dados + Atuação ✅
- [~] T4 — Especialidade + CNPJ (código pronto; verificação interativa parcial)
- [~] T5 — Assinatura + Tomadores (código pronto; browser pendente)
- [~] T6 — Confirmação + Sucesso (código pronto; browser pendente)
- [~] T7 — Polish (código pronto; browser pendente)

_Atualize este checklist ao fechar cada task._
