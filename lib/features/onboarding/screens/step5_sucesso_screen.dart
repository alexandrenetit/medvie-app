// lib/features/onboarding/screens/step5_sucesso_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/onboarding_provider.dart';

class Step5SucessoScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step5SucessoScreen({super.key, required this.onNext});

  @override
  State<Step5SucessoScreen> createState() => _Step5SucessoScreenState();
}

class _Step5SucessoScreenState extends State<Step5SucessoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OnboardingProvider>();
    final primeiroNome = provider.nome.split(' ').first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // ── Ícone animado ──────────────────────────────────────────────
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green.withValues(alpha: 0.12),
                border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.4), width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.green, size: 52),
            ),
          ),
          const SizedBox(height: 32),

          // ── Texto de boas-vindas ───────────────────────────────────────
          FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                Text(
                  'Tudo configurado,\nDr. $primeiroNome!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Seu perfil e CNPJ estão prontos.\n'
                  'Agora você pode emitir NFS-e diretamente pelo Medvie.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppColors.textMid,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Chips de resumo ──────────────────────────────────────
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _Chip(
                      icon: Icons.receipt_long_outlined,
                      label: '${provider.cnpjsFinalizados.length} CNPJ'
                          '${provider.cnpjsFinalizados.length != 1 ? 's' : ''} ativo'
                          '${provider.cnpjsFinalizados.length != 1 ? 's' : ''}',
                      cor: AppColors.green,
                    ),
                    _Chip(
                      icon: Icons.local_hospital_outlined,
                      label: '${provider.cnpjsFinalizados.fold(0, (acc, c) => acc + c.tomadores.length)} tomador'
                          '${provider.cnpjsFinalizados.fold(0, (acc, c) => acc + c.tomadores.length) != 1 ? 'es' : ''}'
                          ' cadastrado'
                          '${provider.cnpjsFinalizados.fold(0, (acc, c) => acc + c.tomadores.length) != 1 ? 's' : ''}',
                      cor: AppColors.cyan,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(flex: 3),

          // ── Botão Começar ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Começar a usar',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de resumo ──────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color cor;
  const _Chip({required this.icon, required this.label, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: cor, size: 15),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cor)),
      ]),
    );
  }
}
