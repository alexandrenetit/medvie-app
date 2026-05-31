// test/shared/widgets/stats_row_test.dart
//
// Testes de widget para StatsRow.
// Cobre: renderização dos 3 chips, valores de totalConfirmados/totalPlanejados,
// e total de NFs emitidas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/features/syncview/widgets/stats_row.dart';

// ── Fake ──────────────────────────────────────────────────────────────────────

class _FakeServico extends ChangeNotifier implements ServicoProvider {
  final int _confirmados;
  final int _planejados;

  _FakeServico({int confirmados = 0, int planejados = 0})
    : _confirmados = confirmados,
      _planejados = planejados;

  @override
  int get totalConfirmados => _confirmados;

  @override
  int get totalPlanejados => _planejados;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── Helper ────────────────────────────────────────────────────────────────────

class _FakeNotaFiscal extends ChangeNotifier implements NotaFiscalProvider {
  final int _nfsEmitidas;

  _FakeNotaFiscal({int nfsEmitidas = 0}) : _nfsEmitidas = nfsEmitidas;

  @override
  int countAutorizadasDoMes(int ano, int mes) => _nfsEmitidas;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _buildWidget({
  int confirmados = 0,
  int planejados = 0,
  int nfsEmitidas = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<ServicoProvider>.value(
            value: _FakeServico(
              confirmados: confirmados,
              planejados: planejados,
            ),
          ),
          ChangeNotifierProvider<NotaFiscalProvider>.value(
            value: _FakeNotaFiscal(nfsEmitidas: nfsEmitidas),
          ),
        ],
        child: const StatsRow(),
      ),
    ),
  );
}

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  testWidgets('renderiza os 3 labels: Confirmados, Planejados, NFs emitidas', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWidget());

    expect(find.text('Confirmados'), findsOneWidget);
    expect(find.text('Planejados'), findsOneWidget);
    expect(find.text('NFs emitidas'), findsOneWidget);
  });

  testWidgets('exibe valores corretos de totalConfirmados e totalPlanejados', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWidget(confirmados: 7, planejados: 3));

    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('chip "NFs emitidas" exibe autorizadas do mês', (tester) async {
    await tester.pumpWidget(
      _buildWidget(confirmados: 5, planejados: 2, nfsEmitidas: 4),
    );

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('valores zerados renderizam sem erros', (tester) async {
    await tester.pumpWidget(_buildWidget());

    // Três chips com valor 0
    expect(find.text('0'), findsNWidgets(3));
  });
}
