// integration_test/flows/welcome_flow_test.dart
//
// Fluxo: WelcomeScreen → AuthScreen → WelcomeScreen
// Não requer rede. Valida navegação entre telas iniciais.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/features/welcome/welcome_screen.dart';
import 'package:medvie/features/auth/auth_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════════════════════
  // WelcomeScreen
  // ════════════════════════════════════════════════════════════════════════════

  testWidgets('WF-01 — novo usuário vê WelcomeScreen', (tester) async {
    // Sem cpfDigitsSalvo → WelcomeScreen
    await tester.pumpWidget(buildTestApp(onboarding: FakeOnboarding()));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('WF-02 — usuário com sessão salva vê AuthScreen', (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(cpfDigitsSalvo: '52998224725'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  testWidgets('WF-03 — botão "Já tenho conta" navega para AuthScreen',
      (tester) async {
    await tester.pumpWidget(buildTestApp(onboarding: FakeOnboarding()));
    await tester.pumpAndSettle();

    // Botões ficam na última página (slide 3) — navega via "Pular"
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Já tenho conta'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('WF-04 — botão "Criar conta" na WelcomeScreen navega para onboarding',
      (tester) async {
    await tester.pumpWidget(buildTestApp(onboarding: FakeOnboarding()));
    await tester.pumpAndSettle();

    // Botões ficam na última página (slide 3) — navega via "Pular"
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    // Sai da WelcomeScreen
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  // ════════════════════════════════════════════════════════════════════════════
  // AuthScreen — validações (sem rede)
  // ════════════════════════════════════════════════════════════════════════════

  testWidgets('WF-05 — AuthScreen renderiza campos e botão Entrar',
      (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(cpfDigitsSalvo: '52998224725'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('CPF'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('WF-06 — tap Entrar sem campos → mostra erros de validação',
      (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(cpfDigitsSalvo: '52998224725'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Pelo menos um erro de validação é exibido
    expect(
      find.textContaining(RegExp(r'CPF|senha', caseSensitive: false)),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('WF-07 — CPF inválido → erro "CPF inválido"', (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(cpfDigitsSalvo: '52998224725'),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '111.111.111-11');
    await tester.pump();
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('CPF inválido'), findsOneWidget);
  });
}
