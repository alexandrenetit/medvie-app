// test/core/services/medvie_api_service_certificado_test.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

const _baseUrl = 'https://api.example.test';
const _cnpjId = 'cnpj-abc';

MedvieApiService _service(http.Client client) {
  final service = MedvieApiService(client: client);
  service.baseUrl = _baseUrl;
  return service;
}

Map<String, dynamic> _certificadoJson({
  String subjectCnpj = '12345678000190',
  String fingerprint = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
}) => <String, dynamic>{
  'status': 'ativo',
  'subjectCnpj': subjectCnpj,
  'issuerName': 'AC SOLUTI',
  'validFrom': '2026-01-01T00:00:00.000Z',
  'validUntil': '2027-01-01T00:00:00.000Z',
  'fingerprintSha256': fingerprint,
  'restritoAoCnpj': false,
  'provider': 'PlugNotas',
  'provisionadoEm': '2026-05-24T10:00:00.000Z',
  'diasParaVencer': 222,
};

http.Response _jsonResponse(Map<String, dynamic> body, int status) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _errorResponse(String code, int status) => http.Response(
  jsonEncode({'code': code, 'description': 'Mensagem $code'}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Uint8List _fakeBytes() => Uint8List.fromList([1, 2, 3, 4]);

void main() {
  group('uploadCertificado', () {
    test('201 retorna CertificadoMetadata com subjectCnpj correto', () async {
      final client = MockClient(
        (_) async => _jsonResponse(_certificadoJson(), 201),
      );
      final service = _service(client);

      final metadata = await service.uploadCertificado(
        _cnpjId,
        _fakeBytes(),
        'senha-segura',
        false,
      );

      expect(metadata.subjectCnpj, '12345678000190');
      expect(metadata.status, StatusCertificado.ativo);
    });

    test('200 idempotente preserva mesmo fingerprint', () async {
      const fp =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final client = MockClient(
        (_) async => _jsonResponse(_certificadoJson(fingerprint: fp), 200),
      );
      final service = _service(client);

      final metadata = await service.uploadCertificado(
        _cnpjId,
        _fakeBytes(),
        'senha',
        true,
      );

      expect(metadata.fingerprintSha256, fp);
    });

    test(
      '422 cada um dos 6 códigos canônicos preserva ApiException.code',
      () async {
        const codes = <String>[
          'Certificado.SenhaInvalida',
          'Certificado.FormatoInvalido',
          'Certificado.CnpjDivergente',
          'Certificado.Vencido',
          'Certificado.SemCnpjNoSubject',
          'Certificado.ProviderRecusou',
        ];

        for (final code in codes) {
          final client = MockClient((_) async => _errorResponse(code, 422));
          final service = _service(client);

          await expectLater(
            () => service.uploadCertificado(
              _cnpjId,
              _fakeBytes(),
              'qualquer',
              false,
            ),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.statusCode, 'statusCode', 422)
                  .having((e) => e.code, 'code', code),
            ),
            reason: 'Falhou para o código $code',
          );
        }
      },
    );

    test('429 rate limit lança ApiException', () async {
      final client = MockClient(
        (_) async => _errorResponse('RateLimit.Excedido', 429),
      );
      final service = _service(client);

      await expectLater(
        () => service.uploadCertificado(
          _cnpjId,
          _fakeBytes(),
          'qualquer',
          false,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('bytes zerados ao final (best-effort)', () async {
      final client = MockClient(
        (_) async => _jsonResponse(_certificadoJson(), 201),
      );
      final service = _service(client);
      final bytes = Uint8List.fromList([9, 9, 9, 9]);

      await service.uploadCertificado(_cnpjId, bytes, 'senha', false);

      expect(bytes, everyElement(0));
    });
  });

  group('consultarCertificado', () {
    test('200 retorna CertificadoMetadata', () async {
      final client = MockClient(
        (_) async => _jsonResponse(_certificadoJson(), 200),
      );
      final service = _service(client);

      final metadata = await service.consultarCertificado(_cnpjId);

      expect(metadata, isNotNull);
      expect(metadata!.subjectCnpj, '12345678000190');
    });

    test('404 retorna null (estado normal sem certificado)', () async {
      final client = MockClient((_) async => http.Response('', 404));
      final service = _service(client);

      final metadata = await service.consultarCertificado(_cnpjId);

      expect(metadata, isNull);
    });
  });

  group('removerCertificado', () {
    test('204 completa sem throw', () async {
      final client = MockClient((_) async => http.Response('', 204));
      final service = _service(client);

      await expectLater(service.removerCertificado(_cnpjId), completes);
    });

    test('409 lança ApiException(Certificado.JaRemovido)', () async {
      final client = MockClient((_) async => http.Response('', 409));
      final service = _service(client);

      await expectLater(
        () => service.removerCertificado(_cnpjId),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'Certificado.JaRemovido'),
        ),
      );
    });
  });
}
