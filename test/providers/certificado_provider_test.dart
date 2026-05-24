// test/providers/certificado_provider_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medvie/core/errors/api_error.dart';
import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/models/certificado_metadata.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/certificado_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

class _MockApi extends Mock implements MedvieApiService {}

CertificadoMetadata _meta({String subjectCnpj = '12345678000190'}) =>
    CertificadoMetadata(
      status: StatusCertificado.ativo,
      subjectCnpj: subjectCnpj,
      issuerName: 'AC SOLUTI',
      validFrom: DateTime.utc(2026, 1, 1),
      validUntil: DateTime.utc(2027, 1, 1),
      fingerprintSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      restritoAoCnpj: false,
      diasParaVencer: 222,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late _MockApi api;
  late CertificadoProvider provider;

  setUp(() {
    api = _MockApi();
    provider = CertificadoProvider(api);
  });

  test('estado inicial é CertificadoIdle', () {
    expect(provider.state, isA<CertificadoIdle>());
  });

  test(
    'enviar OK: Idle → Uploading → Success com notify em cada transição',
    () async {
      final states = <CertificadoState>[];
      provider.addListener(() => states.add(provider.state));

      when(
        () => api.uploadCertificado(any(), any(), any(), any()),
      ).thenAnswer((_) async => _meta());

      await provider.enviar(
        'cnpj-1',
        Uint8List.fromList([1, 2]),
        'senha',
        false,
      );

      expect(states.length, 2, reason: 'Uploading + Success → 2 notifies');
      expect(states[0], isA<CertificadoUploading>());
      expect(states[1], isA<CertificadoSuccess>());
      expect(
        (states[1] as CertificadoSuccess).metadata.subjectCnpj,
        '12345678000190',
      );
    },
  );

  test(
    'enviar 422 SenhaInvalida vira CertificadoErro com código preservado',
    () async {
      when(() => api.uploadCertificado(any(), any(), any(), any())).thenThrow(
        const ApiException(
          ApiError(
            statusCode: 422,
            code: 'Certificado.SenhaInvalida',
            description: 'Senha do certificado inválida.',
          ),
        ),
      );

      await provider.enviar('cnpj', Uint8List(0), 's', false);

      expect(provider.state, isA<CertificadoErro>());
      final erro = provider.state as CertificadoErro;
      expect(erro.codigo, 'Certificado.SenhaInvalida');
      expect(erro.mensagem, 'Senha do certificado inválida.');
    },
  );

  test('carregar 404 mantém Idle (não vira CertificadoErro)', () async {
    when(() => api.consultarCertificado(any())).thenAnswer((_) async => null);

    var notifyCount = 0;
    provider.addListener(() => notifyCount++);

    await provider.carregar('cnpj');

    expect(provider.state, isA<CertificadoIdle>());
    expect(notifyCount, 1, reason: 'carregar sempre notifica no finally');
  });

  test('carregar 200 vira CertificadoSuccess', () async {
    when(() => api.consultarCertificado(any())).thenAnswer((_) async => _meta());

    await provider.carregar('cnpj');

    expect(provider.state, isA<CertificadoSuccess>());
  });

  test('remover OK volta para CertificadoIdle a partir de Success', () async {
    when(() => api.consultarCertificado(any())).thenAnswer((_) async => _meta());
    await provider.carregar('cnpj');
    expect(provider.state, isA<CertificadoSuccess>());

    when(() => api.removerCertificado(any())).thenAnswer((_) async {});

    await provider.remover('cnpj');

    expect(provider.state, isA<CertificadoIdle>());
  });

  test(
    'remover 409 (Certificado.JaRemovido) propaga CertificadoErro sem dependência externa',
    () async {
      when(() => api.removerCertificado(any())).thenThrow(
        const ApiException(
          ApiError(
            statusCode: 409,
            code: 'Certificado.JaRemovido',
            description: 'Certificado já removido.',
          ),
        ),
      );

      await provider.remover('cnpj');

      expect(provider.state, isA<CertificadoErro>());
      final erro = provider.state as CertificadoErro;
      expect(erro.codigo, 'Certificado.JaRemovido');
    },
  );
}
