import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/models/servico.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

import '../test_helpers.dart';

void main() {
  group('Fixtures atendimento PF (T002)', () {
    test('tomador_pf_completo → lookup encontrado e endereço completo', () {
      final json = loadFixture('atendimento_pf/tomador_pf_completo.json');
      final res = LookupTomadorResponse.fromJson(json);

      expect(res.encontrado, isTrue);
      expect(res.nome, 'Julia M. Ramos');
      expect(res.email, 'julia@example.com');
      expect(res.endereco, isNotNull);
      expect(res.endereco!.completo, isTrue);
      expect(res.enderecoFiscalCompleto, isTrue);
      expect(res.ultimoServico, isNotNull);
      expect(res.ultimoServico!.tipoServico, 'Consulta');
      // SC-004: documento só mascarado.
      expect(res.documentoMascarado.contains('*'), isTrue);
    });

    test('tomador_pf_incompleto → endereço fiscal não libera emissão', () {
      final json = loadFixture('atendimento_pf/tomador_pf_incompleto.json');
      final res = LookupTomadorResponse.fromJson(json);

      expect(res.encontrado, isTrue);
      expect(res.enderecoFiscalStatus, 'Incompleto');
      expect(res.endereco!.completo, isFalse);
      expect(res.enderecoFiscalCompleto, isFalse);
    });

    test('servico_pf_lista → linhas PF parseiam sem CNPJ (SC-005)', () {
      final lista = loadFixtureList('atendimento_pf/servico_pf_lista.json');
      final servicos = lista.map(Servico.fromJson).toList();

      expect(servicos.length, 2);
      expect(servicos.every((s) => s.tomadorTipo == TipoTomador.cpf), isTrue);
      expect(servicos.every((s) => s.tomadorCnpj.isEmpty), isTrue);
      expect(servicos.first.tomadorEnderecoFiscalStatus, 'Completo');
      expect(servicos[1].tomadorEnderecoFiscalStatus, 'Incompleto');
    });
  });
}
