// lib/features/syncview/widgets/pipeline_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/dashboard_response.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/utils/formatters.dart';

/// Pipeline financeiro do mês (opção 1b): barra segmentada
/// recebido / a receber / aguardando emissão + legenda.
///
/// Valores vêm prontos do backend via `DashboardProvider.dashboard.pipeline`.
/// Degrada com segurança:
/// - loading inicial → barra e legenda em skeleton;
/// - `pipeline == null` (backend legado) → barra cinza + valores "—";
/// - `pipeline.vazio` (mês sem movimento) → barra cinza + legenda zerada.
class PipelineCard extends StatelessWidget {
  final VoidCallback? onRecebidoTap;
  final VoidCallback? onAReceberTap;
  final VoidCallback? onAguardandoTap;

  const PipelineCard({
    super.key,
    this.onRecebidoTap,
    this.onAReceberTap,
    this.onAguardandoTap,
  });

  static const Color _cinzaBarra = Color(0x12FFFFFF); // rgba(255,255,255,0.07)

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DashboardProvider>();
    final loading = prov.isLoading && prov.dashboard == null;
    final pipeline = prov.dashboard?.pipeline;

    // Mês sem movimento algum: a seção inteira some — a tela assume o estado de
    // primeiro uso (regra do handoff: nenhuma seção renderiza zerada).
    if (pipeline != null && pipeline.vazio) return const SizedBox.shrink();

    // Legenda: só estágios com valor > 0 (nunca renderizar "R$ 0").
    final legendas = <Widget>[];
    if (pipeline != null) {
      void add(
        Color cor,
        String rotulo,
        PipelineSegmento seg,
        String Function(int) contagem,
        VoidCallback? onTap,
      ) {
        if (seg.valor <= 0) return;
        legendas.add(
          _Legenda(
            cor: cor,
            rotulo: rotulo,
            segmento: seg,
            contagem: contagem,
            onTap: onTap,
          ),
        );
      }

      add(
        AppColors.green,
        'Recebido',
        pipeline.recebido,
        (n) => n == 1 ? '1 NF paga' : '$n NFs pagas',
        onRecebidoTap,
      );
      add(
        AppColors.cyan,
        'A receber',
        pipeline.aReceber,
        (n) => n == 1 ? '1 NF autorizada' : '$n NFs autorizadas',
        onAReceberTap,
      );
      add(
        AppColors.amber,
        'Aguardando emissão',
        pipeline.aguardandoEmissao,
        (n) => n == 1 ? '1 atendimento' : '$n atendimentos',
        onAguardandoTap,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sem espaçador: as rows de legenda têm minHeight 48 (alvo de toque)
          // com conteúdo centralizado — o padding interno (~15px) já entrega o
          // margin-top de 14px do design entre a barra e a primeira linha.
          _buildBarra(loading: loading, pipeline: pipeline),
          ...legendas,
        ],
      ),
    );
  }

  Widget _buildBarra({
    required bool loading,
    required PipelineResumo? pipeline,
  }) {
    // Skeleton / indisponível / mês vazio → barra única cinza.
    if (loading || pipeline == null || pipeline.total <= 0) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: _cinzaBarra,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    // Segmentos proporcionais; valor 0 não aparece; gap 3px entre eles.
    final segmentos = <_SegView>[
      _SegView(pipeline.recebido.valor, AppColors.green),
      _SegView(pipeline.aReceber.valor, AppColors.cyan),
      _SegView(pipeline.aguardandoEmissao.valor, AppColors.amber),
    ].where((s) => s.valor > 0).toList();

    final children = <Widget>[];
    for (var i = 0; i < segmentos.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 3));
      final s = segmentos[i];
      // flex inteiro proporcional ao valor (mínimo 1 para não sumir).
      final flex = (s.valor).round().clamp(1, 1 << 30);
      children.add(
        Expanded(
          flex: flex,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: s.cor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }

    return SizedBox(height: 12, child: Row(children: children));
  }
}

class _SegView {
  final double valor;
  final Color cor;
  const _SegView(this.valor, this.cor);
}

/// Uma linha da legenda: swatch + rótulo + contagem + valor no tom do estágio.
/// Só é construída para estágios com valor > 0 (o filtro vive no [PipelineCard]).
class _Legenda extends StatelessWidget {
  final Color cor;
  final String rotulo;
  final PipelineSegmento segmento;
  final String Function(int) contagem;
  final VoidCallback? onTap;

  const _Legenda({
    required this.cor,
    required this.rotulo,
    required this.segmento,
    required this.contagem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valorTexto = segmento.valor.toBrl();
    final contagemTexto =
        segmento.quantidade > 0 ? contagem(segmento.quantidade) : null;

    final row = Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            rotulo,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              color: AppColors.textMid,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        if (contagemTexto != null) ...[
          Text(
            contagemTexto,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textCool,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          valorTexto,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            color: cor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: row,
      );
    }
    // Alvo de toque ≥ 48px (regra do handoff) sem inflar o visual da legenda:
    // conteúdo centralizado verticalmente dentro da área mínima de toque.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        child: row,
      ),
    );
  }
}
