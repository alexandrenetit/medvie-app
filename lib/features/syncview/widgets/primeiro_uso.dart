// lib/features/syncview/widgets/primeiro_uso.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

/// Estado de primeiro uso da SyncView (opção 1b) — mês sem nenhum lançamento.
///
/// Ocupa o corpo abaixo do herói (que já mostra "R$ 0" apagado): card-convite
/// para registrar o primeiro atendimento, atalho "Simular honorário" e a seção
/// "Como funciona". Sem pipeline, sem plantão, sem pendências. [onRegistrar]
/// dispara o mesmo fluxo do FAB; [onSimular] abre o simulador de honorário.
class PrimeiroUso extends StatelessWidget {
  final VoidCallback? onRegistrar;
  final VoidCallback? onSimular;

  const PrimeiroUso({super.key, this.onRegistrar, this.onSimular});

  static const List<String> _passos = [
    'Você registra o atendimento ou plantão',
    'O Medvie valida os dados e emite a NFS-e',
    'Você acompanha tudo até o pagamento',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          _buildConvite(),
          const SizedBox(height: 12),
          _buildSimular(),
          const SizedBox(height: 24),
          _buildComoFunciona(),
        ],
      ),
    );
  }

  Widget _buildConvite() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.green,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Registre seu primeiro atendimento',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Leva menos de 30 segundos. O Medvie calcula o líquido e prepara '
            'a nota para você.',
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textDim),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onRegistrar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.bg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Registrar atendimento',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimular() {
    return InkWell(
      onTap: onSimular,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calculate_outlined,
                color: AppColors.cyan,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simular honorário',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Veja o líquido antes de aceitar um serviço',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Abrir ›',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComoFunciona() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'COMO FUNCIONA',
            style: GoogleFonts.outfit(
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.textCool,
            ),
          ),
        ),
        for (var i = 0; i < _passos.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _buildPasso(i + 1, _passos[i]),
        ],
      ],
    );
  }

  Widget _buildPasso(int numero, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                color: AppColors.textDim,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: AppColors.textMid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
