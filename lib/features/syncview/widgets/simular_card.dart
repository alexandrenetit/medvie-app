// lib/features/syncview/widgets/simular_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

/// Card "Simular honorário" no feed da SyncView: atalho para o simulador de
/// líquido. O cálculo é do backend (fonte da verdade) — este card apenas abre o
/// fluxo. [onAbrir] dispara o bottom sheet do simulador.
class SimularHonorarioCard extends StatelessWidget {
  final VoidCallback? onAbrir;

  const SimularHonorarioCard({super.key, this.onAbrir});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GestureDetector(
        onTap: onAbrir,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: AppColors.green,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calcule o líquido antes de aceitar',
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
                'Abrir',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
