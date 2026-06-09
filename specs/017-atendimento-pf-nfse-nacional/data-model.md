# Data Model: Atendimento PF no app Flutter

## TipoTomador

```dart
enum TipoTomador { cnpj, cpf }
```

Rules:
- Default para payload legado: `cnpj`.
- UI label: `cpf` => "Paciente PF"; `cnpj` => "Empresa/Convenio".

## EnderecoFiscalTomador

```dart
class EnderecoFiscalTomador {
  final String cep;
  final String logradouro;
  final String numero;
  final String? complemento;
  final String bairro;
  final String municipio;
  final String uf;
  final String codigoMunicipioIbge;

  bool get completo;
}
```

Completo when:
- CEP has 8 digits.
- logradouro, numero, bairro, municipio, UF and codigo IBGE are non-empty.
- UF has 2 letters.
- codigo IBGE has 7 digits.

## Tomador

Existing model evolves to:

```dart
class Tomador {
  final String id;
  final TipoTomador tipo;
  final String? documentoMascarado;
  final String? cnpj;
  final String razaoSocial;
  final String? emailFinanceiro;
  final String codigoIbge; // municipio de prestacao
  final EnderecoFiscalTomador? enderecoFiscal;
  final bool retemIss;
  final bool retemIrrf;
  final double? aliquotaIss;
  final double aliquotaIrrf;
}
```

Rules:
- `documento` raw CPF is not a field.
- For PF, `retemIss=false`, `retemIrrf=false`, aliquotas treated as zero in preview.
- For PF, `razaoSocial` may display as patient name.

## AtendimentoPfDraft

Ephemeral form state:

```dart
class AtendimentoPfDraft {
  final String? tomadorId;
  final String nomePaciente;
  final String cpfDigitado;
  final String? email;
  final EnderecoFiscalTomador endereco;
  final TipoServico tipoServico;
  final String codigoNbs;
  final String descricao;
  final double valor;
  final DateTime competencia;
  final String codigoMunicipioPrestacao;
  final String requisicaoId;
}
```

Rules:
- Exists only in memory.
- `cpfDigitado` must be cleared when modal closes or request completes.
- `requisicaoId` enables idempotency.

## AtendimentoFiscalPreview

```dart
class AtendimentoFiscalPreview {
  final double bruto;
  final double issRetido;
  final double irrfRetido;
  final double? ibs;
  final double? cbs;
  final double liquidoEstimado;
  final bool prontoParaEmitir;
  final List<String> pendencias;
}
```

Rules:
- PF always has `issRetido=0` and `irrfRetido=0`.
- `prontoParaEmitir=false` when endereco fiscal is incomplete.

## Servico DTO additions

The app expects service/list DTOs to expose, directly or by resolver:

```json
{
  "tomadorTipo": "CPF",
  "tomadorDocumentoMascarado": "***.***.***-09",
  "tomadorEnderecoFiscalStatus": "Completo"
}
```

Fallback until backend provides this: resolve by `tomadorId` only when screen needs details, avoiding N+1 in long lists.
