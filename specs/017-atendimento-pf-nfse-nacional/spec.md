# Feature Specification: Atendimento PF para NFS-e Nacional no app Flutter

**Feature Branch**: `017-atendimento-pf-nfse-nacional`
**Created**: 2026-06-09
**Status**: Draft - pronta para `/speckit.plan` e `/speckit.tasks`
**Repo**: `medvie-app` (Flutter)
**Input**: Relatorio `C:\Projects\medvie\Roadmap\medvie-relatorio-fluxo-medicos-pf.md`, prototipo aprovado `medvie-prototipo-atendimento-pf.html`, backend `medvie-api/specs/017-atendimento-pf-nfse-nacional`.

---

## Contexto e limites de confianca

O app ja tem SyncView, Agenda, Notas, Relatorios, certificado, `AddServicoModal`, `ServicoProvider`, `NotaFiscalProvider`, `MedvieApiService.buscarCep` e uma identidade visual escura baseada em `AppColors`.

O gap de produto e que o app ainda trata `Tomador` como CNPJ recorrente. Para medicos clinicos, procedimentalistas e cirurgioes, o tomador frequente e uma pessoa fisica: o paciente particular. Esse paciente deve entrar no fluxo de atendimento, nunca no onboarding.

Regra fiscal de produto: para liberar emissao de NFS-e Nacional com tomador PF, o app MUST exigir endereco fiscal completo do tomador antes de chamar emissao. O atendimento pode ser salvo como pendente quando faltarem dados.

Fontes externas usadas na especificacao:

- GitHub Spec Kit templates: https://github.com/github/spec-kit
- Documentacao atual NFS-e Nacional, atualizada em 2026-04-17: https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/documentacao-atual
- APIs NFS-e Producao Restrita e Producao: https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/apis-prod-restrita-e-producao

---

## User Scenarios & Testing

### User Story 1 - Registrar atendimento PF em ate 30 segundos (Priority: P1)

Como medico, quero tocar em "Novo atendimento", escolher "Paciente PF", informar paciente/endereco/servico e salvar o atendimento sem perder tempo no consultorio.

Why this priority: este e o momento de valor. Sem captura rapida, o medico esquece atendimentos e o Medvie vira apenas um formulario fiscal.

Independent Test: em widget test, preencher nome, CPF sintetico, CEP, numero, servico e valor; confirmar; verificar chamada ao backend com payload PF e estado local sem CPF bruto persistido.

Acceptance Scenarios:

1. Given medico autenticado com CNPJ proprio ativo, When abre "Novo atendimento", Then o modo "Paciente PF" aparece junto de "Empresa/Convenio".
2. Given CEP valido, When o medico digita CEP e numero, Then logradouro, bairro, municipio, UF e codigo IBGE sao preenchidos via backend `/api/v1/cep/{cep}`.
3. Given endereco completo e servico valido, When confirma, Then o app cria atendimento/servico PF e exibe status "pronto para emitir".
4. Given endereco incompleto, When confirma, Then o app salva o atendimento e marca "faltam dados fiscais" sem chamar emissao.
5. Given CPF de paciente ja cadastrado no CNPJ proprio, When o medico sai do campo CPF (blur), Then o app consulta o backend e auto-preenche nome, endereco, contato e ultimo servico sem CPF bruto; paciente novo mostra "novo paciente".

---

### User Story 2 - Emitir ou enfileirar NFS-e PF com clareza fiscal (Priority: P1)

Como medico, quero ver bruto, ISS/IRRF zero para PF, IBS/CBS quando aplicavel, liquido estimado e saber se posso emitir agora ou se preciso completar dados.

Why this priority: o medico nao deve entender retencoes. O app deve traduzir a regra fiscal em uma decisao simples.

Independent Test: preview PF com tomador completo deve habilitar "Emitir NFS-e"; preview PF incompleto deve mostrar bloqueio; PF nunca mostra controles editaveis de ISS/IRRF.

Acceptance Scenarios:

1. Given tomador PF completo, When abre preview, Then `ISS retido`, `IRRF retido` e aliquotas aparecem como zero ou ocultos.
2. Given tomador PF incompleto, When abre preview, Then o CTA primario vira "Completar dados fiscais".
3. Given emissao solicitada, When backend aceita, Then app navega para Notas e mostra status `processando`.
4. Given backend rejeita por endereco fiscal, When erro retorna, Then app destaca os campos faltantes sem expor payload tecnico.
5. Given valor > 0 e endereco completo, When o medico aciona "Emitir agora", Then o app cria o atendimento (`emitirAgora=false`) e abre o `EmissaoConfirmacaoSheet` (mesmo do plantonista); a transmissao via `POST /api/v1/notas` so ocorre apos confirmacao no sheet.

---

### User Story 3 - Repeticao perfeita para consultas recorrentes (Priority: P2)

Como medico, quero repetir "mesmo paciente, mesmo servico" em um toque.

Why this priority: recorrencia e o atalho que transforma charge capture em habito diario.

Independent Test: a partir de atendimento anterior, tocar em "Repetir" cria draft com paciente mascarado, servico, valor, descricao, municipio e endereco reaproveitados.

Acceptance Scenarios:

1. Given paciente recorrente, When medico toca "Mesmo paciente, mesmo servico", Then o draft abre preenchido e sem CPF bruto visivel.
2. Given atendimento anterior com endereco completo, When repete, Then o status fiscal continua completo.
3. Given atendimento anterior sem endereco, When repete, Then o draft herda pendencia e orienta completar antes de emitir.

---

### User Story 4 - Jornada completa na SyncView e Notas (Priority: P2)

Como medico, quero enxergar a jornada inteira: atendimento capturado, dados fiscais completos, NFS-e pronta, em processamento, autorizada/rejeitada, PDF enviado, pagamento recebido e fechamento do mes.

Why this priority: o valor percebido nao e somente emitir nota; e saber o que falta para fechar o mes sem risco.

Independent Test: mocks de servicos/notas com `tomadorTipo=CPF` aparecem em cards corretos, sem quebrar quando `tomadorCnpj` vier vazio.

Acceptance Scenarios:

1. Given atendimento PF sem nota, When SyncView carrega, Then card aparece em "Prontos para emitir" ou "Pendentes de dados fiscais".
2. Given nota PF rejeitada, When Notas carrega, Then proxima acao e "Corrigir dados fiscais" ou "Reenviar", nao erro tecnico.
3. Given relatorio mensal, When ha PF e CNPJ, Then valores sao agrupaveis por tipo de tomador.

---

### User Story 5 - Onboarding sem cadastro de pacientes (Priority: P3)

Como novo medico clinico/procedimentalista/cirurgiao, quero configurar defaults de emissao e servicos comuns, sem ser obrigado a cadastrar pacientes no onboarding.

Why this priority: onboarding deve configurar o motor fiscal; paciente entra no atendimento.

Independent Test: perfil nao-plantonista conclui onboarding sem tomador obrigatorio e recebe defaults de servico.

Acceptance Scenarios:

1. Given perfil clinico, When chega ao step de tomadores, Then app mostra defaults de servico e tomadores CNPJ opcionais.
2. Given perfil plantonista, When chega ao step de tomadores, Then hospitais/clinicas recorrentes continuam disponiveis.

---

## Edge Cases

- CPF invalido, repetido, com mascara, ou divergente do paciente escolhido.
- CEP indisponivel, CEP inexistente, municipio sem codigo IBGE, ou medico precisa preencher endereco manual.
- Tomador CPF ja cadastrado e resolvido proativamente no blur do campo CPF (lookup), auto-preenchendo o cadastro existente; o submit ainda reusa por `cpf_hash` de forma idempotente.
- `TomadorCnpj` vazio em servicos PF nao pode quebrar SyncView, Agenda, Notas, Relatorios ou PDF.
- CPF bruto nao pode ir para `SharedPreferences`, logs, debugPrint, cache local, analytics ou fixtures reais.
- App offline em P0 nao salva CPF bruto. Offline criptografado fica fora de escopo desta spec.
- Feature flag backend desabilitada para PF deve ocultar ou bloquear emissao, mas ainda permitir salvar draft se backend suportar.

---

## Functional Requirements

- **FR-001**: App MUST suportar `Tomador.tipo` (`CPF` ou `CNPJ`) e `documentoMascarado` nos modelos locais.
- **FR-002**: App MUST tratar `documento` CPF bruto apenas em payload transiente de criacao/atendimento; MUST NOT persistir em storage local.
- **FR-003**: App MUST modelar endereco fiscal PF nacional: CEP, logradouro, numero, complemento, bairro, municipio, UF e codigo IBGE.
- **FR-004**: App MUST usar `MedvieApiService.buscarCep` para autofill; fallback manual deve existir quando CEP falhar.
- **FR-005**: App MUST bloquear "Emitir NFS-e agora" quando tomador PF nao tiver endereco fiscal completo.
- **FR-006**: App MUST permitir salvar atendimento PF incompleto como pendente de dados fiscais.
- **FR-007**: App MUST esconder/desabilitar retencoes ISS/IRRF para PF e mostrar zero no preview fiscal.
- **FR-008**: App MUST consumir resposta completa de atendimento/tomador quando o backend disponibilizar, evitando refetch obrigatorio.
- **FR-009**: App MUST lidar com `tomadorCnpj == null` ou vazio quando `tomadorTipo == CPF`.
- **FR-010**: App MUST preservar identidade visual atual: `AppColors`, dark theme, cards, chips, bottom nav e tipografia ja usadas.
- **FR-011**: App MUST manter paciente PF fora do onboarding; onboarding configura defaults fiscais e catalogo de servicos.
- **FR-012**: App SHOULD oferecer recentes, favoritos e "mesmo que a ultima vez" sem expor CPF bruto.
- **FR-013**: App SHOULD mostrar jornada operacional completa em SyncView/Notas/Relatorios.
- **FR-014**: App MUST posicionar o campo CPF como primeiro campo do formulario de atendimento PF (chave do paciente), antes do nome.
- **FR-015**: App MUST, ao sair do campo CPF (CPF-first) com CPF valido, consultar `POST /api/v1/atendimentos/tomador/lookup`; quando o paciente existir, auto-preencher nome, endereco, contato e ultimo servico; quando nao existir (404), indicar "novo paciente". Sem botao manual de carregar.
- **FR-016**: App MUST consumir `email`/`telefone` retornados pelo lookup (DECISAO 1 = Opcao B, backend Clarifications Session 2026-06-11) para auto-preenchimento. CPF nunca e exibido alem do mascarado e nunca persiste localmente (ver FR-002).
- **FR-017**: App MUST emitir a NFS-e PF pela MESMA mecanica ja usada para plantonista/CNPJ — `EmissaoConfirmacaoSheet` + `ServicoProvider.emitirNf` + `POST /api/v1/notas` por `servicoId`. O `POST /api/v1/atendimentos` e chamado com `emitirAgora=false` (criacao atomica idempotente de tomador PF + servico); a emissao e passo subsequente, disparado pelo sheet de confirmacao. App MUST NOT usar `emitirAgora=true`.

## Key Entities

- **Tomador**: entidade fiscal consumida pelo app. Na UI, `CPF` e chamado de Paciente; `CNPJ` e chamado de Empresa/Convenio/Hospital/Clinica.
- **EnderecoFiscalTomador**: endereco nacional completo para emissao NFS-e PF.
- **AtendimentoPfDraft**: estado local efemero da captura antes de confirmar.
- **AtendimentoFiscalPreview**: bruto, ISS, IRRF, IBS/CBS, liquido estimado e status de emissao.
- **Servico**: atendimento financeiro/fiscal ja existente, agora compativel com tomador PF.

## Success Criteria

- **SC-001**: Primeiro atendimento PF capturado em ate 30 segundos em smoke manual.
- **SC-002**: Segundo atendimento do mesmo paciente em ate 10 segundos usando repeticao.
- **SC-003**: Emissao PF nunca exibe ISS/IRRF retido diferente de zero.
- **SC-004**: CPF bruto nao aparece em storage local, logs, exceptions ou snapshots de teste.
- **SC-005**: Notas/SyncView/Relatorios nao quebram com `tomadorCnpj` vazio em PF.
- **SC-006**: `dart analyze`, testes focados e DCM ficam verdes no codigo implementado.

## Assumptions

- Backend 017 sera fonte da verdade para criacao atomica de atendimento PF e emissao via Medvie Sandbox.
- Backend 016 ja entrega base de `TipoTomador.CPF`, CPF cifrado/hash e documento mascarado.
- O auto-load por CPF (FR-014..FR-016) depende do endpoint `POST /api/v1/atendimentos/tomador/lookup` (backend 017, follow-up Phase 9, contrato `contracts/api-tomador-lookup.md`). Ate disponivel, o app degrada para preenchimento manual.
- App nao adiciona pacote novo em P0.
- O prototipo HTML aprovado guia fluxo e hierarquia, mas Flutter deve seguir componentes e temas reais do app.

## Out of Scope

- Prontuario medico, dados clinicos sensiveis ou evolucao medica.
- Agenda clinica completa.
- Offline criptografado com reenvio idempotente.
- Voz/IA para captura automatica.
- Pix, conciliacao bancaria e portal contador.
