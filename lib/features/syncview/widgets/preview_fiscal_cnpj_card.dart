// lib/features/syncview/widgets/preview_fiscal_cnpj_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';

/// Preview fiscal do atendimento Empresa/Convênio (CNPJ).
///
/// Diferente do PF, ISS/IRRF aqui **dependem do tomador** (retido ou não) —
/// mas o valor retido em R\$ só é conhecido no envio (alíquota por
/// município/competência, item do `Servico` do tomador). A UI exibe
/// "a definir no envio" ou "Não retém" sem inferir alíquota local. IBS/CBS
/// da reforma vêm do backend (`previewFiscalAtendimento`) e aparecem como
/// "calculado no envio" até a F5.T5.2 ligar o debounce.
///
/// Widget presentational puro: recebe os valores já calculados (ou 0 quando
/// pendentes). Não chama provider nem backend.
class PreviewFiscalCnpjCard extends StatelessWidget {
  /// Valor bruto do serviço em R\$.
  final double bruto;

  /// Tomador declara retenção de ISS no cadastro.
  final bool retemIss;

  /// Tomador declara retenção de IRRF no cadastro.
  final bool retemIrrf;

  /// IBS estimado pelo backend (0 até T5.2 ligar o debounce).
  final double ibs;

  /// CBS estimado pelo backend (0 até T5.2 ligar o debounce).
  final double cbs;

  /// Líquido estimado pelo backend (na F5.T5.1 = bruto, sem retenção
  /// definida; em T5.2 passa a refletir IBS/CBS).
  final double liquido;

  /// `true` quando os valores de IBS/CBS/líquido vieram do backend e podem
  /// ser exibidos como "cálculo oficial". `false` (default na T5.1) →
  /// placeholders "calculado no envio".
  final bool backendCalculado;

  /// `true` quando o toggle "Emitir agora?" está ligado E o backend já
  /// respondeu (F6.T6.1). Pílula muda para "✓ Pronto para emitir".
  final bool prontoParaEmitir;

  const PreviewFiscalCnpjCard({
    super.key,
    required this.bruto,
    required this.retemIss,
    required this.retemIrrf,
    this.ibs = 0,
    this.cbs = 0,
    required this.liquido,
    this.backendCalculado = false,
    this.prontoParaEmitir = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final issTexto = _textoIss();
    final irrfTexto = _textoIrrf();
    final ibsTexto = backendCalculado ? fmt.format(ibs) : 'calculado no envio';
    final cbsTexto = backendCalculado ? fmt.format(cbs) : 'calculado no envio';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _linha('Valor do serviço', fmt.format(bruto)),
          _linha('ISS retido', issTexto, muted: !retemIss),
          _linha('IRRF retido', irrfTexto, muted: !retemIrrf),
          _linha('IBS', ibsTexto, tag: 'REFORMA', muted: !backendCalculado),
          _linha('CBS', cbsTexto, tag: 'REFORMA', muted: !backendCalculado),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.border),
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
            'Retenções e IBS/CBS são definidos no envio. A UI não infere '
            'alíquota — o cálculo oficial vem do backend.',
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

  String _textoIss() {
    if (!retemIss) return 'Não retém';
    if (!backendCalculado) return 'a definir no envio';
    return 'a definir no envio';
  }

  String _textoIrrf() {
    if (!retemIrrf) return 'Não retém';
    if (!backendCalculado) return 'a definir no envio';
    return 'a definir no envio';
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
    if (prontoParaEmitir && backendCalculado && bruto > 0) {
      // Toggle "Emitir agora?" + backend respondeu: confirmar emissão.
      texto = '✓ Pronto para emitir';
      cor = AppColors.green;
    } else if (bruto <= 0) {
      texto = 'Informe o valor';
      cor = AppColors.amber;
    } else if (backendCalculado) {
      texto = 'Cálculo oficial do backend';
      cor = AppColors.green;
    } else {
      texto = 'Cálculo oficial no envio';
      cor = AppColors.cyan;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('preview-cnpj-status'),
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
