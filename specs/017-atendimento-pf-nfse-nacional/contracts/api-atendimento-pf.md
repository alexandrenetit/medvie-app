# Contract consumed by Flutter: Atendimento PF

This file pins the expected backend behavior from `medvie-api/specs/017-atendimento-pf-nfse-nacional`.

## Contract pin (T003)

- **Backend source**: `medvie-api/specs/017-atendimento-pf-nfse-nacional`
  (feature 017 + Phase 9 lookup), reportado IMPLEMENTADO e verde (2391 testes)
  no handoff `prototipo_pf/HANDOFF_app_017.md`.
- **Endpoints consumidos** (não recriar no app):
  - `POST /api/v1/atendimentos` (app usa `emitirAgora=false`)
  - `POST /api/v1/atendimentos/tomador/lookup`
  - `POST /api/v1/notas` (emissão por `servicoId`)
  - `GET /api/v1/cep/{cep}`, `GET /api/v1/servicos`,
    `GET /api/v1/atendimentos/recentes`
- **Cliente Flutter pinado em**: implementação desta feature (branch `develop`).
- **Backend commit**: preencher com o SHA de `medvie-api` no PR de integração
  (repositório não disponível neste workspace — dependência externa).
- **Fixtures de contrato**: `test/fixtures/atendimento_pf/` espelham as
  respostas acima e são exercitadas em `test/core/atendimento_pf_fixtures_test.dart`.

## GET /api/v1/cep/{cep}

Used for address autofill.

Response 200:

```json
{
  "cep": "01311000",
  "logradouro": "Avenida Paulista",
  "bairro": "Bela Vista",
  "municipio": "Sao Paulo",
  "uf": "SP",
  "codigoIbge": "3550308"
}
```

App behavior:
- Fill read/write address fields.
- Keep `numero` empty and focused.
- If 404/timeout, show manual mode.

## POST /api/v1/atendimentos

Atomic endpoint for PF quick-add + service creation.

> **App usa `emitirAgora=false`** (criação atômica idempotente de tomador PF + serviço).
> A emissão NÃO é feita aqui: segue a mecânica existente do app via `POST /api/v1/notas`
> por `servicoId`, disparada pelo `EmissaoConfirmacaoSheet` (mesmo fluxo do plantonista).
> Ver FR-017 em `spec.md`.

Request:

```json
{
  "requisicaoId": "uuid-v7-or-v4",
  "cnpjProprioId": "guid",
  "tomador": {
    "tipo": "CPF",
    "documento": "12345678909",
    "nome": "Julia M. Ramos",
    "email": "julia@example.com",
    "telefone": "11999990000",
    "endereco": {
      "cep": "01311000",
      "logradouro": "Avenida Paulista",
      "numero": "1000",
      "complemento": "cj 101",
      "bairro": "Bela Vista",
      "municipio": "Sao Paulo",
      "uf": "SP",
      "codigoMunicipioIbge": "3550308"
    }
  },
  "servico": {
    "tipoServico": "Consulta",
    "codigoNbs": "40111",
    "descricao": "Consulta medica particular",
    "valor": 500.00,
    "competencia": "2026-06-09",
    "codigoMunicipioPrestacao": "3550308"
  },
  "emitirAgora": false
}
```

Response 201:

```json
{
  "atendimentoId": "guid",
  "servicoId": "guid",
  "tomador": {
    "id": "guid",
    "tipo": "CPF",
    "documentoMascarado": "***.***.***-09",
    "nome": "Julia M. Ramos",
    "enderecoFiscalStatus": "Completo"
  },
  "preview": {
    "bruto": 500.00,
    "issRetido": 0.00,
    "irrfRetido": 0.00,
    "ibs": 0.50,
    "cbs": 4.00,
    "liquidoEstimado": 500.00,
    "prontoParaEmitir": true
  },
  "nota": null,
  "status": "ProntoParaEmitir"
}
```

Response 202 when `emitirAgora=true`:

```json
{
  "atendimentoId": "guid",
  "servicoId": "guid",
  "tomador": {
    "id": "guid",
    "tipo": "CPF",
    "documentoMascarado": "***.***.***-09",
    "nome": "Julia M. Ramos",
    "enderecoFiscalStatus": "Completo"
  },
  "nota": {
    "id": "guid",
    "status": "Processando"
  },
  "status": "NfseEmProcessamento"
}
```

Response 422:

```json
{
  "code": "Tomador.EnderecoFiscal.Incompleto",
  "description": "Endereco fiscal do tomador PF incompleto.",
  "fields": ["tomador.endereco.numero", "tomador.endereco.codigoMunicipioIbge"]
}
```

## GET /api/v1/servicos

The app expects PF-compatible list rows:

```json
{
  "id": "guid",
  "tomadorId": "guid",
  "tomadorNome": "Julia M. Ramos",
  "tomadorCnpj": null,
  "tomadorTipo": "CPF",
  "tomadorDocumentoMascarado": "***.***.***-09",
  "tomadorEnderecoFiscalStatus": "Completo",
  "valor": 500.00,
  "status": "NfPronta"
}
```

Compatibility:
- `tomadorCnpj` can be null/empty for PF.
- Old clients ignore new fields.

## POST /api/v1/atendimentos/tomador/lookup

Lookup de paciente por CPF (CPF-first auto-load). Backend follow-up Phase 9 — contrato
canonico em `medvie-api/specs/017-atendimento-pf-nfse-nacional/contracts/api-tomador-lookup.md`.
DECISAO 1 = Opcao B: o response inclui contato (`email`/`telefone`).

Request:

```json
{
  "cnpjProprioId": "guid",
  "documento": "12345678909"
}
```

Response 200 (paciente existe):

```json
{
  "tomadorId": "guid",
  "tipo": "CPF",
  "documentoMascarado": "***.***.***-09",
  "nome": "Julia M. Ramos",
  "email": "julia@example.com",
  "telefone": "11999990000",
  "enderecoFiscalStatus": "Completo",
  "endereco": {
    "cep": "01311000",
    "logradouro": "Avenida Paulista",
    "numero": "1000",
    "complemento": "cj 101",
    "bairro": "Bela Vista",
    "municipio": "Sao Paulo",
    "uf": "SP",
    "codigoMunicipioIbge": "3550308"
  },
  "ultimoServico": {
    "tipoServico": "Consulta",
    "codigoNbs": "40111",
    "descricao": "Consulta medica particular",
    "competencia": "2026-06-05"
  }
}
```

Response 404 (nao cadastrado): `{ "code": "Tomador.NaoEncontrado" }`.
Response 422 (CPF invalido): `{ "code": "Tomador.Cpf.Invalido" }`.

App behavior (FR-014..FR-016):
- Disparado no blur do campo CPF, com CPF valido (11 digitos + DV).
- 200 → auto-preenche nome, endereco, contato e defaults de servico (sem `valor`).
- 404 → indica "novo paciente"; segue cadastro.
- CPF bruto nunca exibido (so mascarado) e nunca persiste local; `valor` sempre digitado pelo medico.

## POST /api/v1/notas

Existing emission endpoint remains valid by `servicoId`, `tomadorId` and `cnpjProprioId`.

App rule:
- Only call when PF address status is `Completo`.
- On accepted response, navigate to Notas/processing state.
