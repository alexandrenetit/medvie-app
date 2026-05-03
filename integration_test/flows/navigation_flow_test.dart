// integration_test/flows/navigation_flow_test.dart
//
// Fluxo de navegação no SyncViewScreen (tabs).
// Inicia diretamente na tela principal com onboardingCompletoFlag=true.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/features/syncview/syncview_screen.dart';
import 'package:medvie/shared/widgets/bottom_nav.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

// CPF válido para simular sessão ativa
const _cpfValido = '529.982.247-25';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Monta o app e faz login via fake para chegar no SyncViewScreen
  Future<void> loginENavegar(WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(
        cpfDigitsSalvo: '52998224725',
        loginOk: true,
        onboardingCompletoFlag: true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), _cpfValido);
    await tester.enterText(find.byType(TextFormField).at(1), 'senha123');
    await tester.pump();
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SyncViewScreen pós-login
  // ════════════════════════════════════════════════════════════════════════════

  testWidgets('NF-01 — após login, SyncViewScreen é exibido', (tester) async {
    await loginENavegar(tester);

    expect(find.byType(SyncViewScreen), findsOneWidget);
  });

  testWidgets('NF-02 — BottomNav está presente com 4 tabs', (tester) async {
    await loginENavegar(tester);

    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.text('SyncView'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Notas'), findsOneWidget);
    expect(find.text('Relatórios'), findsOneWidget);
  });

  testWidgets('NF-03 — tap em "Notas" muda o tab ativo', (tester) async {
    await loginENavegar(tester);

    // Verifica que a tab inicial é SyncView (índice 0)
    // O ícone ativo de SyncView deve estar presente
    expect(find.byIcon(Icons.dashboard), findsOneWidget);

    // Toca em Notas (índice 2)
    await tester.tap(find.text('Notas'));
    await tester.pumpAndSettle();

    // Ícone de Notas ativo (preenchido) deve estar presente no BottomNav
    // (NotasScreen também usa receipt_long_outlined no conteúdo)
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
  });

  testWidgets('NF-04 — tap em "Relatórios" muda o tab ativo', (tester) async {
    await loginENavegar(tester);

    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsNothing);
  });

  testWidgets('NF-05 — tap em "SyncView" retorna ao tab inicial',
      (tester) async {
    await loginENavegar(tester);

    // Vai para Notas
    await tester.tap(find.text('Notas'));
    await tester.pumpAndSettle();

    // Volta para SyncView
    await tester.tap(find.text('SyncView'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.dashboard), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
  });

  testWidgets('NF-06 — FAB (+) está visível na tela principal', (tester) async {
    await loginENavegar(tester);

    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
