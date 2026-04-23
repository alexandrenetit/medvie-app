// lib/features/onboarding/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/onboarding_provider.dart';
import 'screens/step1a_dados_screen.dart';
import 'screens/step1b_grupo_screen.dart';
import 'screens/step1c_especialidade_screen.dart';
import 'screens/step2a_cnpj_screen.dart';
import 'screens/step2b_assinatura_screen.dart';
import 'screens/step3_tomadores_screen.dart';
import 'screens/step4_confirmacao_screen.dart';
import 'screens/step5_sucesso_screen.dart';

// ── Página 0 : step 1a — Dados Pessoais
// ── Página 1 : step 1b — Atuação
// ── Página 2 : step 1c — Especialidade
// ── Página 3 : step 2a — CNPJ PJ
// ── Página 4 : step 2b — Assinatura Digital
// ── Página 5 : step 3  — Tomadores  (saltada se !mostrarStep3)
// ── Página 6 : step 4  — Confirmação
// ── Página 7 : step 5  — Sucesso    (AppBar oculta)

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onConcluir;
  const OnboardingScreen({super.key, this.onConcluir});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // ── Metadados de cada página (título AppBar) ─────────────────────────────
  static const _meta = [
    'Dados Pessoais',     // 0
    'Como você atua?',    // 1
    'Especialidade',      // 2
    'Seu CNPJ',           // 3
    'Assinatura Digital', // 4
    'Tomadores',          // 5 — só mostrarStep3
    'Confirmação',        // 6
    '',                   // 7 — sucesso (sem AppBar)
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    final page = _aplicarStepInicial(provider);
    _currentPage = page;
    _pageController = PageController(initialPage: page);
  }

  int _aplicarStepInicial(OnboardingProvider provider) {
    // Mapeamento exato: stepBackend == pageIndex (0-6)
    //   0 → page 0  (1a Dados Pessoais)
    //   1 → page 1  (1b Perfil Atuação)
    //   2 → page 2  (1c Especialidade)
    //   3 → page 3  (2a CNPJ)
    //   4 → page 4  (2b Assinatura)
    //   5 → page 5  (3 Tomadores)
    //   6 → page 6  (4 Confirmação)
    final s = provider.stepAtual;
    debugPrint('🔍 [DIAG] onboarding_step backend: $s');
    debugPrint('🔍 [DIAG] perfilAtuacao: ${provider.perfilAtuacao}');
    debugPrint('🔍 [DIAG] mostrarStep3: ${provider.mostrarStep3}');
    int page = s.clamp(0, 6);

    // Fallback: step ainda não foi persistido no backend (s == 0)
    // — usa inferência local para não regredir usuários pré-migração
    if (page == 0 &&
        provider.medicoIdSalvo != null &&
        provider.cnpjProprioIdsPorCnpj.isNotEmpty) {
      page = 6;
    }

    // Ajuste para não-plantonistas: step 3 (Tomadores) não existe no fluxo.
    // Backend pode ter salvo step >= 5 — recuar 1 para evitar cair na página física 5.
    if (!provider.mostrarStep3 && page >= 5) {
      page = page - 1;
    }

    debugPrint('🔍 [DIAG] page final após ajuste: $page');
    return page;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navegação ─────────────────────────────────────────────────────────────

  bool get _mostrarStep3 =>
      context.read<OnboardingProvider>().mostrarStep3;

  void _ir(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = page);
  }

  void _next() {
    // De step 2b (página 4): pular step 3 se não for plantonista
    if (_currentPage == 4) {
      _ir(_mostrarStep3 ? 5 : 6);
      return;
    }
    _ir(_currentPage + 1);
  }

  void _voltar() {
    if (_currentPage <= 1) return; // página 0 cria o usuário — sem retorno
    // Para step 4 (página 6): retroceder para step 3 ou step 2b
    if (_currentPage == 6) {
      _ir(_mostrarStep3 ? 5 : 4);
      return;
    }
    _ir(_currentPage - 1);
  }

  void _adicionarOutroCnpj() => _ir(3); // volta para step 2a

  void _concluir() {
    if (widget.onConcluir != null) {
      widget.onConcluir!();
    } else {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final isSucesso = _currentPage == 7;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: isSucesso
          ? null
          : AppBar(
              backgroundColor: AppColors.bg,
              elevation: 0,
              leading: _currentPage > 1
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                      onPressed: _voltar,
                    )
                  : const SizedBox.shrink(),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _meta[_currentPage],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: _ProgressBar(
                  current: _currentPage,
                  mostrarStep3: provider.mostrarStep3,
                ),
              ),
            ),
      body: Builder(builder: (ctx) {
        final pages = [
          Step1aDadosScreen(onNext: _next),          // 0
          Step1bGrupoScreen(onNext: _next),           // 1
          Step1cEspecialidadeScreen(onNext: _next),   // 2
          Step2aCnpjScreen(onNext: _next),            // 3
          Step2bAssinaturaScreen(onNext: _next),      // 4
          Step3TomadoresScreen(onNext: _next),        // 5
          Step4ConfirmacaoScreen(                     // 6
            onNext: () => _ir(7),
            onAdicionarOutroCnpj: _adicionarOutroCnpj,
          ),
          Step5SucessoScreen(onNext: _concluir),     // 7
        ];
        debugPrint('🔍 [DIAG] pages count: ${pages.length}, _currentPage: $_currentPage');
        return PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: pages,
        );
      }),
    );
  }
}

// ─── Barra de progresso ──────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final bool mostrarStep3;
  const _ProgressBar({required this.current, required this.mostrarStep3});

  @override
  Widget build(BuildContext context) {
    final total = mostrarStep3 ? 8 : 7;

    // Página 5 (tomadores) só aparece quando mostrarStep3 = true.
    // Página 6 (confirmação): 7ª de 8 ou 6ª de 7.
    final int logico = switch (current) {
      5 => 6,                           // tomadores — só mostrarStep3
      6 => mostrarStep3 ? 7 : 6,        // confirmação
      7 => total,                        // sucesso
      _ => current + 1,
    };

    return LinearProgressIndicator(
      value: logico / total,
      backgroundColor: Colors.white12,
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
      minHeight: 3,
    );
  }
}
