// test/core/models/certificado_metadata_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/certificado_metadata.dart';
import 'package:medvie/core/models/medico.dart';

Map<String, dynamic> _payloadCompleto() => <String, dynamic>{
      'status': 'ativo',
      'subjectCnpj': '12.345.678/0001-90',
      'issuerName': 'AC Certisign RFB G5',
      'validFrom': '2026-01-15T00:00:00.000Z',
      'validUntil': '2027-01-15T23:59:59.000Z',
      'fingerprintSha256':
          'a3f8b1c2d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f',
      'restritoAoCnpj': true,
      'provider': 'PlugNotas',
      'provisionadoEm': '2026-02-01T10:30:00.000Z',
      'diasParaVencer': 365,
    };

void main() {
  group('CertificadoMetadata.fromJson', () {
    test('payload completo do OpenAPI preenche todos os campos', () {
      final m = CertificadoMetadata.fromJson(_payloadCompleto());

      expect(m.status, StatusCertificado.ativo);
      expect(m.subjectCnpj, '12.345.678/0001-90');
      expect(m.issuerName, 'AC Certisign RFB G5');
      expect(m.validFrom.isUtc, isTrue);
      expect(m.validFrom, DateTime.utc(2026, 1, 15));
      expect(m.validUntil.isUtc, isTrue);
      expect(m.validUntil, DateTime.utc(2027, 1, 15, 23, 59, 59));
      expect(m.fingerprintSha256.length, 64);
      expect(m.restritoAoCnpj, isTrue);
      expect(m.provider, 'PlugNotas');
      expect(m.provisionadoEm, DateTime.utc(2026, 2, 1, 10, 30));
      expect(m.diasParaVencer, 365);
    });

    test('diasParaVencer é lido do payload (server-calculated)', () {
      final m = CertificadoMetadata.fromJson(
        _payloadCompleto()..['diasParaVencer'] = -3,
      );
      expect(m.diasParaVencer, -3);
    });

    test('provider null é aceito', () {
      final m = CertificadoMetadata.fromJson(
        _payloadCompleto()..['provider'] = null,
      );
      expect(m.provider, isNull);
    });

    test('provider arbitrário (futuro) aceito sem throw — campo é String', () {
      final m = CertificadoMetadata.fromJson(
        _payloadCompleto()..['provider'] = 'FuturoProvider',
      );
      expect(m.provider, 'FuturoProvider');
    });

    test('validFrom sem flag UTC (sem "Z") lança FormatException', () {
      final payload = _payloadCompleto()
        ..['validFrom'] = '2026-01-15T00:00:00';
      expect(
        () => CertificadoMetadata.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('validUntil ausente lança FormatException', () {
      final payload = _payloadCompleto()..['validUntil'] = null;
      expect(
        () => CertificadoMetadata.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('diasParaVencer ausente lança FormatException', () {
      final payload = _payloadCompleto()..remove('diasParaVencer');
      expect(
        () => CertificadoMetadata.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CertificadoMetadata.toJson', () {
    test('round-trip preserva todos os campos', () {
      final original = CertificadoMetadata.fromJson(_payloadCompleto());
      final round = CertificadoMetadata.fromJson(original.toJson());

      expect(round.status, original.status);
      expect(round.subjectCnpj, original.subjectCnpj);
      expect(round.issuerName, original.issuerName);
      expect(round.validFrom, original.validFrom);
      expect(round.validUntil, original.validUntil);
      expect(round.fingerprintSha256, original.fingerprintSha256);
      expect(round.restritoAoCnpj, original.restritoAoCnpj);
      expect(round.provider, original.provider);
      expect(round.provisionadoEm, original.provisionadoEm);
      expect(round.diasParaVencer, original.diasParaVencer);
    });

    test('round-trip com provider null e provisionadoEm null', () {
      final payload = _payloadCompleto()
        ..['provider'] = null
        ..['provisionadoEm'] = null;
      final original = CertificadoMetadata.fromJson(payload);
      final round = CertificadoMetadata.fromJson(original.toJson());

      expect(round.provider, isNull);
      expect(round.provisionadoEm, isNull);
    });
  });
}
