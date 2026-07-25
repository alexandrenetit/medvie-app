// lib/core/errors/mensagem_erro.dart
//
// Fonte ÚNICA de texto de erro exibível ao usuário (SEC-014).
//
// Regra do app, em duas metades:
//   - falha de transporte/contrato  → o service lança [ApiException] e a
//     mensagem sai daqui, derivada SÓ do status. `code`, `description`,
//     `rawBody` e path ficam no objeto para telemetria e NUNCA vão à tela.
//   - regra de negócio já traduzida → o service lança `Exception('texto pt-BR')`
//     e o texto passa direto (ex.: "CPF ou senha inválidos.").
//
// Por isso o service não pode voltar a lançar `Exception` com status, path ou
// corpo do backend: esses casos são [ApiException].

import 'api_exception.dart';

const String _generica = 'Não foi possível concluir a operação. Tente novamente.';

/// Traduz [erro] em mensagem segura para exibição.
String mensagemDeErro(Object? erro) {
  if (erro is ApiException) return _porStatus(erro.statusCode);
  if (erro is Exception) {
    final texto = erro.toString().replaceFirst('Exception: ', '').trim();
    return texto.isEmpty ? _generica : texto;
  }
  return _generica;
}

String _porStatus(int statusCode) {
  if (statusCode == 401) return 'Sessão expirada. Faça login novamente.';
  if (statusCode == 403) return 'Você não tem permissão para esta ação.';
  if (statusCode == 404) return 'Não encontramos o que você procura.';
  if (statusCode == 409) {
    return 'Esta operação conflita com o estado atual. Atualize a tela e tente novamente.';
  }
  if (statusCode == 413) return 'Arquivo grande demais.';
  if (statusCode == 415) return 'Tipo de arquivo não suportado.';
  if (statusCode == 400 || statusCode == 422) {
    return 'Dados inválidos. Revise as informações e tente novamente.';
  }
  if (statusCode == 429) {
    return 'Muitas tentativas. Aguarde um instante e tente novamente.';
  }
  if (statusCode >= 500) return 'Erro no servidor. Tente novamente em instantes.';
  return _generica;
}
