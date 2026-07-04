// lib/features/syncview/widgets/syncview_hero.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/dashboard_response.dart';
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

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final dash = prov.dashboard;
    final semDados = dash == null;
    final loading = prov.isLoading && semDados;
    final erro = prov.error != null && semDados;

    // Título: mês vem pronto do backend (`mesReferenciaLabel`, minúsculo). A UI
    // só aplica caixa alta — nunca deriva o mês do relógio local. Sem label
    // (loading/erro/legado) → título sem sufixo "· MÊS".
    final mesLabel = dash?.mesReferenciaLabel ?? '';
    final titulo = mesLabel.isEmpty
        ? 'LÍQUIDO ESTIMADO'
        : 'LÍQUIDO ESTIMADO · ${mesLabel.toUpperCase()}';
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
            titulo,
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
            _buildValorComChips(
              loading: loading,
              erro: erro,
              liquido: liquido,
              aliquotaEfetiva: dash?.carga?.aliquotaEfetiva,
              comparativo: dash?.comparativo,
            ),
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
          // Transparência (princípio 7): decompõe o líquido em bruto − impostos,
          // valores prontos do backend (`totalBruto` + `carga.totalImpostos`).
          // O app não calcula — apenas apresenta. Some sem carga ou em erro.
          if (!primeiroUso &&
              !erro &&
              dash?.carga != null &&
              (dash?.totalBruto ?? 0) > 0) ...[
            const SizedBox(height: 3),
            _buildComposicao(dash!.totalBruto, dash.carga!.totalImpostos),
          ],
        ],
      ),
    );
  }

  /// Sublinha de transparência: "bruto R$ X · impostos R$ Y" (valores em
  /// JetBrains Mono). Fonte única backend; nenhuma alíquota inferida na UI.
  Widget _buildComposicao(double bruto, double impostos) {
    final base = GoogleFonts.outfit(fontSize: 12, color: AppColors.textCool);
    final mono = GoogleFonts.jetBrainsMono(
      fontSize: 12,
      color: AppColors.textCool,
    );
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'bruto '),
          TextSpan(text: bruto.toBrl(), style: mono),
          const TextSpan(text: ' · impostos '),
          TextSpan(text: impostos.toBrl(), style: mono),
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

  /// Valor do herói + até 2 chips inline (carga efetiva · comparativo mensal).
  /// Os chips só existem no estado normal (sem loading/erro) e cada um some
  /// conforme sua fonte: efetiva sem `carga`, comparativo sem `comparativo`.
  /// [Wrap] permite quebra em telas estreitas sem competir com o número.
  Widget _buildValorComChips({
    required bool loading,
    required bool erro,
    required double? liquido,
    required double? aliquotaEfetiva,
    required ComparativoMensal? comparativo,
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
    final valor = Text(
      texto,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 46,
        height: 1.1,
        letterSpacing: -1.5,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );

    final chips = <Widget>[
      if (!erro && aliquotaEfetiva != null) _buildChipEfetiva(aliquotaEfetiva),
      if (!erro && comparativo != null) _buildChipComparativo(comparativo),
    ];
    if (chips.isEmpty) return valor;

    // Chips empilhados num único grupo à direita do valor. Agrupá-los evita um
    // chip órfão na linha de baixo: se o grupo não couber ao lado do número (46px
    // é largo), o Wrap desce os dois juntos, nunca separados.
    final grupoChips = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          chips[i],
        ],
      ],
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [valor, grupoChips],
    );
  }

  /// Chip "efetiva 11,3%" — alíquota efetiva do backend (fração), formatada
  /// com uma casa e vírgula decimal pt-BR. Fundo discreto, texto textMid.
  Widget _buildChipEfetiva(double aliquotaEfetiva) {
    final pct = (aliquotaEfetiva * 100).toStringAsFixed(1).replaceAll('.', ',');
    return _buildChip(
      texto: 'efetiva $pct%',
      fg: AppColors.textMid,
      bg: Colors.white.withValues(alpha: 0.06),
    );
  }

  /// Chip comparativo "▲ 8% vs junho": seta/cor pelo sinal da variação (fração
  /// do backend), percentual arredondado. O nome do mês vem pronto do backend
  /// (`mesAnteriorLabel`) — a UI não deriva mês do relógio local; vazio omite
  /// o trecho "vs mês".
  Widget _buildChipComparativo(ComparativoMensal comparativo) {
    final subiu = comparativo.variacaoPercentual >= 0;
    final cor = subiu ? AppColors.green : AppColors.red;
    final seta = subiu ? '▲' : '▼';
    final pct = (comparativo.variacaoPercentual.abs() * 100).round();
    final mes = comparativo.mesAnteriorLabel;
    final vsMes = mes.isEmpty ? '' : ' vs $mes';
    return _buildChip(
      texto: '$seta $pct%$vsMes',
      fg: cor,
      bg: cor.withValues(alpha: 0.12),
    );
  }

  /// Container base dos chips: cantos suaves, padding compacto, texto em Outfit
  /// (não é valor monetário — não usa JetBrains Mono).
  Widget _buildChip({
    required String texto,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
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
