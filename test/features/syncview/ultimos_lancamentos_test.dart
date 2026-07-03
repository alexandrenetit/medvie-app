// test/features/syncview/ultimos_lancamentos_test.dart

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/servico.dart';
import 'package:medvie/features/syncview/widgets/ultimos_lancamentos.dart';

Servico _servico({
  required String id,
  required DateTime data,
  StatusServico status = StatusServico.pendente,
  String? tomadorId,
  String tomadorNome = 'Tomador',
  TimeOfDay? horaInicio,
}) =>
    Servico(
      id: id,
      tipo: TipoServico.consulta,
      data: data,
      tomadorCnpj: '00000000000000',
      tomadorNome: tomadorNome,
      valor: 1000,
      status: status,
      tomadorId: tomadorId,
      horaInicio: horaInicio,
    );

void main() {
  final mes = DateTime(2026, 7);

  group('UltimosLancamentos.recentes', () {
    test('exclui cancelados do feed', () {
      final ativo = _servico(id: 'a', data: DateTime(2026, 7, 10));
      final cancelado = _servico(
        id: 'c',
        data: DateTime(2026, 7, 11),
        status: StatusServico.cancelado,
      );
      final r = UltimosLancamentos.recentes([ativo, cancelado], mes);
      expect(r.map((s) => s.id), ['a']);
    });

    test('só uma linha por tomador — mantém o mais recente', () {
      final antigo = _servico(
        id: 'antigo',
        data: DateTime(2026, 7, 5),
        tomadorNome: 'Adriana M.',
      );
      final recente = _servico(
        id: 'recente',
        data: DateTime(2026, 7, 20),
        tomadorNome: 'Adriana M.',
      );
      final r = UltimosLancamentos.recentes([antigo, recente], mes);
      expect(r.length, 1);
      expect(r.first.id, 'recente');
    });

    test('dedupe por tomadorId quando presente (nomes iguais, ids distintos)',
        () {
      final p1 = _servico(
        id: 'p1',
        data: DateTime(2026, 7, 10),
        tomadorId: 'id-1',
        tomadorNome: 'João',
      );
      final p2 = _servico(
        id: 'p2',
        data: DateTime(2026, 7, 11),
        tomadorId: 'id-2',
        tomadorNome: 'João',
      );
      final r = UltimosLancamentos.recentes([p1, p2], mes);
      expect(r.length, 2, reason: 'ids distintos não devem colapsar');
    });

    test('filtra pelo mês de referência', () {
      final doMes = _servico(id: 'in', data: DateTime(2026, 7, 3));
      final outroMes = _servico(id: 'out', data: DateTime(2026, 6, 30));
      final r = UltimosLancamentos.recentes([doMes, outroMes], mes);
      expect(r.map((s) => s.id), ['in']);
    });

    test('limita a 3 e ordena por data desc', () {
      final servicos = [
        _servico(id: '1', data: DateTime(2026, 7, 1), tomadorNome: 'T1'),
        _servico(id: '2', data: DateTime(2026, 7, 2), tomadorNome: 'T2'),
        _servico(id: '3', data: DateTime(2026, 7, 3), tomadorNome: 'T3'),
        _servico(id: '4', data: DateTime(2026, 7, 4), tomadorNome: 'T4'),
      ];
      final r = UltimosLancamentos.recentes(servicos, mes);
      expect(r.map((s) => s.id), ['4', '3', '2']);
    });
  });
}
