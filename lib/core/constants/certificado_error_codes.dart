// lib/core/constants/certificado_error_codes.dart

/// Mapeamento canônico dos códigos de erro do domínio `Certificado.*` (backend Medvie)
/// para mensagens PT-BR exibidas ao médico.
///
/// Fonte única — UI nunca exibe `response.body` cru ou stack trace.
/// Atualizar conforme o fragment OpenAPI `medvie-api/specs/cd-provisionamento/contracts/certificado.openapi.yaml`
/// (commit-pinned em `specs/cd-upload/contracts/api-pin.json`).
const Map<String, String> _msgs = <String, String>{
  'Certificado.SenhaInvalida': 'Senha do certificado inválida.',
  'Certificado.FormatoInvalido': 'Arquivo PFX/P12 inválido ou corrompido.',
  'Certificado.CnpjDivergente':
      'CNPJ do certificado não bate com o CNPJ informado.',
  'Certificado.Vencido': 'Certificado vencido.',
  'Certificado.SemCnpjNoSubject':
      'Certificado não contém CNPJ no Subject/SAN.',
  'Certificado.ProviderRecusou': 'Provedor de NFS-e recusou o certificado.',
};

/// Traduz um código de erro do backend em uma mensagem PT-BR amigável.
///
/// Código desconhecido → `fallback`. Nunca expõe detalhes técnicos.
String traduzir(
  String codigo, {
  String fallback = 'Erro inesperado no certificado.',
}) {
  return _msgs[codigo] ?? fallback;
}
