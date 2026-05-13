import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/models/notas_pagina.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

import '../../test_helpers.dart';

const _baseUrl = 'https://api.example.test';

MedvieApiService _service(http.Client client) {
  final service = MedvieApiService(client: client);
  service.baseUrl = _baseUrl;
  return service;
}

String _fixture(String name) => jsonEncode(loadFixture('notas/$name'));

http.Response _fixtureResponse(String name, int statusCode) => http.Response(
  _fixture(name),
  statusCode,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<String?> _emitirNotaValida(
  MedvieApiService service, {
  double? aliquotaIss,
  bool? issRetido,
}) {
  return service.emitirNota(
    servicoId: 'servico-001',
    cnpjProprioId: 'cnpj-001',
    tomadorId: 'tomador-001',
    aliquotaIss: aliquotaIss,
    issRetido: issRetido,
  );
}

void main() {
  group('cadastrarEmitente', () {
    test('204 sucesso posta contrato esperado', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 204);
      });
      final service = _service(client);

      await expectLater(service.cadastrarEmitente('cnpj-001'), completes);

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, endsWith('/notas/emitentes'));
      expect(
        capturedRequest.headers['content-type'],
        contains('application/json'),
      );
      expect(jsonDecode(capturedRequest.body), {'cnpjProprioId': 'cnpj-001'});
    });

    test('400 erro preserva ApiException', () async {
      final client = MockClient(
        (_) async => _fixtureResponse('cadastrar_emitente_400.json', 400),
      );
      final service = _service(client);

      await expectLater(
        () => service.cadastrarEmitente('cnpj-001'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.code,
                'code',
                'PlugNotas.Emitente.CnpjProprioInvalido',
              )
              .having(
                (e) => e.description,
                'description',
                'CNPJ próprio inválido ou não encontrado.',
              ),
        ),
      );
    });
  });

  group('emitirNota', () {
    test('201 sucesso retorna notaFiscalId', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/notas'));
        return _fixtureResponse('emitir_nota_201.json', 201);
      });
      final service = _service(client);

      final id = await _emitirNotaValida(service);

      expect(id, 'nota-emitida-201');
    });

    test('202 sucesso retorna notaFiscalId', () async {
      final client = MockClient(
        (_) async => _fixtureResponse('emitir_nota_202.json', 202),
      );
      final service = _service(client);

      final id = await _emitirNotaValida(service);

      expect(id, 'nota-processando-202');
    });

    test('omite opcionais null do body', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return _fixtureResponse('emitir_nota_201.json', 201);
      });
      final service = _service(client);

      await _emitirNotaValida(service, aliquotaIss: null, issRetido: null);
      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;

      expect(body['servicoId'], 'servico-001');
      expect(body['cnpjProprioId'], 'cnpj-001');
      expect(body['tomadorId'], 'tomador-001');
      expect(body.containsKey('aliquotaIss'), isFalse);
      expect(body.containsKey('issRetido'), isFalse);
    });

    test('inclui opcionais nao-null no body', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return _fixtureResponse('emitir_nota_201.json', 201);
      });
      final service = _service(client);

      await _emitirNotaValida(service, aliquotaIss: 2.5, issRetido: true);
      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;

      expect(body['aliquotaIss'], 2.5);
      expect(body['issRetido'], isTrue);
    });

    for (final errorCase in [
      (
        fixture: 'emitir_nota_400.json',
        statusCode: 400,
        code: 'PlugNotas.ValidacaoFiscal.CnpjInvalido',
      ),
      (
        fixture: 'emitir_nota_422.json',
        statusCode: 422,
        code: 'PlugNotas.ValidacaoFiscal.CodigoNbsObrigatorio',
      ),
    ]) {
      test('${errorCase.statusCode} erro preserva ApiException', () async {
        final client = MockClient(
          (_) async =>
              _fixtureResponse(errorCase.fixture, errorCase.statusCode),
        );
        final service = _service(client);

        await expectLater(
          () => _emitirNotaValida(service),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', errorCase.statusCode)
                .having((e) => e.code, 'code', errorCase.code),
          ),
        );
      });
    }

    test('202 body vazio retorna null', () async {
      final client = MockClient((_) async => http.Response('', 202));
      final service = _service(client);

      final id = await _emitirNotaValida(service);

      expect(id, isNull);
    });

    test('202 sem notaFiscalId retorna null', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'id': 'nota-sem-campo'}), 202),
      );
      final service = _service(client);

      final id = await _emitirNotaValida(service);

      expect(id, isNull);
    });

    test('201 sem notaFiscalId falha com ApiException', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'id': 'nota-sem-campo'}), 201),
      );
      final service = _service(client);

      await expectLater(
        () => _emitirNotaValida(service),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 201)
              .having((e) => e.code, 'code', 'Contrato.Invalido'),
        ),
      );
    });
  });

  group('cancelarNota', () {
    test('204 sucesso envia DELETE com body esperado', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 204);
      });
      final service = _service(client);

      await expectLater(
        service.cancelarNota('nota-001', 'cnpj-001', 'Duplicidade'),
        completes,
      );

      expect(capturedRequest.method, 'DELETE');
      expect(capturedRequest.url.path, endsWith('/notas/nota-001'));
      expect(jsonDecode(capturedRequest.body), {
        'cnpjProprioId': 'cnpj-001',
        'motivo': 'Duplicidade',
      });
    });

    test('403 erro preserva ApiException', () async {
      final client = MockClient(
        (_) async => _fixtureResponse('cancelar_nota_403.json', 403),
      );
      final service = _service(client);

      await expectLater(
        () => service.cancelarNota('nota-001', 'cnpj-001', 'Duplicidade'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.code,
                'code',
                'PlugNotas.Cancelamento.NaoPermitido',
              ),
        ),
      );
    });
  });

  group('listarNotas', () {
    test('200 pagina com itens retorna NotasPagina', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return _fixtureResponse('listar_notas_pagina_com_itens.json', 200);
      });
      final service = _service(client);

      final pagina = await service.listarNotas('cnpj-001');

      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, endsWith('/notas'));
      expect(capturedRequest.url.queryParameters['cnpjProprioId'], 'cnpj-001');
      expect(capturedRequest.url.queryParameters['pagina'], '1');
      expect(capturedRequest.url.queryParameters['tamanhoPagina'], '20');
      expect(pagina, isA<NotasPagina>());
      expect(pagina.total, 2);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
      expect(pagina.notas, hasLength(2));
    });

    test('200 pagina vazia retorna lista vazia', () async {
      final client = MockClient(
        (_) async => _fixtureResponse('listar_notas_pagina_vazia.json', 200),
      );
      final service = _service(client);

      final pagina = await service.listarNotas('cnpj-001');

      expect(pagina.notas, isEmpty);
      expect(pagina.total, 0);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
    });

    for (final errorCase in [
      (fixture: 'api_error_400.json', statusCode: 400),
      (fixture: 'api_error_403.json', statusCode: 403),
    ]) {
      test('${errorCase.statusCode} erro preserva ApiException', () async {
        final client = MockClient(
          (_) async =>
              _fixtureResponse(errorCase.fixture, errorCase.statusCode),
        );
        final service = _service(client);

        await expectLater(
          () => service.listarNotas('cnpj-001'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              errorCase.statusCode,
            ),
          ),
        );
      });
    }
  });
}
