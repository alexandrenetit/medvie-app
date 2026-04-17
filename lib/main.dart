// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/servico_provider.dart';
import 'core/providers/onboarding_provider.dart';
import 'core/providers/nota_fiscal_provider.dart';
import 'core/services/medvie_api_service.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/syncview/syncview_screen.dart';
import 'features/welcome/welcome_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = MedvieApiService();
  await apiService.carregarTokensPersistidos();

  final servicoProvider = ServicoProvider();
  await servicoProvider.carregar();

  final onboardingProvider = OnboardingProvider(api: apiService);
  await onboardingProvider.carregarMedico();

  final notaFiscalProvider = NotaFiscalProvider();
  await notaFiscalProvider.carregar();

  runApp(MedvieApp(
    servicoProvider: servicoProvider,
    onboardingProvider: onboardingProvider,
    notaFiscalProvider: notaFiscalProvider,
  ));
}

class MedvieApp extends StatelessWidget {
  final ServicoProvider servicoProvider;
  final OnboardingProvider onboardingProvider;
  final NotaFiscalProvider notaFiscalProvider;

  const MedvieApp({
    super.key,
    required this.servicoProvider,
    required this.onboardingProvider,
    required this.notaFiscalProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: servicoProvider),
        ChangeNotifierProvider.value(value: onboardingProvider),
        ChangeNotifierProvider.value(value: notaFiscalProvider),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Medvie',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF07090F),
        ),
        home: Consumer<OnboardingProvider>(
          builder: (context, provider, _) {
            if (provider.restaurando) {
              return const Scaffold(
                backgroundColor: Color(0xFF07090F),
                body: Center(child: CircularProgressIndicator(color: Color(0xFF00C98A))),
              );
            }

            // Usuário já registrado: pede senha na AuthScreen
            if (provider.cpfDigitsSalvo != null) {
              return AuthScreen(
                onLoginSucesso: () async {
                  final mid = provider.medico?.id;
                  if (mid != null) await provider.restaurarProgressoDoBackend(mid);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => provider.onboardingCompletoFlag
                          ? const SyncViewScreen()
                          : _OnboardingWrapper(
                              onConcluir: () => navigatorKey.currentState!.pushReplacement(
                                  MaterialPageRoute(builder: (_) => const SyncViewScreen()))),
                    ),
                  );
                },
                onCriarConta: () {
                  provider.resetarSessao();
                  navigatorKey.currentState!.pushReplacement(
                    MaterialPageRoute(builder: (_) => _OnboardingWrapper(
                      onConcluir: () => navigatorKey.currentState!.pushReplacement(
                          MaterialPageRoute(builder: (_) => const SyncViewScreen())),
                    )),
                  );
                },
              );
            }

            // Novo usuário: boas-vindas antes do onboarding
            return WelcomeScreen(
              onCriarConta: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => _OnboardingWrapper(
                    onConcluir: () => navigatorKey.currentState!.pushReplacement(
                      MaterialPageRoute(builder: (_) => const SyncViewScreen()),
                    ),
                  ),
                ),
              ),
              onJaTenhoConta: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => AuthScreen(
                    onLoginSucesso: () async {
                      final mid = provider.medico?.id;
                      if (mid != null) await provider.restaurarProgressoDoBackend(mid);
                      navigatorKey.currentState!.pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => provider.onboardingCompletoFlag
                              ? const SyncViewScreen()
                              : _OnboardingWrapper(
                                  onConcluir: () => navigatorKey.currentState!.pushReplacement(
                                      MaterialPageRoute(builder: (_) => const SyncViewScreen()))),
                        ),
                      );
                    },
                    onCriarConta: () {
                      provider.resetarSessao();
                      navigatorKey.currentState!.pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => _OnboardingWrapper(
                            onConcluir: () => navigatorKey.currentState!.pushReplacement(
                              MaterialPageRoute(builder: (_) => const SyncViewScreen()),
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
}

class _OnboardingWrapper extends StatelessWidget {
  final VoidCallback onConcluir;
  const _OnboardingWrapper({required this.onConcluir});

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(onConcluir: onConcluir);
  }
}
