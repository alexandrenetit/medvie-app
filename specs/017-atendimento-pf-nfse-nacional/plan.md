# Implementation Plan: Atendimento PF para NFS-e Nacional no app Flutter

**Branch**: `017-atendimento-pf-nfse-nacional` | **Date**: 2026-06-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/017-atendimento-pf-nfse-nacional/spec.md`

## Summary

Evoluir o app Flutter para capturar atendimento de paciente PF em ate 30 segundos, com endereco fiscal completo antes da emissao de NFS-e Nacional, preview fiscal sem retencao PF, reaproveitamento de paciente/servico e jornada operacional em SyncView/Notas. O app consome o backend como fonte da verdade e nunca persiste CPF bruto.

## Technical Context

**Language/Version**: Dart / Flutter, null safety.

**Primary Dependencies**: Provider/ChangeNotifier ja usado, `http`, `flutter_secure_storage` apenas para token de sessao, `SharedPreferences` apenas para preferencias/cache nao sensivel.

**Storage**: Sem persistencia local de CPF bruto ou endereco completo em P0. Estado de formulario em memoria. Dados fiscais persistem no backend.

**Testing**: `dart analyze`, `flutter test`, widget tests focados, testes de modelo/service/provider; DCM via WSL/Docker.

**Target Platform**: Android/iOS Flutter.

**Project Type**: Mobile app.

**Performance Goals**: fluxo PF com ate 6 campos obrigatorios visiveis no primeiro passo; segunda captura recorrente em ate 10 segundos; sem rebuild excessivo em formulario.

**Constraints**:
- Nao alterar identidade visual.
- Nao alterar storage strategy.
- Nao logar CPF/endereco completo.
- Nao chamar ViaCEP direto do app; usar backend `/api/v1/cep/{cep}`.
- Nao mudar contrato backend sem alinhar com spec backend 017.

## Constitution Check

| Principle | Status | Notes |
|---|---|---|
| Existing architecture | PASS | Usar `MedvieApiService`, providers atuais e widgets pequenos. |
| Security/LGPD | PASS | CPF bruto somente em payload transiente. |
| Minimal changes | PASS with scope | Feature exige modelo, API service, provider e UI, mas pode ser entregue faseada. |
| UI/UX consistency | PASS | Usar `AppColors`, dark cards, chips, bottom nav e padroes atuais. |
| Testability | PASS | Business rules em models/providers/services, widget fino. |

## Project Structure

### Documentation

```text
specs/017-atendimento-pf-nfse-nacional/
  spec.md
  plan.md
  research.md
  data-model.md
  quickstart.md
  contracts/
    api-atendimento-pf.md
  tasks.md
```

### Source Code Touchpoints

```text
lib/core/models/medico.dart                 # Tomador PF + endereco fiscal
lib/core/models/servico.dart                # TomadorTipo/DocumentoMascarado em listas
lib/core/services/medvie_api_service.dart   # contratos PF/atendimento/CEP
lib/core/providers/servico_provider.dart    # criar atendimento, emitir, filas
lib/features/syncview/widgets/add_servico_modal.dart
lib/features/syncview/widgets/servico_list.dart
lib/features/notas/notas_screen.dart
lib/features/agenda/agenda_screen.dart
lib/features/onboarding/**                  # remover obrigatoriedade PF, defaults
test/**                                     # modelos, services, providers, widgets
```

Structure Decision: manter organizacao atual. Nao criar feature `pacientes` separada em P0; "Paciente" e linguagem de UI para `Tomador.tipo == CPF`.

## Phases

### Phase 0 - Contract pin and fixtures

- Pin backend contract 017 in `contracts/api-atendimento-pf.md`.
- Criar fixtures JSON PF completo, PF incompleto e CNPJ legado.
- Definir copy PT-BR para estados fiscais.

### Phase 1 - Models and validation

- Evoluir `Tomador` com `tipo`, `documentoMascarado`, `enderecoFiscal`, `enderecoFiscalCompleto`.
- Criar helpers de CPF/CEP/endereco sem persistencia local.
- Atualizar `Servico`/DTOs para `tomadorTipo` e `tomadorDocumentoMascarado`.

### Phase 2 - API service

- Atualizar `cadastrarTomador` para contrato PF completo ou endpoint atomico `criarAtendimento`.
- Garantir `buscarCep` como fonte de autofill.
- Mapear erros canonicos: CPF duplicado, endereco incompleto, sandbox indisponivel, nota rejeitada.

### Phase 3 - Provider/state

- Criar estado de fluxo PF no `ServicoProvider` ou provider coeso sem trocar state manager.
- Suportar draft, preview, confirmar, emitir, pendente de dados fiscais e reutilizar paciente.
- Garantir idempotencia via `requisicaoId`.

### Phase 4 - UX Flutter

- Refatorar `AddServicoModal` ou extrair widgets pequenos: segmented PF/CNPJ, paciente quick-add, endereco, servico, preview.
- Atualizar SyncView/Notas/Agenda/Relatorios para PF sem `tomadorCnpj`.
- Preservar cores e componentes atuais.

### Phase 5 - Tests and validation

- Unit tests de parsing/validacao.
- Service tests com mock HTTP.
- Provider tests para fluxo completo/incompleto.
- Widget tests para modal PF e preview.
- `dart analyze`, `flutter test`, DCM.

## Complexity Tracking

| Risk | Why needed | Mitigation |
|---|---|---|
| Cross-layer app change | PF atravessa modelo, API, provider e UI | Entrega faseada por story, sem mexer em auth/storage/env. |
| Backend contract dependency | App precisa do endpoint atomico/backend 017 | Contract fixture e feature flag; nao hardcodar shape nao aprovado. |
| PII third party | CPF/endereco de paciente | Sem storage local e logs sanitizados. |

## Definition of Done

- Fluxo PF completo funciona contra backend com Medvie Sandbox habilitado.
- Atendimento incompleto fica em fila sem chamar emissao.
- PF autorizada/rejeitada aparece em Notas com proxima acao.
- Testes e validacoes do repo verdes.
