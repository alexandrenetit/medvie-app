// lib/features/syncview/widgets/ultimos_lancamentos.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/servico.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/utils/formatters.dart';

/// Seção "Últimos lançamentos" (opção 1b): ocupa o espaço do "Próximo plantão"
/// quando a Agenda não tem compromisso futuro mas há atividade no mês.
///
/// Feed dos serviços do mês mais recentes (máx. 3) — cada linha traz tipo +
/// tomador, data relativa + valor bruto e um badge de status. É apresentação
/// de dados já carregados; [onVerTodos] leva à lista completa (Notas).
class UltimosLancamentos extends StatelessWidget {
  final DateTime mes;
  final VoidCallback? onVerTodos;

  const UltimosLancamentos({super.key, required this.mes, this.onVerTodos});

  static const int _maxItens = 3;

  List<Servico> _recentes(List<Servico> servicos) {
    final doMes = servicos
        .where((s) => s.data.year == mes.year && s.data.month == mes.month)
        .toList()
      ..sort((a, b) {
        final porData = b.data.compareTo(a.data);
        if (porData != 0) return porData;
        final aMin = (a.horaInicio?.hour ?? 0) * 60 + (a.horaInicio?.minute ?? 0);
        final bMin = (b.horaInicio?.hour ?? 0) * 60 + (b.horaInicio?.minute ?? 0);
        return bMin.compareTo(aMin);
      });
    return doMes.take(_maxItens).toList();
  }

  @override
  Widget build(BuildContext context) {
    final servicos = context.watch<ServicoProvider>().servicos;
    final recentes = _recentes(servicos);

    // Sem atividade no mês: seção some (a tela usa o estado de primeiro uso).
    if (recentes.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < recentes.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        );
      }
      rows.add(_LancamentoRow(servico: recentes[i], onTap: onVerTodos));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Últimos lançamentos',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
                if (onVerTodos != null)
                  GestureDetector(
                    onTap: onVerTodos,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Ver todos ›',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
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

/// Uma linha do feed: tipo · tomador, data relativa + valor bruto e badge.
class _LancamentoRow extends StatelessWidget {
  final Servico servico;
  final VoidCallback? onTap;

  const _LancamentoRow({required this.servico, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge = _StatusBadge.of(servico.status);
    final titulo = '${servico.tipo.label} · ${servico.tomadorNome}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildSubtitulo(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildBadge(badge),
          ],
        ),
      ),
    );
  }

  /// "Hoje 09:10 · R$ 30.000 bruto" — valor em JetBrains Mono, resto em Outfit.
  Widget _buildSubtitulo() {
    final quando = _quando(servico);
    final base = GoogleFonts.outfit(fontSize: 11.5, color: AppColors.textCool);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: '$quando · '),
          TextSpan(
            text: servico.valor.toBrl(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11.5,
              color: AppColors.textCool,
            ),
          ),
          const TextSpan(text: ' bruto'),
        ],
      ),
    );
  }

  Widget _buildBadge(_StatusBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badge.cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        badge.label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badge.cor,
        ),
      ),
    );
  }

  /// Data relativa curta + hora de início quando houver.
  String _quando(Servico s) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final d = DateTime(s.data.year, s.data.month, s.data.day);
    final diff = hoje.difference(d).inDays;
    final String dataStr;
    if (diff == 0) {
      dataStr = 'Hoje';
    } else if (diff == 1) {
      dataStr = 'Ontem';
    } else {
      dataStr =
          '${s.data.day.toString().padLeft(2, '0')}/${s.data.month.toString().padLeft(2, '0')}';
    }
    final hi = s.horaInicio;
    if (hi == null) return dataStr;
    final hora =
        '${hi.hour.toString().padLeft(2, '0')}:${hi.minute.toString().padLeft(2, '0')}';
    return '$dataStr $hora';
  }
}

/// Rótulo + cor do badge de status para o feed de lançamentos. Deriva do
/// [StatusServico] (fonte única no app), traduzido para a linguagem fiscal do
/// design (Autorizada / Paga / Processando / Cancelada).
class _StatusBadge {
  final String label;
  final Color cor;

  const _StatusBadge(this.label, this.cor);

  static _StatusBadge of(StatusServico status) {
    switch (status) {
      case StatusServico.pago:
        return const _StatusBadge('Paga', AppColors.green);
      case StatusServico.nfEmitida:
      case StatusServico.aguardandoPagamento:
        return const _StatusBadge('Autorizada', AppColors.cyan);
      case StatusServico.nfEmProcessamento:
      case StatusServico.pendente:
        return const _StatusBadge('Processando', AppColors.textDim);
      case StatusServico.cancelado:
        return const _StatusBadge('Cancelada', AppColors.amber);
    }
  }
}
