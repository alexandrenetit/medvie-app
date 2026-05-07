# DCM Issues Report

Data/hora da execucao: 2026-05-07 17:19:18 -03:00

Comando executado:

```bash
docker compose up -d dcm
./run_dcm.sh
```

Resumo pendente apos validacao em 2026-05-07:

| Criticidade | Quantidade |
| --- | ---: |
| Critico | 0 |
| Alto | 0 |
| Medio | 0 |
| Baixo | 0 |
| Total | 0 |

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
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1096 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com callback sync chamando `_salvar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1481 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_excluir`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1826 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_selecionarData`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/agenda/agenda_screen.dart:1913 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_salvar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/auth/auth_screen.dart:188 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_entrar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/notas/notas_screen.dart:953 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `onEmitirTodos`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/notas/notas_screen.dart:1073 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com handler `_emitir` e `onTap` sync; nao aparece no DCM atual. |
| Concluido (Alto) | no-empty-block | lib/features/onboarding/screens/step1a_dados_screen.dart:283 | Bloco vazio podia esconder fluxo incompleto ou erro engolido. | Corrigido removendo bloco vazio e atualizando indicador com `ValueListenableBuilder`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1a_dados_screen.dart:323 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_avancar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1b_grupo_screen.dart:114 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_avancar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1c_especialidade_screen.dart:155 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_avancar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step1c_especialidade_screen.dart:193 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_carregar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step2a_cnpj_screen.dart:186 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_consultar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step2a_cnpj_screen.dart:336 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_avancar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step3_tomadores_screen.dart:393 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_adicionar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step3_tomadores_screen.dart:534 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_avancar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step4_confirmacao_screen.dart:197 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_adicionarOutroCnpj`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/onboarding/screens/step4_confirmacao_screen.dart:222 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_concluir`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/profile/editar_tomador_screen.dart:332 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_salvar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:378 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_salvar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:599 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_salvar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:1165 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_adicionar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/profile/profile_screen.dart:1286 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_adicionar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/syncview/syncview_screen.dart:117 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_showAddServicoModal`; nao aparece no DCM atual. |
| Concluido (Alto) | no-empty-block | lib/features/syncview/widgets/add_servico_modal.dart:78 | Bloco vazio no listener de `setState` apenas disparava rebuild do preview fiscal. | Corrigido com `ValueListenableBuilder`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/syncview/widgets/add_servico_modal.dart:559 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_selecionarData`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/syncview/widgets/add_servico_modal.dart:693 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_salvar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/features/syncview/widgets/add_servico_modal.dart:724 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_excluirOuCancelar`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/main.dart:108 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com closure sync chamando `_entrarAposLogin`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/main.dart:159 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com callback sync chamando `_entrarAposLogin` via navigator global; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/main.dart:215 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com callback sync chamando `_entrarAposLogin`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/main.dart:267 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com callback sync chamando `_entrarAposLoginPeloNavigatorGlobal`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/shared/widgets/pdf_viewer_sheet.dart:95 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com wrapper sync `_onCompartilharPressed`; nao aparece no DCM atual. |
| Concluido (Alto) | avoid-passing-async-when-sync-expected | lib/shared/widgets/pdf_viewer_sheet.dart:126 | Callback async passado onde assinatura espera sync; erro async podia escapar fluxo esperado. | Corrigido com wrapper sync `_onTentarNovamentePressed`; nao aparece no DCM atual. |
| Concluido (Medio) | avoid-shrink-wrap-in-lists | lib/features/agenda/agenda_screen.dart:512 | `shrinkWrap` em lista interna causava custo extra em mobile. | Corrigido com `Column` e separadores manuais; nao aparece no DCM atual. |
| Concluido (Medio) | avoid-shrink-wrap-in-lists | lib/features/notas/widgets/emissao_confirmacao_sheet.dart:272 | `shrinkWrap` em lista limitada por altura causava custo extra em mobile. | Corrigido removendo `shrinkWrap` da `ListView`; nao aparece no DCM atual. |
| Concluido (Medio) | avoid-shrink-wrap-in-lists | lib/features/syncview/widgets/servico_list.dart:53 | `shrinkWrap` em lista interna causava custo extra em mobile. | Corrigido com `Column` para itens embutidos; nao aparece no DCM atual. |
| Concluido (Baixo) | avoid-redundant-async | lib/core/providers/nota_fiscal_provider.dart:184 | `async` redundante muda pouco comportamento; limpeza local. | Corrigido sem alterar contrato `Future`; nao aparece no DCM atual. |
| Concluido (Baixo) | avoid-redundant-async | lib/core/providers/nota_fiscal_provider.dart:189 | `async` redundante muda pouco comportamento; limpeza local. | Corrigido sem alterar contrato `Future`; nao aparece no DCM atual. |
| Concluido (Baixo) | avoid-redundant-async | lib/core/providers/servico_provider.dart:191 | `async` redundante muda pouco comportamento; limpeza local. | Corrigido sem alterar contrato `Future`; nao aparece no DCM atual. |
| Concluido (Baixo) | avoid-redundant-async | lib/core/providers/servico_provider.dart:203 | `async` redundante muda pouco comportamento; limpeza local. | Corrigido sem alterar contrato `Future`; nao aparece no DCM atual. |
| Concluido (Baixo) | avoid-redundant-async | lib/core/providers/servico_provider.dart:222 | `async` redundante muda pouco comportamento; limpeza local. | Corrigido sem alterar contrato `Future`; nao aparece no DCM atual. |
| Concluido (Baixo) | avoid-redundant-async | lib/core/providers/servico_provider.dart:363 | `async` redundante muda pouco comportamento; limpeza local. | Corrigido sem alterar contrato `Future`; nao aparece no DCM atual. |
| Concluido (Baixo) | avoid-redundant-async | lib/core/services/medvie_api_service.dart:686 | `async` redundante muda pouco comportamento; limpeza local. | Corrigido removendo `async`; nao aparece no DCM atual. |

## Plano de correcao

1. `lib/features/agenda/agenda_screen.dart` - criticos, altos e medio concluidos.
2. `lib/features/notas/widgets/emissao_confirmacao_sheet.dart` - medio concluido.
3. `lib/features/syncview/widgets/servico_list.dart` - medio concluido.
4. `lib/features/syncview/widgets/add_servico_modal.dart` - criticos e altos concluidos.
5. `lib/features/profile/profile_screen.dart` - critico concluido; altos concluidos.
6. `lib/core/providers/nota_fiscal_provider.dart` - baixos concluidos.
7. `lib/core/providers/servico_provider.dart` - baixos concluidos.
8. `lib/core/services/medvie_api_service.dart` - baixo concluido.
9. `lib/main.dart` - altos concluidos.
10. `lib/shared/widgets/pdf_viewer_sheet.dart` - altos concluidos.

## Observacoes

- `avoid-passing-async-when-sync-expected` nao aparece no DCM atual.
- `avoid-shrink-wrap-in-lists` nao aparece no DCM atual.
- `avoid-redundant-async` foi classificado como baixo porque tende a ser limpeza sem mudanca funcional.
- `avoid-dynamic` foi classificado como alto quando aparece em models/services/providers por estar em boundary de API/dados.
