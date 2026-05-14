// test/core/models/nota_fiscal_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/nota_fiscal.dart';

import '../../test_helpers.dart';

const int _ticksAt1970 = 621355968000000000;

int _ticksFrom(DateTime utc) =>
    _ticksAt1970 + utc.toUtc().microsecondsSinceEpoch * 10;

void main() {
  const baseJson = <String, dynamic>{
    'id': 'abc-123',
    'status': 'Emitida',
    'codigoNbs': '1.0501',
    'numeroNfse': 'NF-001',
    'chaveAcesso': 'chave-abc',
    'linkPdf': 'https://example.com/nf.pdf',
    'motivoRejeicao': null,
    'servicoId': 'servico-001',
    'tomadorNome': 'UNIMED RESENDE LTDA',
    'valorBruto': 1500.0,
    'valorLiquido': 1425.0,
    'tipoServico': 'PlantaoClinico',
    'dataServico': '2026-05-14',
    'dataEmissao': '2026-05-10T18:32:11.123Z',
    'numeroNf': 'NF-001',
    'createdAt': '2026-05-10T18:32:11.123Z',
    'updatedAt': '2026-05-11T09:14:55.789Z',
  };

  group('NotaFiscal.fromJson', () {
    test('1. payload completo → instância correta, versao > 0', () {
      final nota = NotaFiscal.fromJson(baseJson);
      expect(nota.id, 'abc-123');
      expect(nota.status, 'autorizada');
      expect(nota.codigoNbs, '1.0501');
      expect(nota.numeroNfse, 'NF-001');
      expect(nota.chaveAcesso, 'chave-abc');
      expect(nota.linkPdf, 'https://example.com/nf.pdf');
      expect(nota.motivoRejeicao, isNull);
      expect(nota.servicoId, 'servico-001');
      expect(nota.tomadorNome, 'UNIMED RESENDE LTDA');
      expect(nota.valorBruto, 1500.0);
      expect(nota.valorLiquido, 1425.0);
      expect(nota.tipoServico, 'PlantaoClinico');
      expect(nota.dataServico, DateTime.utc(2026, 5, 14));
      expect(nota.dataEmissao, DateTime.parse('2026-05-10T18:32:11.123Z'));
      expect(nota.numeroNf, 'NF-001');
      expect(nota.dataReferencia, DateTime.utc(2026, 5, 14));
      expect(nota.versao, greaterThan(0));
    });

    test('2. nullables ausentes → campos null', () {
      final json = <String, dynamic>{
        'id': 'abc-123',
        'status': 'Processando',
        'codigoNbs': '1.0501',
        'createdAt': '2026-05-10T18:32:11.123Z',
        'updatedAt': '2026-05-11T09:14:55.789Z',
      };
      final nota = NotaFiscal.fromJson(json);
      expect(nota.numeroNfse, isNull);
      expect(nota.chaveAcesso, isNull);
      expect(nota.linkPdf, isNull);
      expect(nota.motivoRejeicao, isNull);
    });

    test('3. sem createdAt → lança FormatException', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('createdAt');
      expect(() => NotaFiscal.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('4. sem updatedAt → lança FormatException', () {
      final json = Map<String, dynamic>.from(baseJson)..remove('updatedAt');
      expect(() => NotaFiscal.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('fixture nota_fiscal_minima.json preserva contrato minimo', () {
      final nota = NotaFiscal.fromJson(
        loadFixture('notas/nota_fiscal_minima.json'),
      );

      expect(nota.id, 'nota-minima');
      expect(nota.status, 'emProcessamento');
      expect(nota.codigoNbs, '1.0501');
      expect(nota.numeroNfse, isNull);
      expect(nota.chaveAcesso, isNull);
      expect(nota.linkPdf, isNull);
      expect(nota.motivoRejeicao, isNull);
      expect(nota.createdAt.isUtc, isTrue);
      expect(nota.updatedAt.isUtc, isTrue);
      expect(nota.versao, greaterThan(0));
      expect(nota.versao, _ticksFrom(nota.updatedAt));
    });

    test('fixture nota_fiscal_completa.json preserva contrato completo', () {
      final nota = NotaFiscal.fromJson(
        loadFixture('notas/nota_fiscal_completa.json'),
      );

      expect(nota.id, 'nota-completa');
      expect(nota.status, 'rejeitada');
      expect(nota.codigoNbs, '1.0501');
      expect(nota.numeroNfse, '98765');
      expect(nota.chaveAcesso, 'chave-acesso-98765');
      expect(nota.linkPdf, 'https://example.test/notas/nota-completa.pdf');
      expect(nota.motivoRejeicao, 'Dados fiscais inconsistentes.');
      expect(nota.createdAt.isUtc, isTrue);
      expect(nota.updatedAt.isUtc, isTrue);
      expect(nota.versao, greaterThan(0));
      expect(nota.versao, _ticksFrom(nota.updatedAt));
    });
  });

  group('versao', () {
    test(
      '5. versao para updatedAt=2026-05-11T09:14:55.789Z é determinístico',
      () {
        // _ticksAt1970 = 621_355_968_000_000_000
        // microsecondsSinceEpoch('2026-05-11T09:14:55.789Z') = 1_778_490_895_789_000
        // versao = 621_355_968_000_000_000 + 1_778_490_895_789_000 * 10
        //        = 639_140_876_957_890_000
        final nota = NotaFiscal.fromJson(baseJson);
        expect(nota.versao, 639140876957890000);
      },
    );
  });

  group('equals e hashCode', () {
    test('6. mesmo id+updatedAt → equals true, hashCode igual', () {
      final a = NotaFiscal.fromJson(baseJson);
      final b = NotaFiscal.fromJson(baseJson);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('7. mesmo id, updatedAt diferente → equals false', () {
      final a = NotaFiscal.fromJson(baseJson);
      final b = NotaFiscal.fromJson(
        Map<String, dynamic>.from(baseJson)
          ..['updatedAt'] = '2026-05-11T10:00:00.000Z',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('toJson / roundtrip', () {
    test('8. toJson → fromJson preserva todos os campos', () {
      final original = NotaFiscal.fromJson(baseJson);
      final roundtrip = NotaFiscal.fromJson(original.toJson());
      expect(roundtrip.id, original.id);
      expect(roundtrip.status, original.status);
      expect(roundtrip.codigoNbs, original.codigoNbs);
      expect(roundtrip.numeroNfse, original.numeroNfse);
      expect(roundtrip.chaveAcesso, original.chaveAcesso);
      expect(roundtrip.linkPdf, original.linkPdf);
      expect(roundtrip.motivoRejeicao, original.motivoRejeicao);
      expect(roundtrip.servicoId, original.servicoId);
      expect(roundtrip.tomadorNome, original.tomadorNome);
      expect(roundtrip.valorBruto, original.valorBruto);
      expect(roundtrip.valorLiquido, original.valorLiquido);
      expect(roundtrip.tipoServico, original.tipoServico);
      expect(roundtrip.dataServico, original.dataServico);
      expect(roundtrip.dataEmissao, original.dataEmissao);
      expect(roundtrip.numeroNf, original.numeroNf);
      expect(roundtrip.createdAt, original.createdAt);
      expect(roundtrip.updatedAt, original.updatedAt);
      expect(roundtrip.versao, original.versao);
    });
  });
}
