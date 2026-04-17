// lib/features/onboarding/screens/step2b_assinatura_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/medico.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../widgets/group_selection_card.dart';

class Step2bAssinaturaScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step2bAssinaturaScreen({super.key, required this.onNext});

  @override
  State<Step2bAssinaturaScreen> createState() => _Step2bAssinaturaScreenState();
}

class _Step2bAssinaturaScreenState extends State<Step2bAssinaturaScreen> {
  MetodoAssinatura _metodo = MetodoAssinatura.certificadoA1;
  @override
  void initState() {
    super.initState();
    _metodo = context.read<OnboardingProvider>().metodoAssinaturaAtual;
  }

  void _confirmar() {
    final provider = context.read<OnboardingProvider>();
    provider.setMetodoAssinatura(_metodo);
    provider.marcarTomadoresIniciado();
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assinatura Digital',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Como sua PJ vai assinar as NFS-e? '
            'O PlugNotas usará essa configuração na hora da emissão.',
            style: TextStyle(color: AppColors.textMid, fontSize: 14),
          ),
          const SizedBox(height: 28),

          // ── Opção: Certificado A1 ────────────────────────────────────────
          GroupSelectionCard(
            icon: Icons.lock_outline,
            title: 'Certificado A1',
            subtitle: 'Arquivo .pfx gerado pela sua contabilidade',
            isSelected: _metodo == MetodoAssinatura.certificadoA1,
            onTap: () => setState(() => _metodo = MetodoAssinatura.certificadoA1),
          ),
          const SizedBox(height: 12),

          // ── Opção: gov.br ────────────────────────────────────────────────
          GroupSelectionCard(
            icon: Icons.verified_user_outlined,
            title: 'Procuração Eletrônica (gov.br)',
            subtitle: 'Autorização gov.br — sem arquivo .pfx',
            isSelected: _metodo == MetodoAssinatura.govBr,
            onTap: () => setState(() => _metodo = MetodoAssinatura.govBr),
          ),
          const SizedBox(height: 24),

          // ── Card informativo dinâmico ────────────────────────────────────
          _MetodoInfoCard(metodo: _metodo),

          const SizedBox(height: 40),

          // ── Botão Ativar CNPJ ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Próximo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card informativo por método ────────────────────────────────────────────

class _MetodoInfoCard extends StatelessWidget {
  final MetodoAssinatura metodo;
  const _MetodoInfoCard({required this.metodo});

  @override
  Widget build(BuildContext context) {
    final (cor, icone, titulo, detalhe) = switch (metodo) {
      MetodoAssinatura.certificadoA1 => (
        AppColors.cyan,
        Icons.info_outline,
        'Como funciona o Certificado A1',
        'O arquivo .pfx fica armazenado no PlugNotas (TecnoSpeed).\n'
        'Você não precisa fazer nada agora — após ativar, '
        'o PlugNotas guiará o envio seguro do certificado.\n'
        'Validade usual: 1 ano. Renove antes do vencimento.',
      ),
      MetodoAssinatura.govBr => (
        AppColors.green,
        Icons.info_outline,
        'Como funciona a Procuração Eletrônica (gov.br)',
        'Usa o certificado do PlugNotas com uma procuração emitida '
        'via gov.br.\nNenhum arquivo .pfx é necessário — ideal para '
        'médicos sem certificado A1 próprio.\n'
        'Exige e-CNPJ ou e-CPF ativo no gov.br.',
      ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icone, color: cor, size: 15),
            const SizedBox(width: 6),
            Text(titulo,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cor)),
          ]),
          const SizedBox(height: 6),
          Text(detalhe,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppColors.textMid, height: 1.5)),
        ],
      ),
    );
  }
}
