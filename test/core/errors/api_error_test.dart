// test/core/errors/api_error_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medvie/core/errors/api_error.dart';
import 'package:medvie/core/errors/api_exception.dart';

import '../../test_helpers.dart';

void main() {
  group('ApiError.from', () {
    test('1. parses code/description from JSON body at status 400', () {
      final response = http.Response('{"code":"X","description":"Y"}', 400);
      final error = ApiError.from(response);

      expect(error.statusCode, 400);
      expect(error.code, 'X');
      expect(error.description, 'Y');
      expect(error.isBadRequest, isTrue);
    });

    test(
      '2. empty body at status 500 → code/description null, isServerError true',
      () {
        final response = http.Response('', 500);
        final error = ApiError.from(response);

        expect(error.statusCode, 500);
        expect(error.code, isNull);
        expect(error.description, isNull);
        expect(error.rawBody, anyOf(isNull, isEmpty));
        expect(error.isServerError, isTrue);
      },
    );

    test(
      '3. invalid JSON body → no throw, rawBody truncated to 500 chars, code/description null',
      () {
        final longInvalid = 'not-json-' * 100; // 900 chars
        final response = http.Response(longInvalid, 400);

        late ApiError error;
        expect(() => error = ApiError.from(response), returnsNormally);

        expect(error.code, isNull);
        expect(error.description, isNull);
        expect(error.rawBody, isNotNull);
        expect(error.rawBody!.length, lessThanOrEqualTo(500));
      },
    );

    test('4. valid JSON without code/description → no throw, both null', () {
      final response = http.Response('{"other":"field"}', 400);

      late ApiError error;
      expect(() => error = ApiError.from(response), returnsNormally);

      expect(error.code, isNull);
      expect(error.description, isNull);
    });

    final fixtureCases = [
      (
        name: 'api_error_400.json',
        statusCode: 400,
        code: 'PlugNotas.ValidacaoFiscal.CnpjInvalido',
        description: 'CNPJ inválido.',
        getter: (ApiError e) => e.isBadRequest,
      ),
      (
        name: 'api_error_403.json',
        statusCode: 403,
        code: 'PlugNotas.Autorizacao.Negada',
        description: 'Operação não permitida para este usuário.',
        getter: (ApiError e) => e.isForbidden,
      ),
      (
        name: 'api_error_404.json',
        statusCode: 404,
        code: 'PlugNotas.NotaFiscal.NaoEncontrada',
        description: 'Nota fiscal não encontrada.',
        getter: (ApiError e) => e.isNotFound,
      ),
      (
        name: 'api_error_422.json',
        statusCode: 422,
        code: 'PlugNotas.ValidacaoFiscal.CamposInvalidos',
        description: 'Existem campos fiscais inválidos.',
        getter: (ApiError e) => e.isValidation,
      ),
    ];

    for (final fixtureCase in fixtureCases) {
      test('fixture ${fixtureCase.name} preserva contrato', () {
        final response = http.Response(
          jsonEncode(loadFixture('notas/${fixtureCase.name}')),
          fixtureCase.statusCode,
        );
        final error = ApiError.from(response);

        expect(error.statusCode, fixtureCase.statusCode);
        expect(error.code, fixtureCase.code);
        expect(error.description, fixtureCase.description);
        expect(fixtureCase.getter(error), isTrue);
      });
    }
  });

  group('ApiError status getters', () {
    final statuses = {
      400: (ApiError e) => e.isBadRequest,
      401: (ApiError e) => e.isUnauthorized,
      403: (ApiError e) => e.isForbidden,
      404: (ApiError e) => e.isNotFound,
      422: (ApiError e) => e.isValidation,
      429: (ApiError e) => e.isRateLimited,
    };

    for (final entry in statuses.entries) {
      final targetStatus = entry.key;
      final getter = entry.value;

      test('getter for $targetStatus returns true only for $targetStatus', () {
        expect(getter(ApiError(statusCode: targetStatus)), isTrue);
        for (final other in statuses.keys.where((s) => s != targetStatus)) {
          expect(
            getter(ApiError(statusCode: other)),
            isFalse,
            reason: 'should be false for $other',
          );
        }
      });
    }

    test('isServerError true for 500+, false below', () {
      expect(const ApiError(statusCode: 500).isServerError, isTrue);
      expect(const ApiError(statusCode: 503).isServerError, isTrue);
      expect(const ApiError(statusCode: 499).isServerError, isFalse);
    });
  });

  group('ApiException', () {
    test('6. toString() == error.toString()', () {
      const error = ApiError(statusCode: 422, code: 'E', description: 'msg');
      const exception = ApiException(error);

      expect(exception.toString(), equals(error.toString()));
    });

    test('delegates getters to ApiError', () {
      const error = ApiError(statusCode: 422, code: 'E', description: 'D');
      const exception = ApiException(error);

      expect(exception.statusCode, 422);
      expect(exception.code, 'E');
      expect(exception.description, 'D');
      expect(exception.isValidation, isTrue);
      expect(exception.isServerError, isFalse);
    });

    test('is catchable as Exception', () {
      const error = ApiError(statusCode: 400);
      Exception? caught;
      try {
        throw const ApiException(error);
      } on Exception catch (e) {
        caught = e;
      }
      expect(caught, isA<ApiException>());
    });
  });
}
