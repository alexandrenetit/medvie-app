// test/shared/widgets/bottom_nav_test.dart
//
// Testes de widget para BottomNav.
// Cobre: renderização dos 4 tabs, tab ativa, taps, badge de pendentes e FAB.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/shared/widgets/bottom_nav.dart';

// ── Fake ──────────────────────────────────────────────────────────────────────

class _FakeServico extends ChangeNotifier implements ServicoProvider {
  final int _pendentes;
  _FakeServico({int pendentes = 0}) : _pendentes = pendentes;

  @override
  int get countPendentesNf => _pendentes;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── Helper ────────────────────────────────────────────────────────────────────

Widget _buildWidget(
  int currentIndex, {
  ValueChanged<int>? onTap,
  VoidCallback? onAddServico,
  int pendentes = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: ChangeNotifierProvider<ServicoProvider>.value(
        value: _FakeServico(pendentes: pendentes),
        child: BottomNav(
          currentIndex: currentIndex,
          onTap: onTap ?? (_) {},
          onAddServico: onAddServico ?? () {},
        ),
      ),
    ),
  );
}

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // Renderização
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets('renderiza os 4 labels de navegação', (tester) async {
    await tester.pumpWidget(_buildWidget(0));

    expect(find.text('SyncView'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Notas'), findsOneWidget);
    expect(find.text('Relatórios'), findsOneWidget);
  });

  testWidgets('FAB central é renderizado com ícone de adição', (tester) async {
    await tester.pumpWidget(_buildWidget(0));

    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('tab ativa (index 2) usa ícone receipt_long (preenchido)',
      (tester) async {
    await tester.pumpWidget(_buildWidget(2));

    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsNothing);
  });

  testWidgets('tab inativa (index 0) usa ícone dashboard_outlined',
      (tester) async {
    await tester.pumpWidget(_buildWidget(2));

    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Badge
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets('badge não aparece quando pendentes == 0', (tester) async {
    await tester.pumpWidget(_buildWidget(0, pendentes: 0));

    // Badge exibe texto numérico; '0' não deve aparecer no badge
    expect(find.text('0'), findsNothing);
  });

  testWidgets('badge aparece com valor correto quando pendentes > 0',
      (tester) async {
    await tester.pumpWidget(_buildWidget(0, pendentes: 3));

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('badge exibe "99+" quando pendentes > 99', (tester) async {
    await tester.pumpWidget(_buildWidget(0, pendentes: 150));

    expect(find.text('99+'), findsOneWidget);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Interações
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets('tap em "Agenda" chama onTap(1)', (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(_buildWidget(0, onTap: (i) => tappedIndex = i));

    await tester.tap(find.text('Agenda'));
    await tester.pump();

    expect(tappedIndex, 1);
  });

  testWidgets('tap em "Relatórios" chama onTap(3)', (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(_buildWidget(0, onTap: (i) => tappedIndex = i));

    await tester.tap(find.text('Relatórios'));
    await tester.pump();

    expect(tappedIndex, 3);
  });

  testWidgets('tap no FAB chama onAddServico', (tester) async {
    bool chamado = false;
    await tester.pumpWidget(
        _buildWidget(0, onAddServico: () => chamado = true));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(chamado, isTrue);
  });
}
