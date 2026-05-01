// lib/features/notas/widgets/emissao_confirmacao_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/servico.dart';

class EmissaoConfirmacaoSheet {
  // ───────────────────────────────────────────────
  // Public API
  // ───────────────────────────────────────────────

  static Future<bool> showIndividual(
    BuildContext context,
    Servico servico,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _IndividualSheet(servico: servico),
    );
    return result ?? false;
  }

  static Future<bool> showLote(
    BuildContext context,
    List<Servico> servicos,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LoteSheet(servicos: servicos),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet Individual
// ─────────────────────────────────────────────────────────────────────────────

class _IndividualSheet extends StatelessWidget {
  final Servico servico;

  const _IndividualSheet({required this.servico});

  @override
  Widget build(BuildContext context) {
    final issValor = servico.issRetido
        ? servico.valor * servico.aliquotaIss / 100
        : 0.0;
    const irrfValor = 0.0;
    final liquido = servico.valor - issValor - irrfValor;

    return _SheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _HandleBar(),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmar emissão da NFS-e',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Verifique os dados antes de transmitir. Após a emissão, '
                      'o cancelamento sujeita-se às regras do município.',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Linhas de detalhe
          _InfoRow(label: 'Tomador', value: servico.tomadorNome),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Data do serviço',
            value: _dataFormatada(servico.data),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Tipo', value: servico.tipo.label),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Bruto',
            value: _valorFormatado(servico.valor),
            valueStyle: _monoStyle(AppColors.green, 13),
          ),
          const SizedBox(height: 12),

          // ISS e IRRF retidos
          Row(
            children: [
              _RetidoChip(
                label: 'ISS retido',
                valor: issValor,
              ),
              const SizedBox(width: 8),
              _RetidoChip(
                label: 'IRRF retido',
                valor: irrfValor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Líquido estimado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Líquido estimado',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMid,
                ),
              ),
              Text(
                _valorFormatado(liquido),
                style: _monoStyle(AppColors.green, 15),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Warning box
          _WarningBox(
            text: 'A NFS-e será transmitida à Receita Federal. '
                'Cancelamentos dependem de prazo e regras municipais.',
          ),
          const SizedBox(height: 20),

          // Botões
          _ActionButtons(
            onRevisar: () => Navigator.of(context).pop(false),
            onConfirmar: () => Navigator.of(context).pop(true),
            labelConfirmar: 'Emitir NFS-e',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet Lote
// ─────────────────────────────────────────────────────────────────────────────

class _LoteSheet extends StatelessWidget {
  final List<Servico> servicos;

  const _LoteSheet({required this.servicos});

  @override
  Widget build(BuildContext context) {
    final totalBruto = servicos.fold<double>(0, (acc, s) => acc + s.valor);
    final n = servicos.length;

    return _SheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HandleBar(),
          const SizedBox(height: 20),

          // Header lote
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  color: AppColors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emitir $n NFS-e em lote',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Todas serão transmitidas simultaneamente.',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Lista resumida — limitada em altura se muitos itens
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: servicos.length,
              separatorBuilder: (_, idx) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (_, i) {
                final s = servicos[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tomadorNome,
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_dataFormatada(s.data)} · ${s.tipo.label}',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _valorFormatado(s.valor),
                        style: _monoStyle(AppColors.textMid, 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Total box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total bruto',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMid,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ISS/IRRF retidos pelo tomador',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
                Text(
                  _valorFormatado(totalBruto),
                  style: _monoStyle(AppColors.green, 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Warning box
          _WarningBox(
            text: 'As $n NFS-e serão transmitidas à Receita Federal. '
                'Cancelamentos dependem de prazo e regras municipais.',
          ),
          const SizedBox(height: 20),

          // Botões
          _ActionButtons(
            onRevisar: () => Navigator.of(context).pop(false),
            onConfirmar: () => Navigator.of(context).pop(true),
            labelConfirmar: 'Emitir $n NFS-e',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Componentes internos
// ─────────────────────────────────────────────────────────────────────────────

class _SheetScaffold extends StatelessWidget {
  final Widget child;

  const _SheetScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: child,
    );
  }
}

class _HandleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RetidoChip extends StatelessWidget {
  final String label;
  final double valor;

  const _RetidoChip({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _valorFormatado(valor),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String text;

  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: AppColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onRevisar;
  final VoidCallback onConfirmar;
  final String labelConfirmar;

  const _ActionButtons({
    required this.onRevisar,
    required this.onConfirmar,
    required this.labelConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onRevisar,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMid,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Revisar',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: onConfirmar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              '$labelConfirmar →',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

TextStyle _monoStyle(Color color, double size) {
  return GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color,
  );
}

String _dataFormatada(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

String _valorFormatado(double valor) {
  final parts = valor.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
  return 'R\$ $intPart,${parts[1]}';
}
