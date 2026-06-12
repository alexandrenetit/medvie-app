// lib/features/syncview/widgets/preview_fiscal_pf_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';

/// Preview fiscal do atendimento PF (FR-007/FR-008/T042).
///
/// Para tomador PF autônomo, ISS e IRRF retidos são SEMPRE zero e aparecem
/// apagados (muted) — nunca como controle editável. IBS/CBS (reforma) são
/// informativos por competência e não reduzem o líquido do prestador.
///
/// Widget presentational puro: recebe os valores já calculados e o estado de
/// completude do endereço; não chama provider nem backend.
class PreviewFiscalPfCard extends StatelessWidget {
  final double bruto;
  final double ibs;
  final double cbs;
  final double liquido;

  /// Endereço fiscal completo o suficiente para emitir (FR-005). Define o
  /// indicador de status quando já há valor informado.
  final bool enderecoCompleto;

  const PreviewFiscalPfCard({
    super.key,
    required this.bruto,
    required this.ibs,
    required this.cbs,
    required this.liquido,
    required this.enderecoCompleto,
  });

  /// Pronto para emitir quando há valor e o endereço fiscal está completo.
  bool get prontoParaEmitir => bruto > 0 && enderecoCompleto;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F17),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0D3326)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _linha('Valor do serviço', fmt.format(bruto)),
          _linha('IBS', fmt.format(ibs), tag: 'REFORMA'),
          _linha('CBS', fmt.format(cbs), tag: 'REFORMA'),
          // ISS/IRRF do PF: sempre zero, apagados (FR-007).
          _linha('ISS retido (PF)', fmt.format(0), muted: true),
          _linha('IRRF retido (PF)', fmt.format(0), muted: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFF0D3326)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Valor da NFS-e',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                fmt.format(liquido),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _statusIndicator(),
          const SizedBox(height: 8),
          const Text(
            'PF autônomo: ISS/IRRF = 0. IBS/CBS informativos por competência; '
            'não reduzem o líquido do prestador.',
            style: TextStyle(
              fontSize: 10,
              height: 1.35,
              color: AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(
    String label,
    String valor, {
    String? tag,
    bool muted = false,
  }) {
    final cor = muted ? AppColors.textFaint : AppColors.textMid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: cor)),
              if (tag != null) ...[
                const SizedBox(width: 6),
                _reformaTag(tag),
              ],
            ],
          ),
          Text(
            valor,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: cor),
          ),
        ],
      ),
    );
  }

  Widget _reformaTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.cyan.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.cyan,
          ),
        ),
      );

  Widget _statusIndicator() {
    final String texto;
    final Color cor;
    if (bruto <= 0) {
      texto = 'Informe o valor';
      cor = AppColors.amber;
    } else if (!enderecoCompleto) {
      texto = 'Complete o endereço para emitir';
      cor = AppColors.amber;
    } else {
      texto = 'Pronto para emitir';
      cor = AppColors.green;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('preview-pf-status'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cor.withValues(alpha: 0.30)),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cor,
          ),
        ),
      ),
    );
  }
}
