# Research: Atendimento PF no app Flutter

## R1 - Paciente como Tomador CPF, nao entidade local nova

**Decision**: No app, usar linguagem "Paciente" quando `Tomador.tipo == CPF`, mas manter o modelo fiscal como `Tomador`.

**Rationale**: O backend ja usa `Tomador` polimorfico. Criar `Paciente` no app em P0 duplicaria contratos e aumentaria risco de divergencia.

**Alternatives rejected**:
- Criar feature completa de pacientes: grande demais e mistura prontuario/CRM com fiscal.
- Tratar PF como CNPJ vazio: quebra UX, relatorios e validacoes.

## R2 - Endereco completo como gate de emissao, nao de captura

**Decision**: O app permite salvar atendimento com endereco incompleto, mas bloqueia emissao NFS-e PF ate completar CEP, logradouro, numero, bairro, municipio, UF e codigo IBGE.

**Rationale**: O medico nao pode perder a captura no ponto de cuidado. Ao mesmo tempo, emitir sem endereco PF completo aumenta risco de rejeicao fiscal.

## R3 - CEP via backend

**Decision**: Usar `MedvieApiService.buscarCep` (`GET /api/v1/cep/{cep}`), nao ViaCEP direto no app.

**Rationale**: Backend centraliza resiliencia, logs sanitizados, timeouts e politica de dependencia externa.

## R4 - Sem CPF bruto em storage local

**Decision**: CPF bruto vive somente em controller/form state enquanto o fluxo esta aberto e no body da request HTTPS autenticada.

**Rationale**: CPF de paciente e dado pessoal de terceiro. `SharedPreferences` nao deve receber dado fiscal sensivel.

## R5 - Repeticao usa IDs e mascaras

**Decision**: "Mesmo paciente, mesmo servico" usa `tomadorId`, `documentoMascarado`, endereco completeness e defaults do backend; nunca CPF bruto.

**Rationale**: Depois do primeiro cadastro, o app nao precisa do CPF bruto para reutilizar paciente.

## R6 - UI em AddServicoModal primeiro

**Decision**: P0 pode evoluir `AddServicoModal` com widgets extraidos, em vez de criar uma nova tela inteira.

**Rationale**: O app ja possui fluxo de captura por FAB e modal. Manter o caminho reduz risco de navegacao e treinamento do usuario.

## R7 - Medvie Sandbox como gate do backend

**Decision**: O app considera uma emissao PF valida em P0 quando backend retorna nota processando/autorizada via provider `MedvieSandbox`.

**Rationale**: O usuario solicitou sandbox Medvie; isso permite validar contrato PF/endereco sem depender de provider externo.
