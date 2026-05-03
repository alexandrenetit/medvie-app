// integration_test/helpers/test_app.dart
//
// Monta o MedvieApp com providers falsos para testes de integração.
// Evita chamadas de rede reais; o estado inicial é controlado pelo teste.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/providers/relatorio_anual_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/providers/simulador_provider.dart';
import 'package:medvie/features/auth/auth_screen.dart';
import 'package:medvie/features/onboarding/onboarding_screen.dart';
import 'package:medvie/features/syncview/syncview_screen.dart';
import 'package:medvie/features/welcome/welcome_screen.dart';
import 'package:medvie/main.dart' show navigatorKey, routeObserver;

import 'fakes.dart';

/// Constrói e bombeia o app de teste no [tester].
///
/// [onboarding] — controla o estado de sessão (quem está logado).
/// Todos os outros providers usam fakes vazios.
Widget buildTestApp({
  required FakeOnboarding onboarding,
  FakeServico? servico,
  FakeNotaFiscal? notaFiscal,
  FakeRelatorioAnual? relatorio,
  FakeSimulador? simulador,
}) {
  final fakeServico = servico ?? FakeServico();
  final fakeNotaFiscal = notaFiscal ?? FakeNotaFiscal();
  final fakeRelatorio = relatorio ?? FakeRelatorioAnual();
  final fakeSimulador = simulador ?? FakeSimulador();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ServicoProvider>.value(value: fakeServico),
      ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
      ChangeNotifierProvider<NotaFiscalProvider>.value(value: fakeNotaFiscal),
      ChangeNotifierProvider<RelatorioAnualProvider>.value(value: fakeRelatorio),
      ChangeNotifierProvider<SimuladorProvider>.value(value: fakeSimulador),
    ],
    child: MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Medvie Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090F),
      ),
      home: Consumer<OnboardingProvider>(
        builder: (context, provider, _) {
          if ((provider as FakeOnboarding).restaurando) {
            return const Scaffold(
              backgroundColor: Color(0xFF07090F),
              body: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00C98A))),
            );
          }

          if (provider.cpfDigitsSalvo != null) {
            return AuthScreen(
              onLoginSucesso: () {
                fakeNotaFiscal.conectarSse('');
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => provider.onboardingCompletoFlag
                        ? const SyncViewScreen()
                        : OnboardingScreen(
                            onConcluir: () =>
                                navigatorKey.currentState!.pushReplacement(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SyncViewScreen()))),
                  ),
                );
              },
              onCriarConta: () {
                provider.resetarSessao();
                navigatorKey.currentState!.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => OnboardingScreen(
                        onConcluir: () =>
                            navigatorKey.currentState!.pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const SyncViewScreen()))),
                  ),
                );
              },
            );
          }

          return WelcomeScreen(
            onCriarConta: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => OnboardingScreen(
                  onConcluir: () => navigatorKey.currentState!.pushReplacement(
                    MaterialPageRoute(builder: (_) => const SyncViewScreen()),
                  ),
                ),
              ),
            ),
            onJaTenhoConta: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AuthScreen(
                  onLoginSucesso: () {
                    fakeNotaFiscal.conectarSse('');
                    navigatorKey.currentState!.pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const SyncViewScreen()),
                    );
                  },
                  onCriarConta: () {
                    provider.resetarSessao();
                    navigatorKey.currentState!.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => OnboardingScreen(
                          onConcluir: () =>
                              navigatorKey.currentState!.pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => const SyncViewScreen()),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
