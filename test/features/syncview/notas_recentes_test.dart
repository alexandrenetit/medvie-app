// test/features/syncview/notas_recentes_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/nota_fiscal.dart';
import 'package:medvie/features/syncview/widgets/notas_recentes.dart';

NotaFiscal _nota({
  required String id,
  required String status,
  required DateTime dataServico,
}) {
  return NotaFiscal(
    id: id,
    status: status,
    codigoNbs: '0000',
    tomadorNome: 'Tomador $id',
    tipoServico: 'Consulta',
    valorBruto: 100,
    dataServico: dataServico,
    createdAt: dataServico,
    updatedAt: dataServico,
  );
}

void main() {
  final mes = DateTime(2026, 7);

  group('NotasRecentes.recentes', () {
    test('filtra pela competência e ordena por data (desc)', () {
      final notas = [
        _nota(id: '1', status: 'autorizada', dataServico: DateTime(2026, 7, 3)),
        _nota(id: '2', status: 'autorizada', dataServico: DateTime(2026, 7, 20)),
        _nota(id: 'fora', status: 'autorizada', dataServico: DateTime(2026, 6, 28)),
      ];

      final r = NotasRecentes.recentes(notas, mes);

      expect(r.map((n) => n.id).toList(), ['2', '1']);
    });

    test('exclui canceladas e limita a 3 mais recentes', () {
      final notas = [
        for (var d = 1; d <= 5; d++)
          _nota(id: 'a$d', status: 'autorizada', dataServico: DateTime(2026, 7, d)),
        _nota(id: 'canc', status: 'cancelada', dataServico: DateTime(2026, 7, 10)),
      ];

      final r = NotasRecentes.recentes(notas, mes);

      expect(r.length, 3);
      expect(r.any((n) => n.id == 'canc'), isFalse);
      expect(r.map((n) => n.id).toList(), ['a5', 'a4', 'a3']);
    });

    test('sem NFS-e na competência → lista vazia', () {
      final notas = [
        _nota(id: 'x', status: 'autorizada', dataServico: DateTime(2026, 5, 10)),
      ];

      expect(NotasRecentes.recentes(notas, mes), isEmpty);
    });
  });
}
