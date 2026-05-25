# Smoke Manual — iOS (Certificado Digital A1)

Executar em device iOS real após `pod install` em host macOS com Xcode instalado. Simulador iOS **não** valida o overlay de privacidade corretamente — usar device físico.

## Pré-requisitos
- Host macOS com Xcode ≥ 15 + CocoaPods instalado.
- Device iOS real (iOS ≥ 13, devido ao uso de `UIScene` lifecycle).
- Backend de staging acessível (`medvie-api` no commit pinado em `specs/cd-upload/contracts/api-pin.json`).
- Usuário PJ válido cadastrado no backend.
- Certificado PFX válido + senha correta para os cenários de fluxo prévios (não cobertos aqui — ver `SmokeManual.Android.md`).

## Setup
```bash
cd /caminho/para/medvie-app/ios
pod install
cd ..
flutter build ios --debug
# Ou abrir Runner.xcworkspace no Xcode e instalar via Run no device conectado.
```

Garantir que `ScreenshotGuardPlugin.swift` aparece no target **Runner** (Xcode → Project Navigator → Runner → File Inspector → Target Membership marcado).

## Cenários

### 7. Overlay opaco no app switcher cobre conteúdo sensível
**Telas a testar:** `CertificadoUploadScreen` e `CertificadoDetalheScreen`.

**Passos (repetir nas duas telas):**
1. Abrir a tela alvo no device.
2. Aguardar o conteúdo renderizar completamente (com card de status, campo de senha, etc).
3. Pressionar **Home** (botão físico nos iPhones com Touch ID) ou fazer swipe para cima (iPhones com Face ID) até o app switcher.

**Esperado:**
- Preview da app no app switcher exibe **retângulo opaco preenchendo toda a tela** com cor `#07090F` (preto azulado da paleta `AppColors.bg`).
- **Nenhum** elemento sensível visível no preview: sem CNPJ, sem holder, sem validade, sem campo de senha, sem botões.
- Em iPads com multi-window, o overlay deve cobrir **a janela cuja cena está em background**.
- Sem flash branco intermediário antes do overlay (cor de fundo casa com o tema dark do app).

### 8. Overlay removido ao voltar para foreground
**Setup:** continuar imediatamente do cenário 7 (app no switcher, overlay visível).

**Passos:**
1. Tocar no preview do app no app switcher para reabrir.
2. Observar a tela renderizar.
3. Repetir o ciclo background → foreground **3 vezes consecutivas** para validar idempotência do observer.

**Esperado:**
- Ao retornar, a tela exibe conteúdo normal (CNPJ, validade, campo de senha, botões — tudo visível).
- **Nenhum** resíduo do overlay opaco permanece sobreposto.
- Sem travamento ou flicker visível na transição.
- Após sair da tela (push de outra rota ou `Navigator.pop`), o `dispose` chama `ScreenshotGuard.disable()` e novos ciclos background/foreground **não** instalam overlay em outras telas do app.

## Critérios de aceite
- ✅ Cenários 7 e 8 executados em device iOS real.
- ✅ Overlay observado nas duas telas (`CertificadoUploadScreen` e `CertificadoDetalheScreen`).
- ✅ Sem regressão: outras telas do app **não** exibem overlay no app switcher após sair das telas sensíveis.
- ✅ Logs do Xcode (Console) não exibem warnings sobre `NotificationCenter` observer não-removido.

## Limitação conhecida — iOS
- iOS **não possui API pública** equivalente ao `FLAG_SECURE` do Android. Não é possível bloquear screenshot manual com o device em foreground (botão Power + Volume Up).
- A proteção via overlay é **eficaz apenas no app switcher** (snapshot que o sistema gera ao backgroundar o app) e em screen recording iniciado **após** o app entrar em background.
- Captura por hardware com app em foreground **não pode ser bloqueada** — limitação da plataforma, decisão de design da Apple. Documentado em ADR-0002.

## Falhas e como reportar
Para cada cenário falho, registrar:
- Nº do cenário.
- Comportamento observado vs esperado.
- Device + versão iOS (`Settings → General → About → iOS Version`).
- Screen recording do app switcher (gravado com outro device, já que screen recording do próprio device pode ser afetado pelo overlay).
- Logs do Xcode Console relevantes.
- Abrir issue no repositório com label `bug` + `certificado-a1` + `ios`.
