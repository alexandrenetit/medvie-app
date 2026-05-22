# Feature Spec — Upload de Certificado Digital A1 (CD)

**Feature ID:** `cd-upload`
**Branch sugerida:** `feat/cd-upload`
**Repo:** `medvie-app` (Flutter)
**Owner:** Arquitetura
**Status:** Draft v1 — pendente aprovação
**Contrato fonte:** `medvie-api/specs/cd-provisionamento/contracts/certificado.openapi.yaml` (commit-pinned)
**Princípios:** Hexagonal · SOLID · DDD (light) · Provider-Neutral · Zero-Trust

---

## 1. Visão & Problema

### 1.1 Problema
Hoje o app declara `MetodoAssinatura.certificadoA1` e `StatusCertificado` como campos locais cosméticos, sem fluxo real de upload de PFX/P12. O médico não tem como anexar seu certificado digital e o onboarding não é capaz de habilitar emissão de NFS-e.

### 1.2 Objetivo
Implementar fluxo de upload do certificado A1 no app:
1. Selecionar arquivo PFX/P12 do dispositivo.
2. Capturar senha do certificado (campo redacted).
3. Enviar para o backend Medvie via `POST /api/v1/cnpjs/{id}/certificado` (multipart).
4. Exibir feedback de validação (sucesso, senha errada, CNPJ divergente, vencido).
5. Manter `StatusCertificado` sincronizado com backend.
6. Bloquear continuação do onboarding (step 2b) até `StatusCertificado = Ativo`.
7. Exibir card de status com dias para vencer e CTA de renovação.
8. Reagir a eventos SSE de expiração próxima e expirado.

### 1.3 Fora de Escopo
- Implementação backend (vive em `medvie-api/specs/cd-provisionamento`).
- Renovação automática junto à AC.
- Suporte a A3 / token físico.
- Edição offline do certificado.

---

## 2. Persona & User Stories

**Persona:** Médico PJ titular do CnpjProprio, autenticado, usando o app Flutter.

**US-1 — Anexar PFX pela primeira vez (onboarding step 2b)**
> Como médico PJ, quero anexar meu certificado A1 no onboarding para concluir o cadastro e começar a emitir NFS-e.

Critérios:
- Tela `CertificadoUploadScreen` apresenta picker de arquivo + campo senha.
- Picker restringe extensões `.pfx`, `.p12`.
- Tamanho máximo 8 MB (validação client-side).
- Botão "Anexar" desabilitado até arquivo + senha preenchidos.
- Loading durante upload; erro exibido em banner com código semântico traduzido.
- Sucesso → atualiza `StatusCertificado.ativo` no provider local + libera próximo step.

**US-2 — Substituir certificado próximo do vencimento**
> Como médico PJ, quero substituir meu certificado antes de vencer.

Critérios:
- `CertificadoStatusCard` na `syncview` mostra dias para vencer.
- Botão "Atualizar certificado" abre `CertificadoUploadScreen` no modo edição.
- Upload com mesmo fingerprint → toast "Certificado já está ativo".
- Upload novo → substitui silenciosamente e mantém histórico (backend cuida).

**US-3 — Visualizar status do certificado**
> Como médico PJ, quero ver status e prazo do certificado a qualquer momento.

Critérios:
- Card na `syncview` mostra: `subjectCnpj` mascarado, `issuerName`, `validUntil`, `diasParaVencer`.
- Cores: verde > 30 dias · amarelo 7–30 · vermelho < 7 · cinza vencido.
- Tap no card abre detalhe.

**US-4 — Tratar erro de validação**
> Como médico PJ, quero entender por que meu certificado foi recusado.

Critérios:
- Tradução de códigos do backend → mensagens claras:
  - `Certificado.SenhaInvalida` → "Senha incorreta. Verifique e tente novamente."
  - `Certificado.FormatoInvalido` → "Arquivo não é um PFX/P12 válido."
  - `Certificado.CnpjDivergente` → "CNPJ do certificado não bate com seu CNPJ cadastrado."
  - `Certificado.Vencido` → "Certificado vencido. Renove na sua AC antes de anexar."
  - `Certificado.ProviderRecusou` → "O provedor fiscal recusou o certificado. Verifique com seu suporte."

**US-5 — Receber alerta de expiração via SSE**
> Como médico PJ, quero ser avisado quando meu certificado está vencendo.

Critérios:
- Evento SSE `certificado_alerta` (`diasRestantes ∈ {30,15,7,1,0}`) gera notificação local + banner persistente na `syncview` até substituição.

**US-6 — Remover certificado**
> Como médico PJ, quero remover meu certificado se trocar de PJ.

Critérios:
- Confirmação destrutiva ("Isso bloqueará novas emissões. Confirmar?").
- `DELETE` no backend → `StatusCertificado` volta a `pendente`.
- Emissão fica bloqueada até novo upload.

---

## 3. Requisitos Funcionais

| ID | Requisito | Prioridade |
|---|---|---|
| RF-01 | Tela `CertificadoUploadScreen` em `lib/features/certificado/screens/` | MUST |
| RF-02 | Picker de arquivo restrito a `.pfx`/`.p12`, max 8 MB | MUST |
| RF-03 | Campo senha redacted (obscureText) | MUST |
| RF-04 | Provider `CertificadoProvider` (ChangeNotifier) com estados `idle`, `uploading`, `success`, `error(codigo, mensagem)` | MUST |
| RF-05 | Método `MedvieApiService.uploadCertificado(cnpjProprioId, bytes, senha, restritoAoCnpj)` (multipart) | MUST |
| RF-06 | Método `MedvieApiService.consultarCertificado(cnpjProprioId)` (GET) | MUST |
| RF-07 | Método `MedvieApiService.removerCertificado(cnpjProprioId)` (DELETE) | MUST |
| RF-08 | Card `CertificadoStatusCard` em `syncview` | MUST |
| RF-09 | Bloqueio do onboarding step 2b enquanto `StatusCertificado != ativo` (quando método = A1) | MUST |
| RF-10 | Tradução de códigos de erro → mensagens UX | MUST |
| RF-11 | Tratamento de evento SSE `certificado_alerta` | SHOULD |
| RF-12 | Indicador visual de dias para vencer (cores 30/7/0) | MUST |
| RF-13 | Confirmação destrutiva no `DELETE` | MUST |
| RF-14 | Bytes do PFX permanecem em memória durante a request e são descartados imediatamente após | MUST |
| RF-15 | Senha nunca persistida em `SharedPreferences`, `FlutterSecureStorage`, Hive, ou cache | MUST |
| RF-16 | Logs do app nunca registram bytes do PFX, senha, nem mensagens de erro do servidor com payload bruto | MUST |
| RF-17 | Pacote `file_picker` aprovado via ADR-0001 do app | MUST |
| RF-18 | Toggle UI "Restringir a este CNPJ" mapeado para `restritoAoCnpj` no payload | SHOULD |

---

## 4. Requisitos Não-Funcionais

| ID | Requisito | Critério |
|---|---|---|
| NFR-01 | **Confidencialidade** | Senha em campo `obscureText`, nunca em logs/screenshots; PFX bytes em `Uint8List` local descartado após `await` |
| NFR-02 | **Performance UX** | Upload com loader; cancelável; timeout 30 s |
| NFR-03 | **Testabilidade** | `CertificadoProvider` isolado de UI; mock de `MedvieApiService` |
| NFR-04 | **Acessibilidade** | Labels semânticos para screen reader; contraste WCAG AA |
| NFR-05 | **Resiliência** | Retry manual; sem retry automático cego (evita reupload em loop em caso de senha errada) |
| NFR-06 | **Observabilidade** | Telemetria local: `certificado_upload_tentativa`, `certificado_upload_sucesso`, `certificado_upload_falha{codigo}` |

---

## 5. Modelagem (App)

### 5.1 Atualizações no domínio local

- `StatusCertificado` ganha `substituido` e `removido` (manter compat com backend).
- `StatusCertificadoExt.fromJson` deixa de cair em fallback silencioso — desconhecido → `StatusCertificado.desconhecido` exibido como warning.
- Novo modelo `CertificadoMetadata` em `lib/core/models/certificado_metadata.dart`:
  ```
  CertificadoMetadata {
    StatusCertificado status,
    String subjectCnpj,
    String issuerName,
    DateTime validFrom,
    DateTime validUntil,
    String fingerprintSha256,
    bool restritoAoCnpj,
    String? provider,
    DateTime? provisionadoEm,
    int diasParaVencer,
  }
  ```
- `fromJson`/`toJson` explícitos, alinhados ao OpenAPI fragment.

### 5.2 Estrutura de pastas (Δ)

```
lib/
  features/
    certificado/                              NEW
      screens/
        certificado_upload_screen.dart        NEW
        certificado_detalhe_screen.dart       NEW
      widgets/
        certificado_status_card.dart          NEW
        senha_field.dart                      NEW
        arquivo_picker_tile.dart              NEW
  core/
    providers/
      certificado_provider.dart               NEW
    models/
      certificado_metadata.dart               NEW
    services/
      medvie_api_service.dart                 EDIT (+upload/consultar/remover certificado)
      sse_service.dart                        EDIT (+evento certificado_alerta)
    constants/
      certificado_error_codes.dart            NEW (mapeamento código → mensagem PT-BR)
```

---

## 6. Contrato Consumido

Contrato é o OpenAPI fragment do backend (`certificado.openapi.yaml`), **commit-pinned** no arquivo `contracts/api-pin.json`:

```
contracts/
  api-pin.json   { "repo": "medvie-api", "path": "specs/cd-provisionamento/contracts/certificado.openapi.yaml", "commit": "<sha>" }
```

CI valida (etapa opcional inicialmente): faz `curl` do raw github do commit pinned e compara com snapshot local. Drift → falha.

### Endpoints consumidos

| Método | Path | Uso |
|---|---|---|
| `POST` | `/api/v1/cnpjs/{id}/certificado` | upload |
| `GET` | `/api/v1/cnpjs/{id}/certificado` | status |
| `DELETE` | `/api/v1/cnpjs/{id}/certificado` | remover |

Códigos de erro mapeados via `certificado_error_codes.dart`.

---

## 7. Critérios de Aceitação Globais

1. ✅ Upload feliz path funciona em dispositivo Android real (smoke manual) com backend em staging.
2. ✅ Senha errada exibe mensagem clara, sem expor stack trace.
3. ✅ Bloqueio do step 2b sem cert ativo testado em widget test.
4. ✅ Bytes do PFX e senha não aparecem em nenhum log (busca em `lib/core/services/medvie_api_service.dart` por interpolação suspeita).
5. ✅ `dart analyze` sem issues.
6. ✅ `flutter test` 100% passa.
7. ✅ `./run_dcm.sh` sem issues.
8. ✅ `flutter build apk --debug` verde.
9. ✅ Pacote `file_picker` justificado em `specs/cd-upload/adr/0001-file-picker-exception.md`.

---

## 8. Riscos & Mitigações

| # | Risco | Mitigação |
|---|---|---|
| R1 | Cache do `file_picker` deixa PFX em diretório temp do app | Após `await` do upload, executar `file.delete()` se `cachedPath != null` |
| R2 | `TextEditingController` da senha vaza após dispose | `controller.dispose()` no `dispose()` da tela; testes garantem |
| R3 | Screenshot do sistema captura senha em onboarding | Aplicar `FLAG_SECURE` (Android) e `isCaptureProtected` (iOS) na tela de upload |
| R4 | Backend offline → cliente fica em loading infinito | Timeout 30 s + estado de erro recuperável |
| R5 | Provider neutro do app divergindo do backend | Snapshot do OpenAPI + teste de serialização do `CertificadoMetadata` |
| R6 | Drift OpenAPI sem CI ativo no início | Adicionar etapa de validação como `[P]` em pipeline futuro; por enquanto manual no PR review |

---

## 9. Dependências

- Backend: spec `medvie-api/specs/cd-provisionamento` (Fase A mínima — endpoints implementados + flag staging ON).
- Pacote `file_picker` aprovado via ADR-0001 do app.
- SSE service: já existe (`lib/core/services/sse_service.dart`) — adicionar evento novo.

---

## 10. Glossário

- **PFX/P12**: container PKCS#12.
- **Subject CNPJ**: CNPJ extraído do campo Subject ou SAN do certificado X.509.
- **Fingerprint**: SHA-256 do DER, identificador idempotente.
- **`restritoAoCnpj`**: equivalente local do Focus `certificado_especifico`.
