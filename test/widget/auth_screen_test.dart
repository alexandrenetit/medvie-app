// test/widget/auth_screen_test.dart
//
// Testes de widget para AuthScreen.
// Cobre: renderização dos campos, validações do formulário,
// login com sucesso/erro, toggle de visibilidade de senha,
// e callback "Criar conta".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/features/auth/auth_screen.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeOnboarding extends ChangeNotifier implements OnboardingProvider {
  @override
  String? cpfDigitsSalvo;
  @override
  // ignore: overridden_fields
  Medico? medico;
  @override
  Map<String, String> cnpjProprioIdsPorCnpj = {};
  @override
  String cnpjAtual = '';

  bool _loginThrows;

  _FakeOnboarding({bool loginThrows = false, this.cpfDigitsSalvo})
      : _loginThrows = loginThrows;

  void setLoginThrows(bool v) => _loginThrows = v;

  @override
  Future<void> loginERestaurar(String cpf, String senha) async {
    if (_loginThrows) throw Exception('Credenciais inválidas');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeServico extends ChangeNotifier implements ServicoProvider {
  @override
  int get countPendentesNf => 0;
  @override
  int get totalConfirmados => 0;
  @override
  int get totalPlanejados => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── Helper ────────────────────────────────────────────────────────────────────

Widget _buildWidget(
  _FakeOnboarding onboarding, {
  VoidCallback? onLoginSucesso,
  VoidCallback? onCriarConta,
}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
        ChangeNotifierProvider<ServicoProvider>.value(value: _FakeServico()),
      ],
      child: AuthScreen(
        onLoginSucesso: onLoginSucesso ?? () {},
        onCriarConta: onCriarConta ?? () {},
      ),
    ),
  );
}

// ── CPF de teste válido ───────────────────────────────────────────────────────
// 529.982.247-25 — CPF matematicamente válido para testes
const _cpfValido = '529.982.247-25';
const _cpfInvalido = '111.111.111-11';

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Renderização
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets('renderiza campos CPF, senha e botão Entrar', (tester) async {
    await tester.pumpWidget(_buildWidget(_FakeOnboarding()));

    expect(find.text('Medvie'), findsOneWidget);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('CPF'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('renderiza link "Não tem conta? Criar conta"', (tester) async {
    await tester.pumpWidget(_buildWidget(_FakeOnboarding()));

    expect(find.text('Não tem conta? Criar conta'), findsOneWidget);
  });

  testWidgets('se cpfDigitsSalvo não nulo, preenche campo CPF', (tester) async {
    final onboarding = _FakeOnboarding(cpfDigitsSalvo: '52998224725');
    await tester.pumpWidget(_buildWidget(onboarding));

    expect(
      find.widgetWithText(TextFormField, '529.982.247-25'),
      findsOneWidget,
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Validações
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets('CPF vazio → erro "Informe seu CPF"', (tester) async {
    await tester.pumpWidget(_buildWidget(_FakeOnboarding()));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe seu CPF'), findsOneWidget);
  });

  testWidgets('CPF inválido → erro "CPF inválido"', (tester) async {
    await tester.pumpWidget(_buildWidget(_FakeOnboarding()));

    // Campo CPF é o primeiro TextFormField
    await tester.enterText(find.byType(TextFormField).at(0), _cpfInvalido);
    await tester.pump();

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('CPF inválido'), findsOneWidget);
  });

  testWidgets('senha vazia → erro "Informe sua senha"', (tester) async {
    await tester.pumpWidget(_buildWidget(_FakeOnboarding()));

    await tester.enterText(find.byType(TextFormField).at(0), _cpfValido);
    await tester.pump();

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe sua senha'), findsOneWidget);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Interações
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets('login com sucesso → onLoginSucesso chamado', (tester) async {
    bool chamado = false;
    await tester.pumpWidget(_buildWidget(
      _FakeOnboarding(),
      onLoginSucesso: () => chamado = true,
    ));

    await tester.enterText(find.byType(TextFormField).at(0), _cpfValido);
    await tester.enterText(find.byType(TextFormField).at(1), 'senha123');
    await tester.pump();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(chamado, isTrue);
  });

  testWidgets('login com erro → exibe mensagem de erro', (tester) async {
    await tester.pumpWidget(_buildWidget(_FakeOnboarding(loginThrows: true)));

    await tester.enterText(find.byType(TextFormField).at(0), _cpfValido);
    await tester.enterText(find.byType(TextFormField).at(1), 'senhaErrada');
    await tester.pump();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(
        find.text('CPF ou senha inválidos. Tente novamente.'), findsOneWidget);
  });

  testWidgets('tap em "Criar conta" dispara onCriarConta', (tester) async {
    bool chamado = false;
    await tester.pumpWidget(_buildWidget(
      _FakeOnboarding(),
      onCriarConta: () => chamado = true,
    ));

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await tester.pump();

    expect(chamado, isTrue);
  });

  testWidgets('ícone de olho alterna visibilidade da senha', (tester) async {
    await tester.pumpWidget(_buildWidget(_FakeOnboarding()));

    // Campo começa oculto (visibility_off)
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    // Após tap, campo fica visível (visibility)
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });
}
