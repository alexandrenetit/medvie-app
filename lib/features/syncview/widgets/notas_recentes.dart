// lib/features/syncview/widgets/notas_recentes.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/nota_fiscal.dart';
import '../../../core/providers/nota_fiscal_provider.dart';
import '../../../core/utils/formatters.dart';

/// Seção "Notas recentes": feed das NFS-e da competência em foco (máx. 3), com
/// o status fiscal (Autorizada / Processando / Rejeitada). Fonte única: backend
/// via [NotaFiscalProvider] — apresentação de dados já carregados, sem cálculo.
/// [onVerTodas] leva à lista completa (aba Notas).
class NotasRecentes extends StatelessWidget {
  final DateTime mes;
  final VoidCallback? onVerTodas;

  const NotasRecentes({super.key, required this.mes, this.onVerTodas});

  static const int _maxItens = 3;

  /// NFS-e da competência [mes], mais recentes primeiro (por data de
  /// referência). Exclui canceladas/cancelando (ruído, não é atividade viva).
  /// Seleção é apresentação — a fonte dos dados é o provider.
  static List<NotaFiscal> recentes(List<NotaFiscal> notas, DateTime mes) {
    final doMes =
        notas.where((n) {
          final d = n.dataReferencia;
          if (d.year != mes.year || d.month != mes.month) return false;
          final st = StatusNotaExtension.fromJson(n.status);
          return st != StatusNota.cancelada &&
              st != StatusNota.cancelamentoPendente;
        }).toList()..sort(
          (a, b) => b.dataReferencia.compareTo(a.dataReferencia),
        );
    return doMes.take(_maxItens).toList();
  }

  @override
  Widget build(BuildContext context) {
    final notaProv = context.watch<NotaFiscalProvider?>();
    final lista = recentes(notaProv?.notas ?? const [], mes);

    // Sem NFS-e no mês: seção some (a atividade sem nota já aparece no fluxo).
    if (lista.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < lista.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        );
      }
      rows.add(_NotaRow(nota: lista[i], onCorrigir: onVerTodas));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notas recentes',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
                GestureDetector(
                  onTap: onVerTodas,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Ver todas',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _NotaRow extends StatelessWidget {
  final NotaFiscal nota;
  final VoidCallback? onCorrigir;

  const _NotaRow({required this.nota, required this.onCorrigir});

  String _dataRelativa(DateTime d) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(d.year, d.month, d.day);
    final diff = hoje.difference(dia).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    final status = StatusNotaExtension.fromJson(nota.status);
    final vis = _StatusVisual.of(status);
    final tipo = (_labelTipoServico(nota.tipoServico) ?? '').trim();
    final tomador = (nota.tomadorNome ?? '').trim();
    final titulo = [
      if (tipo.isNotEmpty) tipo,
      if (tomador.isNotEmpty) tomador,
    ].join(' · ');
    final valor = nota.valorBruto;
    final meta = valor == null
        ? _dataRelativa(nota.dataReferencia)
        : '${_dataRelativa(nota.dataReferencia)} · ${valor.toBrl()}';

    return InkWell(
      onTap: vis.corrigir ? onCorrigir : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo.isEmpty ? 'Nota fiscal' : titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: vis.bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                vis.label,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: vis.fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mapa de apresentação do status fiscal (do backend) → rótulo/cor do chip.
class _StatusVisual {
  final String label;
  final Color fg;
  final Color bg;
  final bool corrigir;

  const _StatusVisual(this.label, this.fg, this.bg, {this.corrigir = false});

  static _StatusVisual of(StatusNota status) {
    switch (status) {
      case StatusNota.autorizada:
        return _StatusVisual(
          'Autorizada',
          AppColors.green,
          AppColors.green.withValues(alpha: 0.12),
        );
      case StatusNota.emProcessamento:
        return _StatusVisual(
          'Processando',
          AppColors.cyan,
          AppColors.cyan.withValues(alpha: 0.12),
        );
      case StatusNota.rejeitada:
        return _StatusVisual(
          'Rejeitada · corrigir',
          AppColors.amber,
          AppColors.amber.withValues(alpha: 0.14),
          corrigir: true,
        );
      case StatusNota.cancelamentoPendente:
      case StatusNota.cancelada:
        return _StatusVisual(
          status.label,
          AppColors.textDim,
          Colors.white.withValues(alpha: 0.06),
        );
    }
  }
}

/// Rótulo em português do tipo de serviço (nome de enum backend em PascalCase,
/// ex.: "PlantaoClinico"). Mesmo mapeamento de notas_screen.dart:_tipoNota().
String? _labelTipoServico(String? raw) {
  final v = raw?.trim();
  if (v == null || v.isEmpty) return v;
  switch (v.toLowerCase()) {
    case 'plantao':
    case 'plantaoclinico':
      return 'Plantão';
    case 'atoanestesico':
      return 'Ato anestésico';
    case 'laudo':
    case 'laudoimagem':
      return 'Laudo / exame';
    case 'procedimentocirurgico':
    case 'procedimentoendoscopico':
      return 'Procedimento';
    case 'consulta':
      return 'Consulta';
    case 'atocirurgico':
      return 'Ato cirúrgico';
    case 'medicinatrabalho':
      return 'Medicina do trabalho';
    default:
      return v;
  }
}
