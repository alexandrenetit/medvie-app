// lib/features/syncview/widgets/competencia_banner.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

/// Faixa exibida quando a SyncView está numa competência que não é o mês
/// corrente: sinaliza que os dados são de um mês passado e oferece atalho para
/// voltar ao mês atual. O [mes] vem do estado de navegação da tela.
class CompetenciaBanner extends StatelessWidget {
  final DateTime mes;
  final VoidCallback onHoje;

  const CompetenciaBanner({super.key, required this.mes, required this.onHoje});

  static const List<String> _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.amber.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.history, size: 15, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vendo ${_meses[mes.month - 1]} de ${mes.year}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.amber,
              ),
            ),
          ),
          GestureDetector(
            onTap: onHoje,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'hoje',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
