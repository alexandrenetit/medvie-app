// test/core/models/servico_pf_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/medico.dart' show TipoTomador;
import 'package:medvie/core/models/servico.dart';

/// Linha de `GET /api/v1/servicos` para tomador PF (contrato 017).
/// `tomadorCnpj` chega null — não pode quebrar o parsing (FR-009/SC-005).
Map<String, dynamic> _servicoPf() => <String, dynamic>{
      'id': 'guid-serv-1',
      'tipoServico': 'Consulta',
      'competencia': '2026-06-09',
      'tomadorId': 'guid-tom-1',
      'tomadorNome': 'Julia M. Ramos',
      'tomadorCnpj': null,
      'tomadorTipo': 'CPF',
      'tomadorDocumentoMascarado': '***.***.***-09',
      'tomadorEnderecoFiscalStatus': 'Completo',
      'valor': 500.00,
      'status': 'pendente',
    };

/// Serviço CNPJ legado — sem campos PF nem `tomadorTipo`.
Map<String, dynamic> _servicoCnpjLegado() => <String, dynamic>{
      'id': 'guid-serv-2',
      'tipoServico': 'PlantaoClinico',
      'competencia': '2026-06-01',
      'tomadorCnpj': '12.345.678/0001-90',
      'tomadorNome': 'Hospital Sao Lucas',
      'valor': 1200.00,
      'status': 'nfEmitida',
    };

void main() {
  group('Servico PF (feature 017)', () {
    test('fromJson lê tomadorTipo/mascarado/status', () {
      final s = Servico.fromJson(_servicoPf());
      expect(s.tomadorTipo, TipoTomador.cpf);
      expect(s.tomadorEhPf, isTrue);
      expect(s.tomadorDocumentoMascarado, '***.***.***-09');
      expect(s.tomadorEnderecoFiscalStatus, 'Completo');
    });

    test('FR-009/SC-005: tomadorCnpj null não quebra e vira string vazia', () {
      final s = Servico.fromJson(_servicoPf());
      expect(s.tomadorCnpj, '');
      expect(s.tomadorNome, 'Julia M. Ramos');
    });

    test('documento de exibição usa mascarado para PF', () {
      final s = Servico.fromJson(_servicoPf());
      expect(s.tomadorDocumentoExibicao, '***.***.***-09');
    });

    test('SC-004: nenhum CPF bruto no toJson', () {
      final s = Servico.fromJson(_servicoPf());
      final dump = s.toJson().toString();
      expect(dump.contains('12345678909'), isFalse);
      expect(s.toJson()['tomadorTipo'], 'CPF');
      expect(s.toJson()['tomadorDocumentoMascarado'], '***.***.***-09');
    });

    test('copyWith preserva campos PF', () {
      final s = Servico.fromJson(_servicoPf()).copyWith(valor: 600.0);
      expect(s.valor, 600.0);
      expect(s.tomadorTipo, TipoTomador.cpf);
      expect(s.tomadorDocumentoMascarado, '***.***.***-09');
      expect(s.tomadorEnderecoFiscalStatus, 'Completo');
    });
  });

  group('TipoServico.backendEnumName', () {
    test('mapeia cada tipo para o nome do enum .NET', () {
      expect(TipoServico.plantao.backendEnumName, 'PlantaoClinico');
      expect(TipoServico.atoAnestesico.backendEnumName, 'AtoAnestesico');
      expect(TipoServico.laudo.backendEnumName, 'LaudoImagem');
      expect(
        TipoServico.procedimentoCirurgico.backendEnumName,
        'ProcedimentoEndoscopico',
      );
      expect(TipoServico.consulta.backendEnumName, 'Consulta');
      expect(TipoServico.outros.backendEnumName, 'Outros');
    });

    test('toJson usa backendEnumName (fonte única)', () {
      final s = Servico.fromJson(_servicoPf());
      expect(s.toJson()['tipoServico'], TipoServico.consulta.backendEnumName);
    });
  });

  group('Servico CNPJ legado (compat)', () {
    test('payload sem campos PF assume tomadorTipo cnpj', () {
      final s = Servico.fromJson(_servicoCnpjLegado());
      expect(s.tomadorTipo, TipoTomador.cnpj);
      expect(s.tomadorEhPf, isFalse);
      expect(s.tomadorDocumentoMascarado, '');
      expect(s.tomadorEnderecoFiscalStatus, '');
    });

    test('documento de exibição usa CNPJ para tomador CNPJ', () {
      final s = Servico.fromJson(_servicoCnpjLegado());
      expect(s.tomadorDocumentoExibicao, '12.345.678/0001-90');
    });
  });
}
