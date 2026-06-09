# Tasks: Atendimento PF para NFS-e Nacional no app Flutter

**Input**: Design documents from `specs/017-atendimento-pf-nfse-nacional/`

**Prerequisites**: [spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/api-atendimento-pf.md](./contracts/api-atendimento-pf.md)

**Tests**: Required for models, API service, provider state and critical widgets.

**Organization**: Tasks grouped by user story to enable independent implementation.

## Format

- `[P]`: can run in parallel.
- `[US#]`: user story.
- Every implementation task names exact files.

## Phase 1 - Setup and fixtures

- [ ] T001 Create branch `codex/017-atendimento-pf-nfse-nacional`.
- [ ] T002 Add JSON fixtures under `test/fixtures/atendimento_pf/`: `tomador_pf_completo.json`, `tomador_pf_incompleto.json`, `servico_pf_lista.json`.
- [ ] T003 [P] Add contract pin note in `specs/017-atendimento-pf-nfse-nacional/contracts/api-atendimento-pf.md` with backend commit before implementation PR.

## Phase 2 - Models and pure validation

- [ ] T010 [US1] Edit `lib/core/models/medico.dart`: add `TipoTomador`, `documentoMascarado`, `EnderecoFiscalTomador`, PF parsing and computed `enderecoFiscalCompleto`.
- [ ] T011 [US1] Edit `lib/core/models/servico.dart`: add `tomadorTipo`, `tomadorDocumentoMascarado`, `tomadorEnderecoFiscalStatus`; tolerate missing `tomadorCnpj`.
- [ ] T012 [P] [US1] Add tests in `test/core/models/tomador_pf_test.dart`.
- [ ] T013 [P] [US1] Add tests in `test/core/models/servico_pf_test.dart`.

## Phase 3 - API service

- [ ] T020 [US1] Edit `lib/core/services/medvie_api_service.dart`: add request/response DTOs for `POST /api/v1/atendimentos`.
- [ ] T021 [US1] Edit `lib/core/services/medvie_api_service.dart`: update `cadastrarTomador` to support `tipo/documento/endereco` only if backend endpoint remains needed.
- [ ] T022 [US1] Edit `lib/core/services/medvie_api_service.dart`: map `Tomador.EnderecoFiscal.Incompleto`, `Tomador.Cpf.Duplicado`, sandbox provider errors to safe app messages.
- [ ] T023 [P] [US1] Add service tests in `test/core/services/medvie_api_service_atendimento_pf_test.dart`.

## Phase 4 - Provider state

- [ ] T030 [US1] Edit `lib/core/providers/servico_provider.dart`: add PF draft lifecycle, CEP lookup orchestration, confirm atendimento and no local persistence of CPF.
- [ ] T031 [US2] Edit `lib/core/providers/servico_provider.dart`: add `emitirAtendimentoPf`/status transitions and idempotent `requisicaoId`.
- [ ] T032 [P] [US1] Add provider tests in `test/core/providers/servico_provider_atendimento_pf_test.dart`.
- [ ] T033 [P] [US2] Add provider tests for incomplete address and emission block.

## Phase 5 - UX flow

- [ ] T040 [US1] Edit `lib/features/syncview/widgets/add_servico_modal.dart`: add segmented PF/CNPJ mode, PF quick-add, address step, service step and preview.
- [ ] T041 [US1] Extract small widgets only if file grows too much: `paciente_pf_form.dart`, `endereco_fiscal_form.dart`, `preview_fiscal_pf_card.dart`.
- [ ] T042 [US2] Hide/disable ISS/IRRF controls for PF and show zero retentions in preview.
- [ ] T043 [P] [US1] Add widget tests in `test/features/syncview/add_servico_modal_pf_test.dart`.

## Phase 6 - Operational surfaces

- [ ] T050 [US4] Edit `lib/features/syncview/widgets/servico_list.dart`: display PF rows with patient name/documento mascarado and fiscal status chip.
- [ ] T051 [US4] Edit `lib/features/notas/notas_screen.dart`: handle PF notes, correction CTA and missing `tomadorCnpj`.
- [ ] T052 [US4] Edit `lib/features/agenda/agenda_screen.dart`: use neutral tomador label.
- [ ] T053 [P] [US4] Add targeted widget/model tests for PF rows.

## Phase 7 - Repetition and defaults

- [ ] T060 [US3] Add "Mesmo paciente, mesmo servico" action using `tomadorId`, last service, value, description and municipality.
- [ ] T061 [US5] Edit onboarding step for tomadores/defaults so non-plantonist profiles are not forced to add patients.
- [ ] T062 [P] [US3] Add tests for repeat flow without raw CPF.

## Phase 8 - Validation

- [ ] T070 Run `dart analyze`.
- [ ] T071 Run `flutter test`.
- [ ] T072 Run `wsl --cd /mnt/c/Projects/medvie/medvie-app -e ./run_dcm.sh`.
- [ ] T073 Run manual smoke from [quickstart.md](./quickstart.md).

## Dependencies

- Phase 2 blocks Phase 3-7.
- Phase 3 and backend 017 contract block emission.
- Phase 4 blocks UI integration.
- Phase 5 can start after PF draft/provider skeleton.
