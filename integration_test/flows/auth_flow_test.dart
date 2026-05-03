// integration_test/flows/auth_flow_test.dart
//
// Fluxo de autenticação completo:
// Login com sucesso → SyncViewScreen
// Login com falha → mensagem de erro
// Botão "Criar conta" → onboarding

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/features/auth/auth_screen.dart';
import 'package:medvie/features/syncview/syncview_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

// CPF válido para testes (matematicamente correto)
const _cpfValido = '529.982.247-25';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Login com sucesso
  // ════════════════════════════════════════════════════════════════════════════

  testWidgets('AF-01 — login com sucesso navega para SyncViewScreen',
      (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(
        cpfDigitsSalvo: '52998224725',
        loginOk: true,
        onboardingCompletoFlag: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);

    // Preenche formulário
    await tester.enterText(find.byType(TextFormField).at(0), _cpfValido);
    await tester.enterText(find.byType(TextFormField).at(1), 'senha123');
    await tester.pump();

    // Toca Entrar
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Deve navegar para SyncViewScreen
    expect(find.byType(SyncViewScreen), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('AF-02 — login com falha exibe mensagem de erro', (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(
        cpfDigitsSalvo: '52998224725',
        loginOk: false,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), _cpfValido);
    await tester.enterText(find.byType(TextFormField).at(1), 'senhaErrada');
    await tester.pump();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Ainda na AuthScreen com mensagem de erro
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(
      find.text('CPF ou senha inválidos. Tente novamente.'),
      findsOneWidget,
    );
  });

  testWidgets('AF-03 — tap em "Criar conta" sai da AuthScreen', (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(cpfDigitsSalvo: '52998224725'),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsNothing);
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Interações de formulário
  // ════════════════════════════════════════════════════════════════════════════

  testWidgets('AF-04 — campo CPF aplica máscara enquanto digita',
      (tester) async {
    await tester.pumpWidget(buildTestApp(
      onboarding: FakeOnboarding(cpfDigitsSalvo: '52998224725'),
    ));
    await tester.pumpAndSettle();

    // Digita apenas os dígitos
    await tester.enterText(find.byType(TextFormField).at(0), '52998224725');
    await tester.pump();

    // A máscara formata como XXX.XXX.XXX-XX
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(0),
        matching: find.byType(EditableText),
      ).first,
    );
    expect(field.controller.text, '529.982.247-25');
  });

  testWidgets('AF-05 — botão Entrar fica desabilitado durante carregamento',
      (tester) async {
    // Provider que demora a responder (nunca completa — testaremos isLoading)
    final onboarding = _SlowFakeOnboarding(cpfDigitsSalvo: '52998224725');
    await tester.pumpWidget(buildTestApp(onboarding: onboarding));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), _cpfValido);
    await tester.enterText(find.byType(TextFormField).at(1), 'senha123');
    await tester.pump();

    // Inicia o tap sem aguardar — botão deve estar desabilitado durante o await
    await tester.tap(find.text('Entrar'));
    await tester.pump(); // processa um frame para que setState seja chamado

    // CircularProgressIndicator aparece (botão em loading)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

// Fake que bloqueia loginERestaurar indefinidamente
class _SlowFakeOnboarding extends FakeOnboarding {
  _SlowFakeOnboarding({super.cpfDigitsSalvo});

  @override
  Future<void> loginERestaurar(String cpf, String senha) async {
    await Future.delayed(const Duration(seconds: 60));
  }
}
