# Handoff: SyncView Home — redesenho "Pipeline financeiro" (opção 1b)

## Overview
Redesenho da tela home do Medvie (SyncView, `medvie-app` Flutter). Substitui o layout atual (card SYNCVIEW bruto/líquido + 3 cards de contagem + calendário mensal) por uma hierarquia centrada no ciclo do dinheiro: **líquido estimado como herói → pipeline (recebido / a receber / aguardando emissão) → pendências acionáveis ("Precisa de você") → próximo plantão → bottom nav com FAB**.

Racional de produto (briefing Medvie):
- Líquido estimado é a informação nº 1, não o bruto (princípio 7 — transparência de valores).
- Pendências fiscais nunca ficam escondidas e sempre têm próxima ação objetiva (princípios 3 e 5).
- Selo de validade do CNPJ vira pill discreto; só ganha destaque quando houver problema.
- Calendário mensal sai da home (permanece na aba Agenda).
- Contadores (Confirmados/Planejados/NFs) deixam de ser cards; a informação vive no pipeline e na agenda.

## About the Design Files
Os arquivos em `design/` são **referências de design criadas em HTML** — protótipos que mostram aparência e comportamento pretendidos, NÃO código de produção. A tarefa é **recriar este design no app Flutter existente** (`C:\Projects\medvie\medvie-app`), usando os padrões já estabelecidos do projeto: Provider, cliente HTTP centralizado, organização por features, tema existente. Não portar HTML/CSS literalmente; mapear para widgets Flutter.

Abra `design/SyncView Home.dc.html` num navegador para ver as 3 opções; **implementar somente a opção 1b** (o frame do meio, rotulado `1b`). O elemento raiz da tela tem `data-screen-label="1b Pipeline financeiro"` no HTML — use-o como fonte da verdade para medidas e cores.

## Fidelity
**High-fidelity.** Cores, tipografia, espaçamentos e raios são finais e devem ser seguidos com precisão, adaptados às convenções do tema existente do app (se o tema já define esses tokens, reutilize os tokens em vez de hardcode).

## Regras arquiteturais obrigatórias (do repositório)
- Ler `CLAUDE.md` / `AGENTS.md` e instruções locais do repo antes de editar; confirmar branch e `git status`. **Nunca descartar mudanças locais.**
- Nenhuma regra tributária em widget. Todos os valores (bruto, líquido, impostos, a receber, recebido, previsões) vêm do backend via service/provider existente. O app **não calcula** — apenas apresenta.
- Fluxo: `Widget → Provider/estado → Service/Repository → API Medvie`.
- Sem novas dependências sem justificativa e aprovação. Não trocar Provider por outro state manager.
- `mounted` após `await`; dispose de controllers/listeners; modelos tipados.
- Valores monetários exibidos com JetBrains Mono; nunca logar PII.
- Tratar loading, erro, vazio e sucesso em todos os blocos.
- Alvos de toque ≥ 48px. Textos nunca cortam nem disputam espaço com FAB/nav.

## Screen: SyncView Home (opção 1b)
Tela única, dark, fundo `#07090F`, fonte de UI **Outfit**, valores monetários em **JetBrains Mono**. Estrutura vertical (coluna), sem scroll no conteúdo de referência (em telas menores, o miolo pode rolar; header e bottom nav fixos).

### 1. Header
- Padding: 14px topo, 20px laterais.
- Linha única, alinhamento central vertical, gap 12px:
  - Coluna (flex 1): mês corrente "Julho 2026" — 13px, `#94A3B8`; abaixo o nome "Dr. Alexandre Goncalves" — 19px, weight 600, letter-spacing −0.2px, `#FFFFFF`.
  - Pill "CNPJ ativo": bg `#111827`, borda 1px `rgba(255,255,255,0.06)`, radius pill, padding 6×10px; dot 7px `#00C98A` + texto 11.5px `#CBD5E1`.
    - **Estado de problema** (CNPJ com pendência/vencimento próximo): dot e texto em `#F59E0B`, texto ex.: "CNPJ · atenção". Tocar abre a tela de detalhes fiscais.
  - Avatar circular 38px, bg `#0EA5E9`, inicial 15px weight 600 cor `#07090F`.

### 2. Hero — líquido estimado
- Padding: 18px topo, 20px laterais.
- Label "LÍQUIDO ESTIMADO · JULHO" — 12px, letter-spacing 1px, `#94A3B8` (mês dinâmico, maiúsculas).
- Valor "R$ 26.601" — JetBrains Mono, 46px, weight 700, letter-spacing −1.5px, `#FFFFFF`, line-height 1.1.
- Sublinha "R$ 12.400 a receber · previsão 15/07" — 13.5px, weight 500, `#0EA5E9`. Ocultar quando a receber = 0.
- Dados: preview fiscal do backend (líquido estimado do mês, total autorizado não pago, data prevista). Loading: skeleton no valor. Erro: traço "—" + retry discreto.

### 3. Pipeline do mês
- Padding: 18px topo, 20px laterais.
- Barra segmentada: altura 12px, radius 6px, gap 3px entre segmentos; larguras proporcionais aos valores:
  - Recebido `#00C98A`
  - A receber `#0EA5E9`
  - Aguardando emissão `#F59E0B`
  - Segmento com valor 0 não aparece. **Linha de legenda com valor 0 também não aparece** (nunca renderizar "R$ 0"). Se TODOS os estágios = 0, ocultar a seção pipeline inteira e usar o estado de primeiro uso (ver "Estados vazios" abaixo).
- Legenda: 3 linhas, gap vertical 10px, margem-top 14px. Cada linha:
  - Swatch 10px, radius 3px, na cor do estágio.
  - Rótulo (flex 1) 13.5px `#CBD5E1`: "Recebido" / "A receber" / "Aguardando emissão".
  - Contagem 12px `#64748B`: "7 NFs pagas" / "2 NFs autorizadas" / "2 atendimentos".
  - Valor JetBrains Mono 14px weight 600 na cor do estágio: "R$ 14.201" / "R$ 12.400" / "R$ 3.399".
- Mapeamento de status (usar os enums/status reais do backend): Recebido = NFs pagas/conciliadas; A receber = NFs autorizadas não pagas; Aguardando emissão = atendimentos capturados ainda não emitidos (inclui `PendenteDadosFiscais` e prontos para emitir).
- Tocar numa linha navega para a lista filtrada correspondente (Notas/Atendimentos).

### 4. "Precisa de você" — pendências acionáveis
- Margem: 20px topo, 16px laterais.
- Título de seção "Precisa de você" — 13px weight 600 `#CBD5E1`, margem inferior 8px.
- Card: bg `#111827`, radius 16px, rows separadas por divider 1px `rgba(255,255,255,0.05)`.
- Cada row (padding 13×14px, gap 12px, altura de toque ≥ 48px, row inteira clicável):
  - Dot de alerta 8px `#F59E0B`.
  - Coluna (flex 1): título 13.5px weight 500 `#FFFFFF` (ex.: "Completar endereço fiscal", "NF rejeitada pelo município"); subtítulo 12px `#94A3B8` (ex.: "Maria S. · consulta · R$ 600"). **Nunca exibir CPF; nome pode aparecer, documento sempre mascarado.**
  - Ação 13px weight 600 `#0EA5E9`: "Resolver ›" / "Corrigir ›".
- Fontes de pendência: atendimentos `PendenteDadosFiscais`, NFs rejeitadas, (futuro) comprovantes não enviados. Mensagens de rejeição traduzidas em texto seguro e acionável — nunca a mensagem crua do provider.
- **Estado vazio: a seção inteira desaparece** (não renderizar título nem card vazio).
- Ações navegam para o fluxo existente correspondente (completar dados fiscais do atendimento / correção e reemissão da NF).

### 5. Próximo plantão
- Margem: 14px topo, 16px laterais.
- Título "Próximo plantão" — 13px weight 600 `#CBD5E1`, margem inferior 8px.
- Card: bg `#111827`, radius 16px, borda 1px `rgba(129,140,248,0.2)`, padding 14px, gap 12px:
  - Badge de data 44×44px, radius 12px, bg `rgba(129,140,248,0.12)`: linha 1 "HOJE" 10px weight 600 `#818CF8` (ou "SEX", "12/07"…); linha 2 hora "19h" JetBrains Mono 14px weight 700 `#818CF8`.
  - Coluna (flex 1): "Hosp. Santa Casa · 12h" 14px weight 600; "19:00 – 07:00 · plantão noturno" 12px `#94A3B8`.
  - Valor "R$ 2.400" JetBrains Mono 14px weight 600 `#CBD5E1`.
- **Fonte de dados: exclusivamente compromissos futuros da Agenda.** Nunca derivar "plantão" de NF, atendimento ou tomador — o nome de um tomador/paciente jamais aparece como plantão. Tocar abre o compromisso na Agenda.
- Sem compromisso futuro na Agenda: **ocultar a seção inteira** (título e card — não mostrar "Nenhum plantão agendado"). Se houver atividade no mês, o espaço é ocupado pela seção "Últimos lançamentos" (abaixo).

### 5b. "Últimos lançamentos" (substitui "Próximo plantão" quando a Agenda está vazia e há atividade no mês)
- Mesmo padrão de card do "Precisa de você": bg `#111827`, radius 16px, rows com divider, máx. 3 itens + "Ver todos ›".
- Row: título "Consulta · Adriana M." 13.5px weight 500; subtítulo "Hoje 09:10 · R$ 30.000 bruto" 11.5px `#64748B` (valor em JetBrains Mono); badge de status à direita (pill 999px, 11px weight 600): Autorizada `rgba(14,165,233,0.12)`/`#0EA5E9` · Paga `rgba(0,201,138,0.12)`/`#00C98A` · Processando `rgba(148,163,184,0.12)`/`#94A3B8` · Rejeitada `rgba(245,158,11,0.12)`/`#F59E0B`.

## Estados vazios (OBRIGATÓRIO — ver screenshots 2a e 2b)
**Regra geral: nenhuma seção renderiza vazia ou zerada. Seção sem dados = seção ausente.**

### Estado "primeiro uso" (mês sem NENHUM lançamento) — `design/screenshot-2a.png`
- Hero: valor "R$ 0" em `#334155` (apagado, não branco); sublinha "Seu mês começa no primeiro registro" 13.5px `#64748B`. Sem skeleton-traço.
- SEM barra de pipeline, SEM legenda, SEM "Próximo plantão", SEM "Precisa de você".
- Card-convite (margem 22px topo/16px lados; bg `#111827`, radius 20px, borda 1px `rgba(0,201,138,0.18)`, padding 22×20px): ícone documento 48×48px em container radius 14px bg `rgba(0,201,138,0.12)`; título "Registre seu primeiro atendimento" 17px weight 600; corpo "Leva menos de 30 segundos. O Medvie calcula o líquido e prepara a nota para você." 13px `#94A3B8`; botão full-width 52px radius 16px `#00C98A` texto `#07090F` 15px weight 700 "Registrar atendimento" (mesma ação do FAB).
- Row "Simular honorário" (card 16px radius, ícone calculadora `#0EA5E9`, ação "Abrir ›").
- Seção "COMO FUNCIONA" (label 12px letter-spacing 1px `#64748B`): 3 linhas com círculo numerado 24px bg `rgba(255,255,255,0.06)` (número JetBrains Mono 11.5px `#94A3B8`) + texto 13.5px `#CBD5E1`: "Você registra o atendimento ou plantão" / "O Medvie valida os dados e emite a NFS-e" / "Você acompanha tudo até o pagamento". Esta seção só existe no estado primeiro-uso.

### Estado parcial (há atividade, mas nem tudo) — `design/screenshot-2b.png`
- Pipeline: só segmentos e linhas de legenda com valor > 0 (ex.: só "A receber").
- "Precisa de você": ausente se não há pendências.
- "Próximo plantão": ausente se Agenda vazia → mostrar "Últimos lançamentos".
- Header: nome com ellipsis (nunca quebrar linha); pills não encolhem.

### 6. Bottom nav + FAB
- Manter a navegação existente do app (SyncView, Agenda, +, Notas, Relatórios). Referência visual:
  - Barra: bg `#0B0E15`, border-top 1px `rgba(255,255,255,0.06)`.
  - Item ativo: ícone + label `#00C98A`, weight 600; inativos `#64748B`; label 10.5px; ícones 20px.
  - FAB central 56px, circular, `#00C98A`, ícone “+” `#07090F`, sobreposto 26px acima da barra, sombra `0 8px 24px rgba(0,201,138,0.35)`. Ação: registrar atendimento (fluxo existente).

## Interactions & Behavior
- Pull-to-refresh na tela inteira → refetch do resumo do mês.
- Troca de mês NÃO existe nesta tela (mês corrente fixo no header); histórico fica em Relatórios.
- Transições padrão do app; sem animações novas obrigatórias. Opcional: animar largura dos segmentos do pipeline no primeiro build (200–300ms, easeOut).
- Loading inicial: skeletons (hero + barra + 2 rows). Erro de rede: estado de erro com retry, mantendo header.
- Todos os valores formatados pt-BR pelo formatter existente; valores vêm prontos do backend (decimal), sem cálculo local.

## State Management
- Reutilizar/estender o provider do SyncView existente. Estado necessário:
  - `resumoMes`: líquido estimado, bruto, impostos, aReceber (+ data prevista), recebido, aguardandoEmissao (+ contagens por estágio).
  - `pendencias`: lista tipada (tipo, título, subtítulo, rota de destino).
  - `proximoPlantao`: compromisso ou null.
  - `statusCnpj`: ok | atenção.
  - flags: loading, erro.
- Se o endpoint de resumo atual não fornecer os agregados do pipeline, **não calcular no app**: expor a lacuna e propor o contrato ao backend (fonte única da verdade).

## Design Tokens
Cores: fundo `#07090F` · surface `#111827` · nav `#0B0E15` · primária `#00C98A` · secundária `#0EA5E9` · atenção `#F59E0B` · terciária `#818CF8` · texto `#FFFFFF` / `#CBD5E1` / `#94A3B8` / auxiliar-frio `#64748B` · dividers `rgba(255,255,255,0.05–0.08)`.
Tipografia: Outfit (400/500/600/700) para UI; JetBrains Mono (600/700) para todo valor monetário e horas no badge.
Raios: cards 16px · hero-cards 20px · barra pipeline 6px · pills 999px · badge data 12px.
Espaçamento: laterais 16–20px; entre seções 14–20px; interno de card 13–18px.

## Assets
Ícones da referência são SVGs simples desenhados no protótipo (grid, calendário, documento, barras, “+”). Usar o pacote de ícones já adotado no app — não copiar os SVGs.

## Files
- `design/screenshot-1b.png` — screenshot da tela 1b (referência visual principal, 412×892).
- `design/screenshot-2a.png` — estado primeiro uso (mês sem lançamentos).
- `design/screenshot-2b.png` — estado parcial (1 NF autorizada, Agenda vazia).
- `design/SyncView Home.dc.html` — protótipo com as 3 opções; implementar a **1b** (frame com `data-screen-label="1b Pipeline financeiro"`).
- `design/android-frame.jsx`, `design/support.js` — runtime do protótipo (apenas para abrir o HTML; irrelevantes para o Flutter).
