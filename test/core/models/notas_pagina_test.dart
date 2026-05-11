// test/core/models/notas_pagina_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/nota_fiscal.dart';
import 'package:medvie/core/models/notas_pagina.dart';

import '../../test_helpers.dart';

void main() {
  Map<String, dynamic> notaJson(String id) {
    return {
      'id': id,
      'status': 'Processando',
      'codigoNbs': '1.0501',
      'createdAt': '2026-05-10T18:32:11.123Z',
      'updatedAt': '2026-05-11T09:14:55.789Z',
    };
  }

  group('NotasPagina.fromJson', () {
    test('1. payload completo cria pagina correta', () {
      final pagina = NotasPagina.fromJson({
        'notas': [notaJson('nota-1'), notaJson('nota-2')],
        'total': 2,
        'pagina': 3,
        'tamanhoPagina': 10,
      });

      expect(pagina.notas, hasLength(2));
      expect(pagina.notas.first.id, 'nota-1');
      expect(pagina.notas.last.id, 'nota-2');
      expect(pagina.total, 2);
      expect(pagina.pagina, 3);
      expect(pagina.tamanhoPagina, 10);
    });

    test('2. lista vazia preserva metadados', () {
      final pagina = NotasPagina.fromJson({
        'notas': [],
        'total': 0,
        'pagina': 1,
        'tamanhoPagina': 20,
      });

      expect(pagina.notas, isEmpty);
      expect(pagina.total, 0);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
    });

    test('3. sem metadados usa defaults', () {
      final pagina = NotasPagina.fromJson({'notas': []});

      expect(pagina.notas, isEmpty);
      expect(pagina.total, 0);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
    });

    test('4. notas nao-lista lanca FormatException', () {
      expect(
        () => NotasPagina.fromJson({'notas': 'invalido'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('fixture listar_notas_pagina_com_itens.json preserva contrato', () {
      final pagina = NotasPagina.fromJson(
        loadFixture('notas/listar_notas_pagina_com_itens.json'),
      );

      expect(pagina.notas, hasLength(2));
      expect(pagina.total, 2);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
      expect(pagina.notas.first, isA<NotaFiscal>());
      expect(pagina.notas.first.id, 'nota-1');
      expect(pagina.notas.first.status, 'Processando');
      expect(pagina.notas.first.codigoNbs, '1.0501');
    });

    test('fixture listar_notas_pagina_vazia.json preserva contrato', () {
      final pagina = NotasPagina.fromJson(
        loadFixture('notas/listar_notas_pagina_vazia.json'),
      );

      expect(pagina.notas, isEmpty);
      expect(pagina.total, 0);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
    });
  });

  group('toJson / roundtrip', () {
    test('5. toJson preserva dados ao reparsear', () {
      final dto = NotasPagina(
        notas: [NotaFiscal.fromJson(notaJson('nota-1'))],
        total: 1,
        pagina: 1,
        tamanhoPagina: 20,
      );

      final roundtrip = NotasPagina.fromJson(dto.toJson());

      expect(roundtrip, equals(dto));
    });
  });

  group('copyWith', () {
    test('6. altera somente campo informado', () {
      final nota = NotaFiscal.fromJson(notaJson('nota-1'));
      final original = NotasPagina(
        notas: [nota],
        total: 1,
        pagina: 1,
        tamanhoPagina: 20,
      );

      final copy = original.copyWith(pagina: 2);

      expect(copy.notas, original.notas);
      expect(copy.total, original.total);
      expect(copy.pagina, 2);
      expect(copy.tamanhoPagina, original.tamanhoPagina);
    });
  });
}
