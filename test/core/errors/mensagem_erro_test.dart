// test/core/errors/mensagem_erro_test.dart
//
// SEC-014: a mensagem exibida ao usuário nunca pode conter corpo, código
// interno, path ou status vindos do backend.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:medvie/core/errors/api_error.dart';
import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/errors/mensagem_erro.dart';

ApiException _apiException(int statusCode, {String body = ''}) =>
    ApiException(ApiError.from(http.Response(body, statusCode)));

void main() {
  group('mensagemDeErro — ApiException traduz por status', () {
    test('429 devolve mensagem de espera igual à do web', () {
      expect(
        mensagemDeErro(_apiException(429)),
        'Muitas tentativas. Aguarde um instante e tente novamente.',
      );
    });

    test('401 orienta novo login', () {
      expect(
        mensagemDeErro(_apiException(401)),
        'Sessão expirada. Faça login novamente.',
      );
    });

    test('403 informa falta de permissão', () {
      expect(
        mensagemDeErro(_apiException(403)),
        'Você não tem permissão para esta ação.',
      );
    });

    test('422 pede revisão dos dados', () {
      expect(
        mensagemDeErro(_apiException(422)),
        'Dados inválidos. Revise as informações e tente novamente.',
      );
    });

    test('500 aponta falha do servidor', () {
      expect(
        mensagemDeErro(_apiException(500)),
        'Erro no servidor. Tente novamente em instantes.',
      );
    });

    test('status sem tradução dedicada cai na mensagem genérica', () {
      expect(
        mensagemDeErro(_apiException(418)),
        'Não foi possível concluir a operação. Tente novamente.',
      );
    });
  });

  group('mensagemDeErro — não vaza detalhe do backend (SEC-014)', () {
    test('corpo ProblemDetails com code/description não chega à mensagem', () {
      final erro = _apiException(
        409,
        body: jsonEncode({
          'code': 'Conflict.Servico.NotaVinculada',
          'description': 'servico 8f2e-4a1b possui nota fiscal 1234 vinculada',
        }),
      );

      final mensagem = mensagemDeErro(erro);

      expect(mensagem, isNot(contains('Conflict.Servico')));
      expect(mensagem, isNot(contains('8f2e-4a1b')));
      expect(mensagem, isNot(contains('nota fiscal 1234')));
      expect(mensagem, isNot(contains('409')));
    });

    test('corpo não-JSON (rawBody) não chega à mensagem', () {
      final erro = _apiException(
        500,
        body: 'System.NullReferenceException at Medvie.Api.Controllers.X',
      );

      final mensagem = mensagemDeErro(erro);

      expect(mensagem, isNot(contains('NullReferenceException')));
      expect(mensagem, isNot(contains('Medvie.Api')));
      expect(mensagem, 'Erro no servidor. Tente novamente em instantes.');
    });

    test('detalhe segue disponível no objeto para telemetria', () {
      final erro = _apiException(
        409,
        body: jsonEncode({'code': 'X.Y', 'description': 'detalhe interno'}),
      );

      // O que a tela mostra ≠ o que o app pode logar.
      expect(erro.code, 'X.Y');
      expect(erro.description, 'detalhe interno');
      expect(mensagemDeErro(erro), isNot(contains('detalhe interno')));
    });
  });

  group('mensagemDeErro — Exception de negócio passa direto', () {
    test('mensagem já traduzida é preservada sem o prefixo Exception', () {
      expect(
        mensagemDeErro(Exception('CPF ou senha inválidos.')),
        'CPF ou senha inválidos.',
      );
    });

    test('Exception sem texto cai na genérica', () {
      expect(
        mensagemDeErro(Exception('')),
        'Não foi possível concluir a operação. Tente novamente.',
      );
    });

    test('objeto não-Exception cai na genérica', () {
      expect(
        mensagemDeErro('falha crua'),
        'Não foi possível concluir a operação. Tente novamente.',
      );
    });

    test('null cai na genérica', () {
      expect(
        mensagemDeErro(null),
        'Não foi possível concluir a operação. Tente novamente.',
      );
    });
  });
}
