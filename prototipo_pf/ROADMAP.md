# Roadmap — Atendimento PF (protótipo v13)

Itens fora do escopo do protótipo `medvie-atendimento-pf-v13.html`, registrados para não se perderem. Cada item indica o que falta e a dependência (app, backend ou produto).

---

## 1. Aba "Empresa / Convênio" — faturamento por CNPJ (FUTURO)

**O quê**: hoje o segmento "Empresa / Convênio" é só um placeholder (card "fluxo CNPJ legado"). Construir o fluxo real de atendimento faturado por CNPJ nessa aba.

**Cobre**:
- **Plantonista Hospitalar** — sempre fatura via hospital (CNPJ). É o único perfil que não usa o fluxo PF.
- **Cirurgião / Clínico / Procedimentalista** — quando o atendimento é via convênio ou hospital (tomador CNPJ), e não particular.

**Decisão de design**: separar o fluxo por **tipo de tomador** (PF vs CNPJ) no segmento do topo, **não** por perfil de atuação. Assim não é preciso bloquear perfil no fluxo PF — quem fatura CNPJ escolhe a aba "Empresa / Convênio". O fluxo PF permanece focado em paciente particular Pessoa Física.

**Dependências**:
- App: reusar cadastro existente de tomadores CNPJ (hospitais/clínicas) — Step 3 do onboarding já cadastra para plantonista.
- Backend: contrato CNPJ legado já existe; `POST /atendimentos` aceita o caminho CNPJ.

**Status**: planejado — "depois" (confirmado pelo usuário, 2026-06-11).

---

## 2. Endpoint de lookup de tomador PF por CPF (BACKEND)

**O quê**: `POST /api/v1/atendimentos/tomador/lookup` — resolve paciente por `cpf_hash`, devolve nome + endereço + status fiscal, **sem CPF bruto**. Habilita o auto-load por CPF (CPF-first) que o protótipo já demonstra com stub local.

**Registrado em**: `medvie-api/specs/017-atendimento-pf-nfse-nacional/`
- `contracts/api-tomador-lookup.md` (proposta)
- `tasks.md` → Phase 9 (T032–T035)

**Status**: proposta aguardando implementação no backend.

---

## 3. [DECISÃO 1 — RESOLVIDA: Opção B, 2026-06-11] Contato no lookup

**Decisão**: o lookup por CPF **retorna** `email`/`telefone` do tomador para auto-preenchimento no app. Endpoint autenticado e escopado ao próprio CNPJ → ganho de UX supera o risco controlado.

**Aplicado em**:
- `contracts/api-tomador-lookup.md` — response 200 inclui contato.
- `spec.md` — Clarification Session 2026-06-11.
- `tasks.md` — T032 ajustada; **T036** criada (abrir exceção à FR-002).

**Garantias**: CPF bruto nunca no response; email/telefone nunca em logs (só no corpo do 200).

**Pendência backend**: implementar T036 (ajuste FR-002). Protótipo v13 já reflete B (preenche contato).

---

## 4. Tela "Ver nota" navegável (APP)

**O quê**: a partir da tela de resultado, abrir o detalhe da NFS-e (status, provider, código de verificação, ações). Hoje o botão "Ver nota" não navega.

**Status**: refino opcional do protótipo, ainda não feito.

---

## 5. Divergência de código NBS no backend (BACKEND — confirmar)

**O quê**: o contrato 017 usa `40111` (Consulta) no exemplo de `POST /atendimentos`, mas o exemplo de `GET /atendimentos/recentes` usa `40101`. O protótipo adota a família `40111/40112/40201/40103` (alinhada ao POST + ao prompt Flutter).

**Status**: inconsistência interna do backend a confirmar/normalizar no `medvie-api`.
