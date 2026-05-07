# DCM Issues Report

Data/hora da execucao: 2026-05-07 14:10:02 -03:00

Comando executado:

```bash
docker compose up -d dcm
./run_dcm.sh
```

Resumo pendente apos validacao em 2026-05-07:

| Criticidade | Quantidade |
| --- | ---: |
| Critico | 0 |
| Alto | 34 |
| Medio | 3 |
| Baixo | 7 |
| Total | 44 |

## Issues

| Criticidade | Regra DCM | Arquivo:linha | Motivo | Acao recomendada |
| --- | --- | --- | --- | --- |
| Concluido (Critico) | use-setstate-synchronously | lib/features/agenda/agenda_screen.dart:736 | `setState` apos async gap podia executar com widget desmontado. | Corrigido com checagem `mounted`; nao aparece no DCM atual. |
| Concluido (Critico) | use-setstate-synchronously | lib/features/agenda/agenda_screen.dart:1310 | `setState` apos async gap podia executar com widget desmontado. | Corrigido com checagem `mounted`; nao aparece no DCM atual. |
| Concluido (Critico) | use-setstate-synchronously | lib/features/agenda/agenda_screen.dart:1331 | `setState` apos async gap podia executar com widget desmontado. | Corrigido com checagem `mounted`; nao aparece no DCM atual. |
| Concluido (Critico) | use-setstate-synchronously | lib/features/profile/profile_screen.dart:447 | `setState` apos async gap podia executar com widget desmontado. | Corrigido com checagem `mounted`; nao aparece no DCM atual. |
| Concluido (Critico) | use-setstate-synchronously | lib/features/syncview/widgets/add_servico_modal.dart:176 | `setState` apos async gap podia executar com widget desmontado. | Corrigido com checagem `mounted`; nao aparece no DCM atual. |
| Concluido (Critico) | use-setstate-synchronously | lib/features/syncview/widgets/add_servico_modal.dart:198 | `setState` apos async gap podia executar com widget desmontado. | Corrigido com checagem `mounted`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/models/medico.dart:319 | `dynamic` em lista de tomadores reduzia validacao estatica na borda de dados. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/models/medico.dart:399 | `dynamic` em lista de CNPJs reduzia validacao estatica na borda de dados. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/models/perfil_atuacao.dart:39 | `dynamic` em model reduzia validacao estatica na borda de dados. | Corrigido com `Object?` em desserializacao robusta; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/providers/relatorio_anual_provider.dart:50 | `dynamic` em lista de tomadores reduzia validacao estatica na borda de dados. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/providers/relatorio_anual_provider.dart:81 | `dynamic` em lista de meses reduzia validacao estatica na borda de dados. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/services/medvie_api_service.dart:314 | `dynamic` em service/API enfraquecia contrato com backend. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/services/medvie_api_service.dart:390 | `dynamic` em cache de especialidades enfraquecia contrato com backend. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/services/medvie_api_service.dart:405 | `dynamic` em lista de especialidades enfraquecia contrato com backend. | Corrigido com `List<Object?>`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/services/medvie_api_service.dart:545 | `dynamic` em service/API enfraquecia contrato com backend. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/services/medvie_api_service.dart:547 | `dynamic` em service/API enfraquecia contrato com backend. | Corrigido junto com a tipagem da lista de servicos; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-dynamic | lib/core/services/medvie_api_service.dart:579 | `dynamic` em lista de notas fiscais enfraquecia contrato com backend. | Corrigido com `List<Object?>` e conversao explicita para JSON object; nao aparece no DCM atual. |
| Concluido (Alto) | no-empty-block | lib/features/agenda/agenda_screen.dart:669 | Bloco vazio no listener de `setState` apenas disparava rebuild do preview fiscal. | Corrigido com estado explicito para o valor bruto do preview; nao aparece no DCM atual. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1096 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1477 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1818 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1903 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/auth/auth_screen.dart:188 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/notas/notas_screen.dart:953 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/notas/notas_screen.dart:1073 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | no-empty-block | lib/features/onboarding/screens/step1a_dados_screen.dart:283 | Bloco vazio pode esconder fluxo incompleto ou erro engolido. | Confirmar intencao; remover bloco ou tratar caminho explicitamente. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1a_dados_screen.dart:323 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1b_grupo_screen.dart:114 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1c_especialidade_screen.dart:155 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1c_especialidade_screen.dart:193 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step2a_cnpj_screen.dart:186 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step2a_cnpj_screen.dart:336 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step3_tomadores_screen.dart:393 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step3_tomadores_screen.dart:530 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step4_confirmacao_screen.dart:197 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step4_confirmacao_screen.dart:218 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/profile/editar_tomador_screen.dart:332 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:378 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:598 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:1164 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:1285 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/syncview/syncview_screen.dart:117 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | no-empty-block | lib/features/syncview/widgets/add_servico_modal.dart:78 | Bloco vazio pode esconder fluxo incompleto ou erro engolido. | Confirmar intencao; remover bloco ou tratar caminho explicitamente. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/syncview/widgets/add_servico_modal.dart:555 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/syncview/widgets/add_servico_modal.dart:689 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/features/syncview/widgets/add_servico_modal.dart:720 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/main.dart:108 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/main.dart:150 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/main.dart:206 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/main.dart:258 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/shared/widgets/pdf_viewer_sheet.dart:95 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Alto | avoid-passing-async-when-sync-expected | lib/shared/widgets/pdf_viewer_sheet.dart:126 | Callback async passado onde assinatura espera sync; erro async pode escapar fluxo esperado. | Separar handler sync e chamar metodo async controlado. |
| Medio | avoid-shrink-wrap-in-lists | lib/features/agenda/agenda_screen.dart:512 | `shrinkWrap` em lista pode causar custo extra em mobile. | Avaliar sliver/lista com constraints fixas. |
| Medio | avoid-shrink-wrap-in-lists | lib/features/notas/widgets/emissao_confirmacao_sheet.dart:272 | `shrinkWrap` em lista pode causar custo extra em mobile. | Avaliar sliver/lista com constraints fixas. |
| Medio | avoid-shrink-wrap-in-lists | lib/features/syncview/widgets/servico_list.dart:53 | `shrinkWrap` em lista pode causar custo extra em mobile. | Avaliar sliver/lista com constraints fixas. |
| Baixo | avoid-redundant-async | lib/core/providers/nota_fiscal_provider.dart:184 | `async` redundante muda pouco comportamento; limpeza local. | Remover `async` se assinatura continuar compatível. |
| Baixo | avoid-redundant-async | lib/core/providers/nota_fiscal_provider.dart:189 | `async` redundante muda pouco comportamento; limpeza local. | Remover `async` se assinatura continuar compatível. |
| Baixo | avoid-redundant-async | lib/core/providers/servico_provider.dart:191 | `async` redundante muda pouco comportamento; limpeza local. | Remover `async` se assinatura continuar compatível. |
| Baixo | avoid-redundant-async | lib/core/providers/servico_provider.dart:203 | `async` redundante muda pouco comportamento; limpeza local. | Remover `async` se assinatura continuar compatível. |
| Baixo | avoid-redundant-async | lib/core/providers/servico_provider.dart:222 | `async` redundante muda pouco comportamento; limpeza local. | Remover `async` se assinatura continuar compatível. |
| Baixo | avoid-redundant-async | lib/core/providers/servico_provider.dart:363 | `async` redundante muda pouco comportamento; limpeza local. | Remover `async` se assinatura continuar compatível. |
| Baixo | avoid-redundant-async | lib/core/services/medvie_api_service.dart:685 | `async` redundante muda pouco comportamento; limpeza local. | Remover `async` se assinatura continuar compatível. |

## Plano de correcao

1. `lib/features/agenda/agenda_screen.dart` - criticos concluidos; restam 4 altos, 1 medio.
2. `lib/features/syncview/widgets/add_servico_modal.dart` - criticos concluidos; restam 4 altos.
3. `lib/features/profile/profile_screen.dart` - critico concluido; restam 4 altos.
4. `lib/core/services/medvie_api_service.dart` - 5 altos, 1 baixo; tipar boundary de API para reduzir risco de contrato.
5. `lib/main.dart` - 4 altos; revisar callbacks async em fluxos globais.

## Observacoes

- `avoid-passing-async-when-sync-expected` domina o relatorio: 32 ocorrencias. Pode haver ruido se callbacks forem `VoidCallback` de UI aceitando fire-and-forget, mas ainda vale revisar tratamento de erro e estado.
- `avoid-redundant-async` foi classificado como baixo porque tende a ser limpeza sem mudanca funcional.
- `avoid-dynamic` foi classificado como alto quando aparece em models/services/providers por estar em boundary de API/dados.
