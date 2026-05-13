// test/models/nota_fiscal_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/nota_fiscal.dart';
import '../test_helpers.dart';

void main() {
  // ── StatusNota ───────────────────────────────────────────────────────────

  group('StatusNota.fromJson', () {
    test('reconhece todos os valores do enum', () {
      expect(
        StatusNotaExtension.fromJson('emProcessamento'),
        StatusNota.emProcessamento,
      );
      expect(
        StatusNotaExtension.fromJson('Processando'),
        StatusNota.emProcessamento,
      );
      expect(StatusNotaExtension.fromJson('autorizada'), StatusNota.autorizada);
      expect(StatusNotaExtension.fromJson('Autorizada'), StatusNota.autorizada);
      expect(StatusNotaExtension.fromJson('rejeitada'), StatusNota.rejeitada);
      expect(StatusNotaExtension.fromJson('Rejeitada'), StatusNota.rejeitada);
      expect(StatusNotaExtension.fromJson('cancelada'), StatusNota.cancelada);
    });

    test('valor desconhecido retorna emProcessamento via orElse', () {
      expect(
        StatusNotaExtension.fromJson('invalido'),
        StatusNota.emProcessamento,
      );
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

    test('parseia campos de identidade e contrato', () {
      expect(nf.id, 'fixture-nf-001');
      expect(nf.status, 'autorizada');
      expect(nf.codigoNbs, '1.0501');
    });

    test('parseia datas obrigatórias em UTC', () {
      expect(nf.createdAt.isUtc, isTrue);
      expect(nf.updatedAt.isUtc, isTrue);
      expect(nf.createdAt.year, 2026);
      expect(nf.createdAt.month, 4);
      expect(nf.createdAt.day, 15);
    });

    test('parseia campos opcionais presentes', () {
      expect(nf.numeroNfse, '000123');
      expect(nf.chaveAcesso, 'CHAVE-ACESSO-FAKE-001');
    });

    test('campos nulos ficam null', () {
      expect(nf.linkPdf, isNull);
      expect(nf.motivoRejeicao, isNull);
    });

    test('versao é positivo e derivado de updatedAt', () {
      expect(nf.versao, greaterThan(0));
    });
  });

  group('NotaFiscal.fromJson — NF rejeitada', () {
    late NotaFiscal nf;

    setUp(() {
      nf = NotaFiscal.fromJson(loadFixture('nota_fiscal_rejeitada.json'));
    });

    test('status é rejeitada', () {
      expect(nf.status, 'rejeitada');
    });

    test('campos fiscais ficam null quando rejeitada', () {
      expect(nf.numeroNfse, isNull);
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
      expect(out.containsKey('status'), true);
      expect(out.containsKey('codigoNbs'), true);
      expect(out.containsKey('createdAt'), true);
      expect(out.containsKey('updatedAt'), true);
    });

    test('status serializado como string crua', () {
      final nf = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      expect(nf.toJson()['status'], 'autorizada');
    });

    test(
      'round-trip fromJson → toJson → fromJson preserva campos essenciais',
      () {
        final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
        final roundTrip = NotaFiscal.fromJson(original.toJson());

        expect(roundTrip.id, original.id);
        expect(roundTrip.status, original.status);
        expect(roundTrip.codigoNbs, original.codigoNbs);
        expect(roundTrip.numeroNfse, original.numeroNfse);
        expect(roundTrip.chaveAcesso, original.chaveAcesso);
      },
    );

    test('round-trip preserva datas', () {
      final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final roundTrip = NotaFiscal.fromJson(original.toJson());

      expect(roundTrip.createdAt, original.createdAt);
      expect(roundTrip.updatedAt, original.updatedAt);
    });
  });

  // ── NotaFiscal.copyWith ──────────────────────────────────────────────────

  group('NotaFiscal.copyWith', () {
    test('substitui apenas campos especificados', () {
      final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final copy = original.copyWith(
        status: 'cancelada',
        motivoRejeicao: 'Cancelada pelo médico',
      );

      expect(copy.id, original.id);
      expect(copy.codigoNbs, original.codigoNbs);
      expect(copy.status, 'cancelada');
      expect(copy.motivoRejeicao, 'Cancelada pelo médico');
    });

    test('copyWith sem argumentos preserva todos os campos', () {
      final original = NotaFiscal.fromJson(loadFixture('nota_fiscal.json'));
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.status, original.status);
      expect(copy.numeroNfse, original.numeroNfse);
      expect(copy.updatedAt, original.updatedAt);
    });
  });
}
