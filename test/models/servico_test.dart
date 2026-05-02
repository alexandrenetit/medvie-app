// test/models/servico_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/servico.dart';
import '../test_helpers.dart';

void main() {
  // ── TipoServico ──────────────────────────────────────────────────────────

  group('TipoServico.fromJson', () {
    test('reconhece todos os valores do enum (case-insensitive)', () {
      expect(TipoServicoExtension.fromJson('plantao'), TipoServico.plantao);
      expect(TipoServicoExtension.fromJson('PLANTAO'), TipoServico.plantao);
      expect(TipoServicoExtension.fromJson('atoAnestesico'), TipoServico.atoAnestesico);
      expect(TipoServicoExtension.fromJson('laudo'), TipoServico.laudo);
      expect(TipoServicoExtension.fromJson('procedimentoCirurgico'), TipoServico.procedimentoCirurgico);
      expect(TipoServicoExtension.fromJson('consulta'), TipoServico.consulta);
      expect(TipoServicoExtension.fromJson('outros'), TipoServico.outros);
    });

    test('valor desconhecido retorna plantao via orElse', () {
      expect(TipoServicoExtension.fromJson('valorInvalido'), TipoServico.plantao);
    });
  });

  group('TipoServico extensions', () {
    test('label retorna texto legível para cada tipo', () {
      expect(TipoServico.plantao.label, 'Plantão');
      expect(TipoServico.atoAnestesico.label, 'Ato Anestésico');
      expect(TipoServico.laudo.label, 'Laudo / Exame');
      expect(TipoServico.procedimentoCirurgico.label, 'Procedimento Cirúrgico');
      expect(TipoServico.consulta.label, 'Consulta / Atendimento');
      expect(TipoServico.outros.label, 'Outros');
    });

    test('icone retorna emoji para cada tipo', () {
      expect(TipoServico.plantao.icone, isNotEmpty);
      expect(TipoServico.atoAnestesico.icone, isNotEmpty);
      expect(TipoServico.laudo.icone, isNotEmpty);
      expect(TipoServico.procedimentoCirurgico.icone, isNotEmpty);
      expect(TipoServico.consulta.icone, isNotEmpty);
      expect(TipoServico.outros.icone, isNotEmpty);
    });

    test('codigoNbs retorna código NBS correto', () {
      expect(TipoServico.plantao.codigoNbs, '40119');
      expect(TipoServico.atoAnestesico.codigoNbs, '40119');
      expect(TipoServico.laudo.codigoNbs, '40201');
      expect(TipoServico.procedimentoCirurgico.codigoNbs, '40119');
      expect(TipoServico.consulta.codigoNbs, '40101');
      expect(TipoServico.outros.codigoNbs, '40119');
    });

    test('toJson retorna o name do enum', () {
      expect(TipoServico.plantao.toJson, 'plantao');
      expect(TipoServico.consulta.toJson, 'consulta');
      expect(TipoServico.laudo.toJson, 'laudo');
    });
  });

  // ── StatusServico ────────────────────────────────────────────────────────

  group('StatusServico.fromJson', () {
    test('reconhece todos os valores', () {
      expect(StatusServicoExtension.fromJson('pendente'), StatusServico.pendente);
      expect(StatusServicoExtension.fromJson('nfEmProcessamento'), StatusServico.nfEmProcessamento);
      expect(StatusServicoExtension.fromJson('nfEmitida'), StatusServico.nfEmitida);
      expect(StatusServicoExtension.fromJson('aguardandoPagamento'), StatusServico.aguardandoPagamento);
      expect(StatusServicoExtension.fromJson('pago'), StatusServico.pago);
      expect(StatusServicoExtension.fromJson('cancelado'), StatusServico.cancelado);
    });

    test('valor desconhecido retorna pendente via orElse', () {
      expect(StatusServicoExtension.fromJson('invalido'), StatusServico.pendente);
    });
  });

  group('StatusServico extensions', () {
    test('label retorna texto legível para cada status', () {
      expect(StatusServico.pendente.label, 'Pendente');
      expect(StatusServico.nfEmProcessamento.label, 'Em processamento');
      expect(StatusServico.nfEmitida.label, 'NF emitida');
      expect(StatusServico.aguardandoPagamento.label, 'Aguardando pagamento');
      expect(StatusServico.pago.label, 'Pago');
      expect(StatusServico.cancelado.label, 'Cancelado');
    });

    test('foiExecutado — false para pendente e cancelado', () {
      expect(StatusServico.pendente.foiExecutado, false);
      expect(StatusServico.cancelado.foiExecutado, false);
    });

    test('foiExecutado — true para demais status', () {
      expect(StatusServico.nfEmProcessamento.foiExecutado, true);
      expect(StatusServico.nfEmitida.foiExecutado, true);
      expect(StatusServico.aguardandoPagamento.foiExecutado, true);
      expect(StatusServico.pago.foiExecutado, true);
    });

    test('pendenteDEmissao apenas para pendente', () {
      expect(StatusServico.pendente.pendenteDEmissao, true);
      expect(StatusServico.pago.pendenteDEmissao, false);
      expect(StatusServico.cancelado.pendenteDEmissao, false);
    });

    test('temNotaFiscal — false para pendente e cancelado', () {
      expect(StatusServico.pendente.temNotaFiscal, false);
      expect(StatusServico.cancelado.temNotaFiscal, false);
    });

    test('temNotaFiscal — true quando NF existe', () {
      expect(StatusServico.nfEmProcessamento.temNotaFiscal, true);
      expect(StatusServico.nfEmitida.temNotaFiscal, true);
      expect(StatusServico.aguardandoPagamento.temNotaFiscal, true);
      expect(StatusServico.pago.temNotaFiscal, true);
    });

    test('color retorna Color não-nulo para cada status', () {
      for (final s in StatusServico.values) {
        expect(s.color, isA<Color>());
      }
    });

    test('toJson retorna o name do enum', () {
      expect(StatusServico.pendente.toJson, 'pendente');
      expect(StatusServico.pago.toJson, 'pago');
    });
  });

  // ── Servico.fromJson ─────────────────────────────────────────────────────

  group('Servico.fromJson', () {
    test('parseia todos os campos obrigatórios a partir da fixture', () {
      final json = loadFixture('servico.json');
      final s = Servico.fromJson(json);

      expect(s.id, 'fixture-servico-001');
      expect(s.tipo, TipoServico.plantao);
      expect(s.data, DateTime(2026, 4, 15));
      expect(s.tomadorCnpj, '00.000.000/0001-00');
      expect(s.tomadorNome, 'Hospital Teste');
      expect(s.valor, 3500.0);
      expect(s.status, StatusServico.pendente);
      expect(s.observacao, 'Plantão noturno UTI');
      expect(s.tomadorId, 'tomador-id-001');
      expect(s.aliquotaIss, 2.0);
      expect(s.issRetido, false);
    });

    test('parseia horaInicio e horaFim quando presentes', () {
      final json = loadFixture('servico.json');
      final s = Servico.fromJson(json);

      expect(s.horaInicio, const TimeOfDay(hour: 20, minute: 0));
      expect(s.horaFim, const TimeOfDay(hour: 8, minute: 0));
    });

    test('campos opcionais ausentes recebem defaults', () {
      final json = <String, dynamic>{
        'id': 'sem-opcionals',
        'tipoServico': 'consulta',
        'competencia': '2026-01-10',
        'tomadorCnpj': '',
        'tomadorNome': '',
        'valor': 500.0,
        'status': 'pendente',
      };
      final s = Servico.fromJson(json);

      expect(s.observacao, '');
      expect(s.horaInicio, isNull);
      expect(s.horaFim, isNull);
      expect(s.tomadorId, isNull);
      expect(s.aliquotaIss, 0.0);
      expect(s.issRetido, false);
    });

    test('hora com formato inválido resulta em null', () {
      final json = <String, dynamic>{
        'id': 'hora-invalida',
        'tipoServico': 'plantao',
        'competencia': '2026-03-01',
        'tomadorCnpj': '',
        'tomadorNome': '',
        'valor': 100.0,
        'status': 'pendente',
        'horaInicio': 'invalido',
      };
      final s = Servico.fromJson(json);
      expect(s.horaInicio, isNull);
    });
  });

  // ── Servico.toJson ───────────────────────────────────────────────────────

  group('Servico.toJson', () {
    test('produz mapa com todas as chaves esperadas', () {
      final s = Servico.fromJson(loadFixture('servico.json'));
      final out = s.toJson();

      expect(out.containsKey('id'), true);
      expect(out.containsKey('tipoServico'), true);
      expect(out.containsKey('competencia'), true);
      expect(out.containsKey('tomadorCnpj'), true);
      expect(out.containsKey('tomadorNome'), true);
      expect(out.containsKey('valor'), true);
      expect(out.containsKey('status'), true);
      expect(out.containsKey('aliquotaIss'), true);
      expect(out.containsKey('issRetido'), true);
    });

    test('competencia serializada em formato YYYY-MM-DD', () {
      final s = Servico.fromJson(loadFixture('servico.json'));
      expect(s.toJson()['competencia'], '2026-04-15');
    });

    test('tomadorId incluído quando não-nulo e não-vazio', () {
      final s = Servico.fromJson(loadFixture('servico.json'));
      expect(s.toJson()['tomadorId'], 'tomador-id-001');
    });

    test('tomadorId ausente do mapa quando nulo', () {
      final s = Servico(
        id: 'x',
        tipo: TipoServico.consulta,
        data: DateTime(2026, 1, 1),
        tomadorCnpj: '',
        tomadorNome: '',
        valor: 100,
        status: StatusServico.pendente,
      );
      expect(s.toJson().containsKey('tomadorId'), false);
    });

    test('horaInicio e horaFim serializados quando presentes', () {
      final s = Servico.fromJson(loadFixture('servico.json'));
      final out = s.toJson();
      expect(out['horaInicio'], isNotNull);
      expect(out['horaFim'], isNotNull);
    });
  });

  // ── Servico helpers ──────────────────────────────────────────────────────

  group('Servico.duracaoFormatada', () {
    test('retorna null sem horaInicio ou horaFim', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
      );
      expect(s.duracaoFormatada, isNull);
    });

    test('retorna null com horaInicio mas sem horaFim', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
        horaInicio: const TimeOfDay(hour: 8, minute: 0),
      );
      expect(s.duracaoFormatada, isNull);
    });

    test('calcula duração sem minutos residuais', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
        horaInicio: const TimeOfDay(hour: 8, minute: 0),
        horaFim: const TimeOfDay(hour: 12, minute: 0),
      );
      expect(s.duracaoFormatada, '4h');
    });

    test('calcula duração com minutos residuais', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
        horaInicio: const TimeOfDay(hour: 8, minute: 30),
        horaFim: const TimeOfDay(hour: 10, minute: 45),
      );
      expect(s.duracaoFormatada, '2h15');
    });

    test('lida com virada de meia-noite (plantão 12h)', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
        horaInicio: const TimeOfDay(hour: 20, minute: 0),
        horaFim: const TimeOfDay(hour: 8, minute: 0),
      );
      expect(s.duracaoFormatada, '12h');
    });
  });

  group('Servico.horarioFormatado', () {
    test('retorna null sem horaInicio', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
      );
      expect(s.horarioFormatado, isNull);
    });

    test('retorna apenas início quando sem horaFim', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
        horaInicio: const TimeOfDay(hour: 8, minute: 0),
      );
      expect(s.horarioFormatado, '08:00');
    });

    test('retorna intervalo formatado quando ambas presentes', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 1, 1),
        tomadorCnpj: '', tomadorNome: '', valor: 100, status: StatusServico.pendente,
        horaInicio: const TimeOfDay(hour: 8, minute: 0),
        horaFim: const TimeOfDay(hour: 12, minute: 30),
      );
      expect(s.horarioFormatado, '08:00 – 12:30');
    });
  });

  group('Servico.discriminacao', () {
    test('discriminacaoFinal usa observacao quando preenchida', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 4, 1),
        tomadorCnpj: '', tomadorNome: 'Hospital', valor: 100, status: StatusServico.pendente,
        observacao: 'Descrição personalizada',
      );
      expect(s.discriminacaoFinal, 'Descrição personalizada');
    });

    test('discriminacaoFinal usa discriminacaoPadrao quando observacao vazia', () {
      final s = Servico(
        id: 'x', tipo: TipoServico.plantao, data: DateTime(2026, 4, 1),
        tomadorCnpj: '', tomadorNome: 'Hospital', valor: 100, status: StatusServico.pendente,
      );
      expect(s.discriminacaoFinal, contains('Plantão médico'));
      expect(s.discriminacaoFinal, contains('Hospital'));
    });

    test('discriminacaoPadrao inclui mês e ano para cada tipo', () {
      final tipos = TipoServico.values;
      for (final tipo in tipos) {
        final s = Servico(
          id: 'x', tipo: tipo, data: DateTime(2026, 4, 1),
          tomadorCnpj: '', tomadorNome: 'Tomador', valor: 100, status: StatusServico.pendente,
        );
        expect(s.discriminacaoPadrao, contains('Tomador'));
        expect(s.discriminacaoPadrao, contains('2026'));
      }
    });
  });

  // ── Servico.copyWith ─────────────────────────────────────────────────────

  group('Servico.copyWith', () {
    late Servico original;

    setUp(() {
      original = Servico(
        id: 'orig',
        tipo: TipoServico.plantao,
        data: DateTime(2026, 1, 1),
        tomadorCnpj: 'cnpj-original',
        tomadorNome: 'Nome Original',
        valor: 1000.0,
        status: StatusServico.pendente,
        horaInicio: const TimeOfDay(hour: 8, minute: 0),
        horaFim: const TimeOfDay(hour: 12, minute: 0),
      );
    });

    test('substitui apenas campos especificados', () {
      final copy = original.copyWith(valor: 2000, status: StatusServico.pago);

      expect(copy.id, 'orig');
      expect(copy.valor, 2000.0);
      expect(copy.status, StatusServico.pago);
      expect(copy.tomadorNome, 'Nome Original');
      expect(copy.horaInicio, const TimeOfDay(hour: 8, minute: 0));
    });

    test('clearHoraInicio remove horaInicio', () {
      final copy = original.copyWith(clearHoraInicio: true);
      expect(copy.horaInicio, isNull);
      expect(copy.horaFim, const TimeOfDay(hour: 12, minute: 0));
    });

    test('clearHoraFim remove horaFim', () {
      final copy = original.copyWith(clearHoraFim: true);
      expect(copy.horaFim, isNull);
      expect(copy.horaInicio, const TimeOfDay(hour: 8, minute: 0));
    });
  });
}
