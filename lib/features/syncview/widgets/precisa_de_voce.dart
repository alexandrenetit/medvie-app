// lib/features/syncview/widgets/precisa_de_voce.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/nota_fiscal.dart';
import '../../../core/providers/nota_fiscal_provider.dart';
import '../../../core/providers/servico_provider.dart';
import 'pendencia.dart';

/// Seção "Precisa de você" (opção 1b): pendências acionáveis.
///
/// Regra de estado vazio: quando não há pendências, a seção inteira desaparece
/// (não renderiza título nem card). [onPendenciaTap] é acionado ao tocar numa
/// linha — a navegação é resolvida pela tela (Fase 4).
class PrecisaDeVoce extends StatefulWidget {
  final void Function(Pendencia)? onPendenciaTap;

  const PrecisaDeVoce({super.key, this.onPendenciaTap});

  @override
  State<PrecisaDeVoce> createState() => _PrecisaDeVoceState();
}

class _PrecisaDeVoceState extends State<PrecisaDeVoce> {
  /// Recolhido pelo usuário: só o cabeçalho (título + contador) fica visível.
  /// Expandido por padrão — pendência é acionável e não deve começar escondida.
  bool _recolhido = false;

  @override
  Widget build(BuildContext context) {
    final servicoProv = context.watch<ServicoProvider>();
    final notaProv = context.watch<NotaFiscalProvider?>();

    // Loading inicial (spec: skeleton "hero + barra + 2 rows"): serviços ainda
    // carregando e nada em memória → 2 rows de skeleton no card.
    if (servicoProv.carregando && servicoProv.servicos.isEmpty) {
      return _secao(
        count: null,
        recolhivel: false,
        card: _card(const [_SkeletonRow(), _SkeletonRow()]),
      );
    }

    final pendencias = Pendencia.montar(
      servicos: servicoProv.servicos,
      notasRejeitadas:
          notaProv?.porStatus(StatusNota.rejeitada.name) ?? const [],
    );

    if (pendencias.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < pendencias.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        );
      }
      rows.add(
        _PendenciaRow(pendencia: pendencias[i], onTap: widget.onPendenciaTap),
      );
    }

    return _secao(
      count: pendencias.length,
      recolhivel: true,
      card: _recolhido ? null : _card(rows),
    );
  }

  /// Título + (opcional) card da seção. [card] nulo = recolhido (só cabeçalho).
  Widget _secao({
    required int? count,
    required bool recolhivel,
    required Widget? card,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(count: count, recolhivel: recolhivel),
          if (card != null) ...[const SizedBox(height: 8), card],
        ],
      ),
    );
  }

  /// Cabeçalho tocável: ícone de atenção + título + contador + chevron. Toca
  /// para recolher/expandir; sem contador (loading) fica não-recolhível.
  Widget _header({required int? count, required bool recolhivel}) {
    final conteudo = Padding(
      // Inset horizontal de 4px do design (margin: 0 4px 8px).
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.amber),
          const SizedBox(width: 8),
          Text(
            'Precisa de você',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMid,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (recolhivel)
            Icon(
              _recolhido ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: AppColors.textDim,
            ),
        ],
      ),
    );

    if (!recolhivel) return conteudo;
    return GestureDetector(
      onTap: () => setState(() => _recolhido = !_recolhido),
      behavior: HitTestBehavior.opaque,
      child: conteudo,
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

/// Placeholder de linha durante o loading inicial (sem shimmer — barras cinza).
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final base = Colors.white.withValues(alpha: 0.06);

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: base, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(150, 12), const SizedBox(height: 6), bar(110, 10)],
            ),
          ),
          const SizedBox(width: 12),
          bar(56, 12),
        ],
      ),
    );
  }
}

class _PendenciaRow extends StatelessWidget {
  final Pendencia pendencia;
  final void Function(Pendencia)? onTap;

  const _PendenciaRow({required this.pendencia, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(pendencia),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pendencia.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  if (pendencia.subtitulo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      pendencia.subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              pendencia.acaoLabel,
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
}
