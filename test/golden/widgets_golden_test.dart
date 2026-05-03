// test/golden/widgets_golden_test.dart
//
// Testes golden para widgets compartilhados e de navegação.
// Gera screenshots de referência: BottomNav (com/sem badge),
// StatsRow (valores reais), AuthScreen (estado inicial).
//
// Para regenerar os goldens:
//   flutter test --update-goldens test/golden/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/features/auth/auth_screen.dart';
import 'package:medvie/shared/widgets/bottom_nav.dart';

// ── Fakes (replicados aqui para evitar dependência cruzada de test/) ──────────

class _FakeServico extends ChangeNotifier implements ServicoProvider {
  final int _pendentes;
  final int _confirmados;
  final int _planejados;

  _FakeServico({
    int pendentes = 0,
    int confirmados = 0,
    int planejados = 0,
  })  : _pendentes = pendentes,
        _confirmados = confirmados,
        _planejados = planejados;

  @override
  int get countPendentesNf => _pendentes;
  @override
  int get totalConfirmados => _confirmados;
  @override
  int get totalPlanejados => _planejados;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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

  @override
  Future<void> loginERestaurar(String cpf, String senha) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ── Testes golden ─────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // Impede google_fonts de fazer requisições HTTP em testes.
    // As fontes usarão o fallback do sistema, garantindo determinismo.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Suprime erros de "fonte não encontrada nos assets" do google_fonts.
    // Widgets renderizam com a fonte padrão do sistema nos golden tests.
    final prevHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) return;
      prevHandler?.call(details);
    };
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('golden — BottomNav index=0, sem badge', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        bottomNavigationBar: ChangeNotifierProvider<ServicoProvider>.value(
          value: _FakeServico(),
          child: BottomNav(
            currentIndex: 0,
            onTap: (_) {},
            onAddServico: () {},
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BottomNav),
      matchesGoldenFile('goldens/bottom_nav_index0.png'),
    );
  });

  testWidgets('golden — BottomNav index=2 (Notas) com badge 3', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        bottomNavigationBar: ChangeNotifierProvider<ServicoProvider>.value(
          value: _FakeServico(pendentes: 3),
          child: BottomNav(
            currentIndex: 2,
            onTap: (_) {},
            onAddServico: () {},
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BottomNav),
      matchesGoldenFile('goldens/bottom_nav_badge3.png'),
    );
  });

  testWidgets('golden — AuthScreen estado inicial', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<OnboardingProvider>.value(
              value: _FakeOnboarding()),
          ChangeNotifierProvider<ServicoProvider>.value(
              value: _FakeServico()),
        ],
        child: AuthScreen(
          onLoginSucesso: () {},
          onCriarConta: () {},
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AuthScreen),
      matchesGoldenFile('goldens/auth_screen.png'),
    );
  });

  testWidgets('golden — AuthScreen com erros de validação', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<OnboardingProvider>.value(
              value: _FakeOnboarding()),
          ChangeNotifierProvider<ServicoProvider>.value(
              value: _FakeServico()),
        ],
        child: AuthScreen(
          onLoginSucesso: () {},
          onCriarConta: () {},
        ),
      ),
    ));

    // Dispara validação sem preencher campos
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AuthScreen),
      matchesGoldenFile('goldens/auth_screen_erros.png'),
    );
  });
}
