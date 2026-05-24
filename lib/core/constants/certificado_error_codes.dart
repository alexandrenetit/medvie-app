// lib/core/constants/certificado_error_codes.dart

/// Mapeamento de códigos de erro do backend Medvie (domínio `Certificado.*`)
/// para mensagens em PT-BR exibidas ao médico.
///
/// Fonte única — UI nunca exibe `response.body` cru ou stack trace.
/// Atualizar conforme o fragment OpenAPI `medvie-api/specs/cd-provisionamento/contracts/certificado.openapi.yaml`
/// (commit-pinned em `specs/cd-upload/contracts/api-pin.json`).
const Map<String, String> certificadoErrorCodes = <String, String>{
  'Certificado.SenhaInvalida':
      'Senha incorreta. Verifique e tente novamente.',
  'Certificado.FormatoInvalido':
      'Arquivo não é um PFX/P12 válido.',
  'Certificado.CnpjDivergente':
      'CNPJ do certificado não bate com seu CNPJ cadastrado.',
  'Certificado.Vencido':
      'Certificado vencido. Renove na sua AC antes de anexar.',
  'Certificado.ProviderRecusou':
      'O provedor fiscal recusou o certificado. Verifique com seu suporte.',
};

/// Mensagem genérica quando o código do backend não está no mapa
/// ou veio nulo/vazio. Nunca expõe detalhes técnicos.
const String certificadoErrorFallback =
    'Não foi possível processar seu certificado. Tente novamente.';

/// Traduz um código de erro do backend em uma mensagem PT-BR amigável.
///
/// - Código conhecido → mensagem do mapa.
/// - Código desconhecido / nulo / vazio → `fallback` (se informado) ou
///   [certificadoErrorFallback].
String traduzir(String? codigo, {String? fallback}) {
  if (codigo == null || codigo.isEmpty) {
    return fallback ?? certificadoErrorFallback;
  }
  return certificadoErrorCodes[codigo] ?? fallback ?? certificadoErrorFallback;
}
