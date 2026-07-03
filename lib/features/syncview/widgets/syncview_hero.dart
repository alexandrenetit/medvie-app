// lib/features/syncview/widgets/syncview_hero.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/utils/formatters.dart';

/// Bloco herói da SyncView (opção 1b): líquido estimado do mês em destaque,
/// com sublinha "a receber · previsão".
///
/// Fonte única backend (`DashboardProvider`): o valor é `carga.liquidoPosImpostos`;
/// o app apenas apresenta, nunca calcula. [onRetry] é acionado no estado de erro.
class SyncViewHero extends StatelessWidget {
  final VoidCallback? onRetry;

  /// Estado de primeiro uso (mês sem nenhum lançamento): valor "R$ 0" apagado
  /// (#334155) + sublinha "Seu mês começa no primeiro registro", sem skeleton
  /// nem traço de erro. Decidido pela tela a partir da ausência de atividade.
  final bool primeiroUso;

  const SyncViewHero({super.key, this.onRetry, this.primeiroUso = false});

  static const List<String> _mesesMaiusc = [
    'JANEIRO',
    'FEVEREIRO',
    'MARÇO',
    'ABRIL',
    'MAIO',
    'JUNHO',
    'JULHO',
    'AGOSTO',
    'SETEMBRO',
    'OUTUBRO',
    'NOVEMBRO',
    'DEZEMBRO',
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final dash = prov.dashboard;
    final semDados = dash == null;
    final loading = prov.isLoading && semDados;
    final erro = prov.error != null && semDados;

    final mesLabel = _mesesMaiusc[DateTime.now().month - 1];
    final liquido = dash?.carga?.liquidoPosImpostos;

    // "A receber" prioriza o valor do pipeline (autoritativo por estágio) e cai
    // para totalLiquidoEstimado enquanto o backend não expõe o pipeline.
    final aReceber =
        dash?.pipeline?.aReceber.valor ?? dash?.totalLiquidoEstimado ?? 0;
    final dataPrevista = dash?.pipeline?.dataPrevista;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LÍQUIDO ESTIMADO · $mesLabel',
            style: GoogleFonts.outfit(
              fontSize: 12,
              letterSpacing: 1,
              color: AppColors.textDim,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          if (primeiroUso)
            _buildValorZero()
          else
            _buildValor(loading: loading, erro: erro, liquido: liquido),
          const SizedBox(height: 4),
          if (primeiroUso)
            _buildSublinhaPrimeiroUso()
          else
            _buildSublinha(
              erro: erro,
              temDados: !semDados,
              aReceber: aReceber,
              dataPrevista: dataPrevista,
            ),
        ],
      ),
    );
  }

  /// "R$ 0" apagado do estado de primeiro uso.
  Widget _buildValorZero() {
    return Text(
      0.toBrl(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 46,
        height: 1.1,
        letterSpacing: -1.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }

  /// Sublinha do primeiro uso — convite discreto, sem valor a receber.
  Widget _buildSublinhaPrimeiroUso() {
    return Text(
      'Seu mês começa no primeiro registro',
      style: GoogleFonts.outfit(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AppColors.textCool,
      ),
    );
  }

  Widget _buildValor({
    required bool loading,
    required bool erro,
    required double? liquido,
  }) {
    if (loading) {
      return Container(
        height: 46,
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    final texto = (erro || liquido == null) ? '—' : liquido.toBrl();
    return Text(
      texto,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 46,
        height: 1.1,
        letterSpacing: -1.5,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }

  Widget _buildSublinha({
    required bool erro,
    required bool temDados,
    required double aReceber,
    required DateTime? dataPrevista,
  }) {
    if (erro) {
      if (onRetry == null) return const SizedBox(height: 4);
      return GestureDetector(
        onTap: onRetry,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Não foi possível carregar · tentar novamente',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.cyan,
            ),
          ),
        ),
      );
    }

    // Ocultar quando não há dados ou a receber = 0.
    if (!temDados || aReceber <= 0) return const SizedBox(height: 4);

    final previsao = dataPrevista == null
        ? ''
        : ' · previsão ${_ddMM(dataPrevista)}';
    return Text(
      '${aReceber.toBrl()} a receber$previsao',
      style: GoogleFonts.outfit(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AppColors.cyan,
      ),
    );
  }

  String _ddMM(DateTime d) {
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }
}
