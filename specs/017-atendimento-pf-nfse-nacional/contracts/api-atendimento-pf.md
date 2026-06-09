# Contract consumed by Flutter: Atendimento PF

This file pins the expected backend behavior from `medvie-api/specs/017-atendimento-pf-nfse-nacional`.

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

Preferred atomic endpoint for PF quick-add + service creation.

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
    "codigoNbs": "0401",
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

## POST /api/v1/notas

Existing emission endpoint remains valid by `servicoId`, `tomadorId` and `cnpjProprioId`.

App rule:
- Only call when PF address status is `Completo`.
- On accepted response, navigate to Notas/processing state.
