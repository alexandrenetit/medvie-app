# CLAUDE.md — medvie-app (Flutter)

### Iniciando a sessão
Sempre inicie a sessão configurando:
- caveman ultra

## Contexto
Cliente Flutter do Medvie — SaaS de automação fiscal para médicos PJ. Backend .NET é fonte única da verdade. Flutter só renderiza. Produto é production-final desde o primeiro commit — nunca tratar como MVP.

## Stack
- Flutter / Dart (null safety)
- State management: **Provider** — sem Riverpod, sem Bloc, sem GetX
- `SharedPreferences` apenas para JWT e preferências de UI. NUNCA para dado de negócio.
- API client em `lib/core/services/medvie_api_service.dart`

## Arquitetura
- Camadas: UI (`features/*/screens`) → Provider (`core/providers`) → Service (`core/services`) → API .NET
- Sem lógica de negócio em widget. Sem chamada HTTP em widget.
- Sem singleton global sem necessidade arquitetural clara.
- Estrutura ativa: `lib/features/<feature>/screens/`. Pasta `steps/` é legado — ignorar.

## Regras inegociáveis
- **Backend = fonte única da verdade.** Login → backend. SharedPreferences nunca é fonte de verdade para médico, CNPJs, onboarding state.
- **Sem chamada externa direta do Flutter.** IBGE, BrasilAPI, ViaCEP, CNPJ → sempre via backend .NET.
- **Sem hardcode** de URL, token, cor, dimensão, texto de negócio, regra fiscal.
- **Apenas pacotes oficiais Google/Flutter.** Terceiros só com 100% de certeza e justificativa.
- **`sed -i` proibido** — usar `str_replace`.
- Nada de solução temporária. Todo código é production-final.
- Arquivo entregue sempre completo, com caminho na linha 1: `// lib/features/...`

## Regras de negócio com impacto no código
- Enum `PerfilAtuacao`: `MédicoClínico`, `ProcedimentalistaAmbulatorial`, `PlantonistaHospitalar`, `CirurgiãoHospitalar`.
- Step 3 (Tomadores) só aparece para `PlantonistaHospitalar`.
- Onboarding restoration: `onboarding_completo=true` → SyncView; `false` → `PageController` no índice = `onboarding_step`.
- `NotaFiscal.versao` é getter computado de `updatedAt` via Ticks UTC compatível com .NET: `_ticksAt1970 + utc.microsecondsSinceEpoch * 10`.
- `StatusNota`: comparação por string literal matching contrato backend — não enum local.
- Município: exibir `municipio_nome`, nunca código IBGE cru.

## Design system (dark theme obrigatório)
- Fundo `#07090F` · Surface `#111827` · Brand `#00C98A` · Secundária `#0EA5E9`
- Texto: `#FFFFFF` / `#CBD5E1` / `#94A3B8`
- Fontes: **Outfit** (UI) · **JetBrains Mono** (valores monetários)
- Sempre via `core/constants/app_colors.dart` e `core/theme/app_theme.dart`. Nunca cor literal em widget.

## Padrões Flutter
- `const` onde possível
- Sem `setState` excessivo em telas complexas
- Validar `mounted` após qualquer `await` antes de usar `BuildContext`
- Tratar loading / success / error / empty
- `ListView.builder` para listas longas
- Sem criação desnecessária de objeto dentro de `build`
- Serialização: `fromJson`/`toJson` explícitos, alinhados ao contrato do backend

## Protocolo (obrigatório antes de editar)
Em 2–3 linhas:
1. O que vai fazer
2. Arquivos envolvidos
3. Risco principal

Aguardar `pode ir`.

## Exploração
1. `find` → estrutura
2. `grep` → símbolo/widget/provider
3. Ler APENAS o arquivo da subtarefa
4. Se precisar abrir >3 arquivos ou ampliar escopo → PARAR e perguntar

Nunca assumir estado de código. Verificar via `cat`/`find`.

## Limites de edição
- Cirúrgicas. Preservar código funcionando.
- Máx. 3 arquivos por iteração.
- Não trocar state manager. Não trocar arquitetura.
- Não remover código aparentemente não usado sem confirmar impacto.
- Não introduzir pacote sem justificativa.

## Resolução de erros comuns
- Erro de import / build estranho: `flutter clean && flutter pub get && flutter run`
- Antes de afirmar que arquivo existe/tem conteúdo X: `cat` ou `find` para confirmar.

## Validação
Antes de finalizar:
1. `dart analyze` — zero issues
2. `flutter test` — 0 failed
3. `./run_dcm.sh` em `/mnt/c/Projects/medvie/medvie-app` (WSL Ubuntu) — zero issues
4. `flutter build apk --debug` apenas ao final de tarefa completa

Tarefa só é considerada concluída com `dart analyze`, `flutter test` e `./run_dcm.sh` 100% limpos. Qualquer issue residual = não finalizado.

Reportar erro com: comando + erro essencial + arquivo/linha + sugestão objetiva. Nunca colar log completo.

## Resposta após execução
1. O que mudou
2. Arquivos modificados
3. Como validar
4. Riscos
5. Próximo passo

Confirmar com ✅ ou reportar erro com stack mínimo.

## Commits
pt-br, prefixo `feat:`. Sem `Co-Authored-By: Claude`.

## Caminho
WSL: `/mnt/c/Projects/medvie/medvie-app/`