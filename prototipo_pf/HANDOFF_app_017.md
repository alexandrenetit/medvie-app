# Medvie app (Flutter) — Implementar feature 017 Atendimento PF (NFS-e Nacional)

> Handoff para nova sessão. Cole o conteúdo abaixo (ou aponte este arquivo) ao iniciar.

## Contexto
App Flutter do Medvie (SaaS fiscal p/ médicos PJ). Backend .NET = fonte única da verdade; Flutter só renderiza. State: Provider. Dark theme obrigatório via AppColors. Production-final, nunca MVP.
Ler primeiro: `C:\Projects\medvie\medvie-app\CLAUDE.md` (regras inegociáveis, validação, protocolo).
Iniciar sessão com: `caveman ultra`.

## Objetivo
Implementar a feature "Atendimento PF" no app Flutter, seguindo a spec já escrita:
- `specs/017-atendimento-pf-nfse-nacional/spec.md`  (FR-001..FR-017)
- `specs/017-atendimento-pf-nfse-nacional/tasks.md`  (T010..T073)
- `specs/017-atendimento-pf-nfse-nacional/contracts/api-atendimento-pf.md`

Protótipo visual aprovado (fonte de verdade de UX/hierarquia): `prototipo_pf/medvie-atendimento-pf-v13.html`
Backlog/decisões: `prototipo_pf/ROADMAP.md`

## Estado atual (já feito)
- Protótipo v13 aprovado: CPF-first, auto-load por CPF no blur, endereço fiscal, serviço (tipo sem preço + valor manual), preview fiscal (IBS/CBS, ISS/IRRF=0), toggle emitir, sheet de confirmação de emissão, design oficial (header/syncview card/bottom nav + FAB).
- Backend `medvie-api`: feature 017 + Phase 9 (lookup) IMPLEMENTADOS e verdes (2391 testes passando). Endpoints prontos.

## Endpoints backend disponíveis (consumir, não recriar)
- `POST /api/v1/atendimentos`  (emitirAgora=false) — cria/reusa tomador PF + serviço, idempotente por requisicaoId. 201/409/422.
- `POST /api/v1/atendimentos/tomador/lookup`  `{ cnpjProprioId, documento }` — auto-load CPF-first. 200 `{tomadorId, tipo, documentoMascarado, nome, email, telefone, enderecoFiscalStatus, endereco{...}, ultimoServico{tipoServico,codigoNbs,descricao,competencia}}` · 404 `Tomador.NaoEncontrado` · 422 `Tomador.Cpf.Invalido`.
- `POST /api/v1/notas`  (por servicoId+tomadorId+cnpjProprioId) — EMISSÃO.
- `GET /api/v1/cep/{cep}` — autofill endereço.
- `GET /api/v1/servicos` — lista (campos PF: tomadorTipo, tomadorDocumentoMascarado, tomadorEnderecoFiscalStatus, tomadorCnpj null).
- `GET /api/v1/atendimentos/recentes?cnpjProprioId=&limite=` — recentes (clone client-side).

## Decisões de arquitetura travadas
1. CPF é o PRIMEIRO campo. Auto-load no blur via lookup; existe → preenche nome/endereço/CONTATO/defaults; não existe → "novo paciente". Sem botão manual.
2. DECISÃO 1 = B: lookup retorna email/telefone (consumir no auto-load). CPF nunca em storage local/logs; só mascarado na UI.
3. Emissão PF = MESMA mecânica do plantonista: `POST /atendimentos` com emitirAgora=false (cria serviço) → `EmissaoConfirmacaoSheet` → `ServicoProvider.emitirNf` → `POST /notas`. NUNCA usar emitirAgora=true. (FR-017)
4. Valor sempre digitado pelo médico (tipo de serviço não carrega preço).
5. CNPJ/convênio (plantonista) = aba "Empresa/Convênio", FUTURO (fora deste escopo).
6. Reusar componentes oficiais: AppColors, bottom nav + FAB (`shared/widgets/bottom_nav.dart`, `syncview/widgets/add_servico_fab.dart`), `app_header.dart`, `syncview_card.dart`, `emissao_confirmacao_sheet.dart`.

## Ordem de implementação (tasks.md)
1. Phase 2 — models: T010 (`medico.dart`: TipoTomador, documentoMascarado, EnderecoFiscalTomador, enderecoFiscalCompleto), T011 (`servico.dart`: tomadorTipo/documentoMascarado/enderecoFiscalStatus, tolerar tomadorCnpj null), T012/T013 testes.
2. Phase 3 — service: T020 (DTOs POST /atendimentos), T024 (lookupTomadorPorCpf), T022 (mapear erros), T023 testes.
3. Phase 4 — provider: T030 (draft PF, CEP, confirmar, sem CPF persistido), T031 (emissão reusa emitirNf+sheet, emitirAgora=false), testes.
4. Phase 5 — UX: T040 (`add_servico_modal`: segmento PF/CNPJ, CPF-first), T044 (auto-load no blur), T042 (ISS/IRRF ocultos PF), testes.

## Regras (CLAUDE.md)
- Sem chamada externa direta (CEP/CPF sempre via backend). Sem hardcode cor/URL/texto. Apenas pacotes oficiais Google/Flutter. `str_replace`, nunca `sed -i`. Arquivo completo c/ caminho na linha 1. Validar `mounted` após `await`. `const` onde possível. Máx 3 arquivos/iteração. Protocolo antes de editar (o quê/arquivos/risco → aguardar "pode ir").
- Validação final: `dart analyze` (0), `flutter test` (0 failed), `./run_dcm.sh` em `/mnt/c/Projects/medvie/medvie-app` (WSL).

## Primeiro passo
Ler CLAUDE.md raiz + spec.md + tasks.md. Depois propor protocolo da Phase 2 (models) e aguardar "pode ir".
