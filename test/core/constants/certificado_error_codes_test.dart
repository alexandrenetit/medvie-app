// test/core/constants/certificado_error_codes_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/constants/certificado_error_codes.dart';

void main() {
  group('traduzir — códigos canônicos do contrato', () {
    test('Certificado.SenhaInvalida', () {
      expect(
        traduzir('Certificado.SenhaInvalida'),
        'Senha do certificado inválida.',
      );
    });

    test('Certificado.FormatoInvalido', () {
      expect(
        traduzir('Certificado.FormatoInvalido'),
        'Arquivo PFX/P12 inválido ou corrompido.',
      );
    });

    test('Certificado.CnpjDivergente', () {
      expect(
        traduzir('Certificado.CnpjDivergente'),
        'CNPJ do certificado não bate com o CNPJ informado.',
      );
    });

    test('Certificado.Vencido', () {
      expect(
        traduzir('Certificado.Vencido'),
        'Certificado vencido.',
      );
    });

    test('Certificado.SemCnpjNoSubject', () {
      expect(
        traduzir('Certificado.SemCnpjNoSubject'),
        'Certificado não contém CNPJ no Subject/SAN.',
      );
    });

    test('Certificado.ProviderRecusou', () {
      expect(
        traduzir('Certificado.ProviderRecusou'),
        'Provedor de NFS-e recusou o certificado.',
      );
    });
  });

  group('traduzir — fallback', () {
    test('código desconhecido + fallback custom retorna o custom', () {
      expect(
        traduzir('Certificado.Inexistente', fallback: 'Mensagem custom.'),
        'Mensagem custom.',
      );
    });

    test('código desconhecido sem fallback retorna mensagem default', () {
      expect(
        traduzir('Certificado.Inexistente'),
        'Erro inesperado no certificado.',
      );
    });

    test('string vazia cai no fallback default', () {
      expect(
        traduzir(''),
        'Erro inesperado no certificado.',
      );
    });
  });
}
