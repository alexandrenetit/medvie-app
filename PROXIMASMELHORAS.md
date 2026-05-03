# PRÓXIMAS MELHORIAS — Medvie App
> Roadmap arquitetural rumo à maturidade Top de Mercado
> Autor: Revisão arquitetural — Claude Code (Sonnet 4.6) · 2026-05-03
> Referência: padrões Nubank, Conta Azul, Stripe Dashboard, Doctolib, iFood

---

## Como usar este documento

Cada seção é um **nível de maturidade**. Execute na ordem. Não pule níveis — a base de cada nível sustenta o próximo. Marque cada item com ✅ quando concluído.

---

## 🔴 NÍVEL 1 — Fundação de Entrega (Pré-lançamento obrigatório)

> Sem esses itens, o app não deveria ir para produção com usuários reais.

### 1.1 Ambientes e Build Flavors

- [ ] Criar três flavors: `dev`, `staging`, `prod`
- [ ] Variáveis de ambiente por flavor: `baseUrl`, `supabaseKey`, `sentryDsn`
- [ ] `flutter_dotenv` ou `--dart-define-from-file` para injeção segura de secrets
- [ ] Nunca commitar `.env` — adicionar ao `.gitignore`
- [ ] Ícone de app diferente por flavor (dev = laranja, staging = amarelo, prod = original)

### 1.2 CI/CD

- [ ] GitHub Actions com jobs paralelos:
  - `dart analyze --fatal-infos` — zero warnings tolerado
  - `flutter test --coverage` com gate mínimo de 80% de cobertura
  - `flutter build apk --release` e `flutter build ios --release`
- [ ] Pull Request bloqueado se CI falhar
- [ ] Upload automático de build para Firebase App Distribution (staging)
- [ ] Deploy automático para Play Store internal track ao merge em `main`
- [ ] Secrets gerenciados via GitHub Secrets — nunca em código

### 1.3 Observabilidade

- [ ] **Sentry** integrado (`sentry_flutter`): crash reports com stack trace, contexto de usuário anonimizado
- [ ] `FlutterError.onError` e `PlatformDispatcher.instance.onError` capturando 100% dos crashes
- [ ] Breadcrumbs de navegação (qual tela o usuário estava antes do crash)
- [ ] Performance tracing nas operações críticas: login, emissão de NF, carregamento de dashboard
- [ ] **Nunca logar CPF, CNPJ, token ou valor financeiro** — validar com lint customizado

### 1.4 Segurança de Release

- [ ] Ofuscação ativa: `flutter build apk --obfuscate --split-debug-info=./debug-info/`
- [ ] ProGuard/R8 configurado para Android
- [ ] Certificate pinning no `MedvieApiService` (`dio` com `CertificatePinning`)
- [ ] Desabilitar backup ADB: `android:allowBackup="false"` no `AndroidManifest.xml`
- [ ] `flutter_jailbreak_detection` — bloquear uso em dispositivos comprometidos
- [ ] Timeout de sessão automático após inatividade (15 min)

---

## 🟠 NÍVEL 2 — Qualidade de Produto (Primeiras semanas pós-lançamento)

> O que separa um app funcional de um app confiável.

### 2.1 Testes de Integração

- [ ] `integration_test/` com cenários E2E usando Flutter Integration Test:
  - Fluxo completo de onboarding
  - Login → visualizar dashboard → emitir NF
  - Cancelar NF
- [ ] Rodar integration tests em emulador no CI (Firebase Test Lab ou GitHub Actions com emulator)
- [ ] Testes contra backend **real de staging** — nunca mocks em integration tests

### 2.2 Tratamento de Erros de Ponta a Ponta

- [ ] Classe `AppError` tipada: `NetworkError`, `AuthError`, `BusinessError`, `UnknownError`
- [ ] Cada provider expõe `AppError? erro` (não `String?`)
- [ ] Widget global `ErrorBoundary` que captura erros de UI e exibe fallback digno
- [ ] Retry automático com exponential backoff para falhas de rede transitórias
- [ ] Tratamento offline explícito: banner "Sem conexão" + fila de operações pendentes

### 2.3 Deep Links e Navegação

- [ ] App links configurados (Android) e Universal Links (iOS) — `medvie://` scheme
- [ ] Navegação por deep link: `medvie://notas/[id]`, `medvie://onboarding/step/[n]`
- [ ] Push notifications via FCM com ação ao tocar (navegar direto para NF atualizada)
- [ ] `go_router` com rotas nomeadas e guards de autenticação

### 2.4 Performance Baseline

- [ ] Tempo de cold start < 2s no dispositivo de referência (mid-range Android)
- [ ] `flutter_performance` ou DevTools timeline gravado e salvo como baseline
- [ ] Nenhuma jank (frame > 16ms) nas transições de tela principais
- [ ] `const` em 100% dos widgets folha — análise com `flutter analyze`
- [ ] Imagens com `cached_network_image` e tamanho explícito (evitar layout thrashing)

### 2.5 Versionamento Semântico

- [ ] `pubspec.yaml` com `version: MAJOR.MINOR.PATCH+BUILD` gerenciado automaticamente pelo CI
- [ ] `CHANGELOG.md` atualizado a cada release
- [ ] Tags git automáticas (`v1.0.0`) ao publicar para produção
- [ ] In-app update check: notificar usuário se versão < versão mínima suportada (`package_info_plus` + endpoint `/version`)

---

## 🟡 NÍVEL 3 — Escala e Resiliência (Crescimento)

> O que apps Tier-1 têm que apps comuns não têm.

### 3.1 Feature Flags

- [ ] Integrar `firebase_remote_config` ou serviço próprio de flags
- [ ] Toda feature nova protegida por flag: `if (flags.emissaoLoteEnabled)`
- [ ] Rollout gradual: 5% → 20% → 100% de usuários
- [ ] Kill switch por feature: desligar em produção sem novo deploy
- [ ] Flags por segmento: CNPJs do Simples vs. Lucro Presumido

### 3.2 Analytics de Produto

- [ ] Eventos de negócio rastreados (não vaidade): `nf_emitida`, `onboarding_step_concluido`, `erro_emissao`, `servico_adicionado`
- [ ] Funil de onboarding visível: % usuários que chegam em cada step
- [ ] `firebase_analytics` ou Mixpanel — nunca dados identificáveis nos eventos
- [ ] Dashboard de produto atualizado em tempo real

### 3.3 Offline-First Real

- [ ] Decisão arquitetural documentada: Hive (criptografado) ou Drift (SQLite com compile-time queries)
- [ ] `encryptionKey` gerada no Keystore e armazenada no `FlutterSecureStorage`
- [ ] TTL de 24h por registro de serviço local
- [ ] Fila de sincronização: operações offline enfileiradas e enviadas ao reconectar
- [ ] Indicador visual de "dados offline" na UI quando trabalhando sem conexão

### 3.4 Acessibilidade (A11y)

- [ ] `Semantics` em todos os widgets interativos (botões, cards de NF, inputs)
- [ ] Contraste mínimo 4.5:1 em todos os textos (WCAG AA)
- [ ] Suporte a TalkBack (Android) e VoiceOver (iOS) no fluxo principal
- [ ] Tamanho de fonte responsivo a `textScaleFactor` sem quebrar layout
- [ ] `flutter_accessibility_test` no CI

### 3.5 Localização e Internacionalização

- [ ] `flutter_localizations` + `intl` configurados mesmo que apenas pt-BR por enquanto
- [ ] Zero strings hardcoded na UI — todas em `app_pt.arb`
- [ ] Formatos de data, moeda e CPF/CNPJ via `intl` (nunca formatação manual)
- [ ] Preparado para es-LA (espanhol) se expansão regional for planejada

---

## 🟢 NÍVEL 4 — Excelência Operacional (Maturidade Contínua)

> O que faz um app durar anos sem acumular dívida técnica.

### 4.1 Arquitetura de Camadas Formal

- [ ] Separação explícita em packages: `core`, `features`, `design_system`
- [ ] Regra: widget nunca importa `MedvieApiService` diretamente — sempre via provider/repository
- [ ] `Repository pattern` formal: providers dependem de interfaces, não de implementações
- [ ] Injeção de dependência com `get_it` ou `riverpod` — eliminar dependência de `Provider` raiz
- [ ] Diagrama de arquitetura atualizado no repositório (`docs/architecture.md`)

### 4.2 Design System Próprio

- [ ] Componentes extraídos para biblioteca interna: `MedvieButton`, `MedvieCard`, `MedvieInput`
- [ ] Tokens de design: cores, tipografia, espaçamentos — todos de `ThemeData`, zero hardcoded
- [ ] Golden tests para todos os componentes do design system (`flutter_golden_toolkit`)
- [ ] Storybook equivalente: `widgetbook` para desenvolvimento visual isolado
- [ ] Dark mode suportado via `ThemeMode`

### 4.3 Qualidade de Código Automatizada

- [ ] `dart_code_metrics` no CI — complexidade ciclomática máxima 10 por método
- [ ] `very_good_analysis` lint rules — mais rigoroso que `flutter_lints`
- [ ] Pre-commit hook com `dart format` e `dart analyze`
- [ ] Cobertura de testes com relatório HTML publicado no GitHub Pages por PR
- [ ] Nenhum `// ignore:` sem comentário explicando o motivo

### 4.4 Documentação Viva

- [ ] `ARCHITECTURE.md`: decisões arquiteturais com contexto (ADRs — Architecture Decision Records)
- [ ] `RUNBOOK.md`: como rodar, testar, fazer deploy, rollback
- [ ] `API_CONTRACT.md`: contrato de cada endpoint consumido (versionado junto com o app)
- [ ] Cada provider com docstring explicando responsabilidade e ciclo de vida
- [ ] `dart doc` gerando documentação HTML no CI

### 4.5 SLOs e Alertas de Produção

- [ ] SLO definido: 99.5% de sucesso em emissão de NF (medido no Sentry)
- [ ] Alerta automático se taxa de erro > 1% em janela de 5 min
- [ ] Dashboard de saúde: crash-free rate, ANR rate, tempo médio de emissão de NF
- [ ] Post-mortem obrigatório para qualquer incidente que afete > 5% dos usuários
- [ ] Runbook de rollback testado trimestralmente

---

## 🔵 NÍVEL 5 — Diferenciação Competitiva (Longo Prazo)

> O que coloca o Medvie na mesma conversa que Conta Azul e QuickBooks.

### 5.1 Experiência Offline Completa

- [ ] Emissão de NF em modo offline com envio automático ao reconectar
- [ ] Dashboard funcional offline com dados da última sessão (criptografados)
- [ ] Sincronização delta: apenas o que mudou, não a lista inteira
- [ ] Resolução de conflitos: backend é fonte de verdade, app notifica o usuário de divergências

### 5.2 Biometria e Autenticação Forte

- [ ] `local_auth`: Face ID / Touch ID / biometria Android como segunda camada
- [ ] Re-autenticação biométrica para operações sensíveis (emitir NF, visualizar PDF)
- [ ] Session token renovação silenciosa com refresh token armazenado no Keystore
- [ ] MFA opcional para CNPJs de alto volume

### 5.3 Testes de Carga e Chaos Engineering

- [ ] Simular degradação de API (latência 3s, timeout, 500) com proxy de caos
- [ ] Verificar que loading states, retries e mensagens de erro aparecem corretamente
- [ ] Testar comportamento com 1.000+ serviços na lista (virtual scroll, memória)
- [ ] Profiling de memória com `flutter_memory_profiler` — sem leaks após 30 min de uso

### 5.4 Atualizações Over-the-Air (OTA)

- [ ] `shorebird` para patches Dart sem passar pela loja (correções críticas em horas)
- [ ] Política de versão mínima suportada documentada e aplicada via `force_update`
- [ ] Canal beta para usuários early adopters via TestFlight / Play Store Open Testing

### 5.5 Compliance e Auditoria

- [ ] LGPD: tela de consentimento, exportação de dados pessoais, exclusão de conta
- [ ] Logs de auditoria para operações sensíveis (emissão, cancelamento de NF) — imutáveis no backend
- [ ] Política de retenção de dados documentada e implementada
- [ ] Penetration test anual por empresa especializada
- [ ] Certificação de segurança (ISO 27001 ou SOC 2) para contratos B2B enterprise

---

## Tabela de Priorização Rápida

| Item | Impacto | Esforço | Quando |
|------|---------|---------|--------|
| Flavors dev/staging/prod | 🔴 Crítico | Baixo | Antes do launch |
| CI/CD com gate de cobertura | 🔴 Crítico | Médio | Antes do launch |
| Sentry crash reporting | 🔴 Crítico | Baixo | Antes do launch |
| Ofuscação + certificate pinning | 🔴 Crítico | Baixo | Antes do launch |
| Integration tests E2E | 🟠 Alto | Alto | Sprint 1 pós-launch |
| Feature flags | 🟠 Alto | Médio | Sprint 2 |
| Offline-first criptografado | 🟡 Médio | Alto | Sprint 3-4 |
| Design system formal | 🟡 Médio | Alto | Sprint 3-4 |
| Biometria | 🟡 Médio | Baixo | Sprint 2 |
| LGPD compliance completo | 🟠 Alto | Médio | Antes de escalar |
| Shorebird OTA | 🟢 Baixo | Baixo | Quando tiver usuários |
| Pentest externo | 🟠 Alto | Externo | Antes de contratos B2B |

---

## Estado Final Esperado

Quando todos os níveis estiverem concluídos, o Medvie-app terá:

- **Zero dados sensíveis desprotegidos** (já atingido ✅)
- **Zero crashes não rastreados** em produção
- **Deploy sem medo**: CI bloqueia regressões antes de chegar ao usuário
- **Rollout controlado**: features ligam e desligam sem novo deploy
- **Compliance LGPD**: auditável, exportável, deletável
- **Performance mensurável**: SLOs definidos, alertas automáticos
- **Time novo onboarda em < 1 dia**: documentação, runbook e arquitetura clara

> "Software de qualidade não é aquele que nunca falha. É aquele que falha de forma controlada, se recupera rapidamente e melhora continuamente." — padrão SRE Google
