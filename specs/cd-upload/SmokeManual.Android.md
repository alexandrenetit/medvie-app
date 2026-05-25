# Smoke Manual — Android (Certificado Digital A1)

Executar em device Android real conectado ao backend de staging. Não usar emulador para os cenários de screenshot (item 6).

## Pré-requisitos
- Device Android real (API ≥ 21).
- Backend de staging acessível (`medvie-api` no commit pinado em `specs/cd-upload/contracts/api-pin.json`).
- Usuário PJ válido cadastrado no backend (CPF + senha).
- Pelo menos **2 arquivos PFX/P12 de teste**: um válido com senha correta e outro com senha incorreta.
- APK debug instalado: `flutter build apk --debug && flutter install`.

## Cenários

### 1. Gate de onboarding bloqueia avanço sem certificado
**Setup:** logar com usuário cujo onboarding está em step 2b com método de assinatura = **A1**.

**Passos:**
1. Login → onboarding navega até step 2b.
2. Sem anexar nenhum certificado, observar o CTA **"Próximo"**.

**Esperado:**
- Botão **"Próximo"** desabilitado (cinza, não clicável).
- Mensagem de hint visível indicando necessidade de envio do certificado.

### 2. Upload de PFX válido libera o step
**Passos:**
1. No step 2b, tocar em **"Enviar certificado"** → abre `CertificadoUploadScreen`.
2. Selecionar arquivo PFX válido via picker.
3. Digitar a senha correta.
4. Tocar em **"Anexar"**.

**Esperado:**
- Spinner durante upload.
- Snackbar verde: *"Certificado enviado."*
- Navegação retorna ao step 2b.
- CTA **"Próximo"** agora habilitado.
- Card de status do certificado visível (faixa verde, validade futura).

### 3. PFX com senha errada exibe mensagem traduzida
**Passos:**
1. No step 2b, tocar em **"Enviar certificado"**.
2. Selecionar arquivo PFX válido.
3. Digitar senha **incorreta** propositalmente.
4. Tocar em **"Anexar"**.

**Esperado:**
- Snackbar vermelho com mensagem em **português** (não código bruto do backend).
- Exemplo aceitável: *"Senha do certificado incorreta."* ou tradução equivalente em `certificado_error_codes.dart`.
- Tela permanece em `CertificadoUploadScreen` para nova tentativa.
- Senha previamente digitada permanece no campo (UX para correção).

### 4. Reanexar mesmo PFX trata 409 como sucesso idempotente
**Setup:** ter um certificado já ativo (cenário 2 completo).

**Passos:**
1. Acessar `CertificadoDetalheScreen` (via menu ou SyncView card → tap).
2. Tocar em **"Substituir certificado"** → abre `CertificadoUploadScreen`.
3. Reanexar **o mesmo arquivo PFX** com a mesma senha.
4. Tocar em **"Anexar"**.

**Esperado:**
- Backend responde HTTP 409 (`Certificado.JaExiste` ou equivalente).
- Provider trata como sucesso idempotente — sem erro vermelho.
- Snackbar verde ou neutra indicando que o certificado já estava ativo.
- Metadados (validade, holder) permanecem inalterados.

### 5. Remover certificado bloqueia emissão de notas
**Setup:** ter um certificado ativo.

**Passos:**
1. Em `CertificadoDetalheScreen`, tocar em **"Remover certificado"**.
2. Confirmar no `AlertDialog` destrutivo.
3. Aguardar conclusão da operação.
4. Navegar até a tela de emissão de notas fiscais.
5. Tentar emitir uma nota.

**Esperado:**
- Após remoção: snackbar verde *"Certificado removido."*.
- `CertificadoDetalheScreen` exibe estado vazio (`_EmptyState`) com CTA **"Enviar certificado"**.
- Card de status no SyncView desaparece (ou indica ausência).
- Tentativa de emissão é bloqueada na UI (CTA desabilitado) ou retorna erro traduzido vindo do backend.

### 6. Screenshot bloqueado nas telas sensíveis
**Telas a testar:** `CertificadoUploadScreen` e `CertificadoDetalheScreen`.

**Passos (repetir nas duas telas):**
1. Abrir a tela alvo.
2. Tentar capturar screenshot:
   - **Hardware:** botão Power + Volume Down (varia por OEM).
   - **Gesto:** swipe de 3 dedos (em devices Samsung/Xiaomi compatíveis).
3. Verificar galeria.
4. Tentar gravar a tela via app de screen recorder nativo.
5. Tentar conectar mirror (scrcpy via USB, ou Smart View).

**Esperado:**
- Screenshot dispara toast nativo do Android: *"Não foi possível capturar a tela"* (texto exato varia por OEM/locale).
- Galeria **não contém** captura da tela.
- Screen recorder grava **tela preta** no lugar do conteúdo das telas protegidas.
- Mirror via scrcpy/Smart View renderiza **tela preta** quando a tela protegida está em foreground.
- Ao sair das telas (`dispose`): screenshot volta a funcionar normalmente em outras telas do app.

## Critérios de aceite
- ✅ Todos os 6 cenários executados em device Android real.
- ✅ Comportamento observado bate com **Esperado** em cada item.
- ✅ Nenhum log de senha em `logcat` durante o upload.
- ✅ Após `dispose`, validar via inspeção de heap (Android Studio Profiler) que `Uint8List` do PFX não permanece referenciado.

## Falhas e como reportar
Para cada cenário falho, registrar:
- Nº do cenário.
- Comportamento observado vs esperado.
- Device + versão Android (`adb shell getprop ro.build.version.release`).
- Print da tela (quando aplicável — exceto cenário 6).
- Trecho de `logcat` relevante (sem dados sensíveis).
- Abrir issue no repositório com label `bug` + `certificado-a1`.
