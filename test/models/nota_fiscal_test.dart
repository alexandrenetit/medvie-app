// test/models/nota_fiscal_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/nota_fiscal.dart';
import '../test_helpers.dart';

void main() {
  // ── StatusNota ───────────────────────────────────────────────────────────

  group('StatusNota.fromJson', () {
    test('reconhece todos os valores do enum', () {
      expect(StatusNotaExtension.fromJson('emProcessamento'), StatusNota.emProcessamento);
      expect(StatusNotaExtension.fromJson('autorizada'), StatusNota.autorizada);
      expect(StatusNotaExtension.fromJson('rejeitada'), StatusNota.rejeitada);
      expect(StatusNotaExtension.fromJson('cancelada'), StatusNota.cancelada);
    });

    test('valor desconhecido retorna emProcessamento via orElse', () {
      expect(StatusNotaExtension.fromJson('invalido'), StatusNota.emProcessamento);
    });
  });

  group('StatusNota extensions', () {
    test('label retorna texto legível para cada status', () {
      expect(StatusNota.emProcessamento.label, 'Em processamento');
      expect(StatusNota.autorizada.label, 'Autorizada');
      expect(StatusNota.rejeitada.label, 'Rejeitada');
      expect(StatusNota.cancelada.label, 'Cancelada');
    });

    test('toJson retorna o name do enum', () {
      expect(StatusNota.autorizada.toJson, 'autorizada');
      expect(StatusNota.rejeitada.toJson, 'rejeitada');
      expect(StatusNota.emProcessamento.toJson, 'emProcessamento');
      expect(StatusNota.cancelada.toJson, 'cancelada');
    });
  });

  // ── NotaFiscal.fromJson ──────────────────────────────────────────────────

  group('NotaFiscal.fromJson — NF autorizada', () {
    late NotaFiscal nf;

    setUp(() {
      nf = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
    });

    test('parseia campos de identidade', () {
      expect(nf.id, 'fixture-nf-001');
      expect(nf.servicoId, 'fixture-servico-001');
    });

    test('parseia campos do tomador', () {
      expect(nf.tomadorRazaoSocial, 'Hospital Teste Ltda');
      expect(nf.tomadorCnpj, '00.000.000/0001-00');
      expect(nf.cnpjEmissor, '12.345.678/0001-99');
    });

    test('parseia valor e status', () {
      expect(nf.valor, 3500.0);
      expect(nf.status, StatusNota.autorizada);
    });

    test('parseia data competencia', () {
      expect(nf.competencia.year, 2026);
      expect(nf.competencia.month, 4);
      expect(nf.competencia.day, 15);
    });

    test('parseia data emitidaEm com hora', () {
      expect(nf.emitidaEm.hour, 14);
      expect(nf.emitidaEm.minute, 30);
    });

    test('parseia campos opcionais presentes', () {
      expect(nf.numeroNota, '000123');
      expect(nf.chaveAcesso, 'CHAVE-ACESSO-FAKE-001');
    });

    test('campos nulos ficam null', () {
      expect(nf.linkPdf, isNull);
      expect(nf.motivoRejeicao, isNull);
    });
  });

  group('NotaFiscal.fromJson — NF rejeitada', () {
    late NotaFiscal nf;

    setUp(() {
      nf = NotaFiscal.fromJson(loadFixture('nota_fiscal_rejeitada.json'));
    });

    test('status é rejeitada', () {
      expect(nf.status, StatusNota.rejeitada);
    });

    test('campos fiscais ficam null quando rejeitada', () {
      expect(nf.numeroNota, isNull);
      expect(nf.chaveAcesso, isNull);
    });

    test('motivoRejeicao preenchido', () {
      expect(nf.motivoRejeicao, 'CNPJ do tomador inativo na Receita Federal');
    });
  });

  // ── NotaFiscal.toJson ────────────────────────────────────────────────────

  group('NotaFiscal.toJson', () {
    test('produz mapa com todas as chaves esperadas', () {
      final nf = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final out = nf.toJson();

      expect(out.containsKey('id'), true);
      expect(out.containsKey('servicoId'), true);
      expect(out.containsKey('tomadorRazaoSocial'), true);
      expect(out.containsKey('tomadorCnpj'), true);
      expect(out.containsKey('cnpjEmissor'), true);
      expect(out.containsKey('valor'), true);
      expect(out.containsKey('competencia'), true);
      expect(out.containsKey('emitidaEm'), true);
      expect(out.containsKey('status'), true);
    });

    test('status serializado como string do enum', () {
      final nf = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      expect(nf.toJson()['status'], 'autorizada');
    });

    test('round-trip fromJson → toJson → fromJson preserva campos essenciais', () {
      final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final roundTrip = NotaFiscal.fromJson(original.toJson());

      expect(roundTrip.id, original.id);
      expect(roundTrip.servicoId, original.servicoId);
      expect(roundTrip.valor, original.valor);
      expect(roundTrip.status, original.status);
      expect(roundTrip.numeroNota, original.numeroNota);
      expect(roundTrip.chaveAcesso, original.chaveAcesso);
    });

    test('round-trip preserva datas', () {
      final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final roundTrip = NotaFiscal.fromJson(original.toJson());

      expect(roundTrip.competencia.year, original.competencia.year);
      expect(roundTrip.competencia.month, original.competencia.month);
      expect(roundTrip.competencia.day, original.competencia.day);
    });
  });

  // ── NotaFiscal.copyWith ──────────────────────────────────────────────────

  group('NotaFiscal.copyWith', () {
    test('substitui apenas campos especificados', () {
      final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final copy = original.copyWith(
        status: StatusNota.cancelada,
        motivoRejeicao: 'Cancelada pelo médico',
      );

      expect(copy.id, original.id);
      expect(copy.servicoId, original.servicoId);
      expect(copy.valor, original.valor);
      expect(copy.status, StatusNota.cancelada);
      expect(copy.motivoRejeicao, 'Cancelada pelo médico');
    });

    test('copyWith sem argumentos preserva todos os campos', () {
      final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.status, original.status);
      expect(copy.numeroNota, original.numeroNota);
    });
  });
}
