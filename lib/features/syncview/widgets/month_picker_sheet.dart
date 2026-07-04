// lib/features/syncview/widgets/month_picker_sheet.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

/// Seletor de competência (mês/ano) da SyncView. Devolve o primeiro dia do mês
/// escolhido via `Navigator.pop`. Meses futuros (após [mesCorrente]) ficam
/// desabilitados — não há competência futura no fiscal. [selecionado] destaca o
/// mês em foco. Apresentação pura: quem carrega os dados do mês é a tela.
class MonthPickerSheet extends StatefulWidget {
  final DateTime selecionado;
  final DateTime mesCorrente;

  const MonthPickerSheet({
    super.key,
    required this.selecionado,
    required this.mesCorrente,
  });

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  static const List<String> _abrev = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  late int _ano;

  @override
  void initState() {
    super.initState();
    _ano = widget.selecionado.year;
  }

  bool _futuro(int mes) {
    final c = widget.mesCorrente;
    return _ano > c.year || (_ano == c.year && mes > c.month);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navAno(Icons.chevron_left, () => setState(() => _ano--)),
              Text(
                '$_ano',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              _navAno(Icons.chevron_right, () => setState(() => _ano++)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: List.generate(12, (i) => _cell(i + 1)),
          ),
        ],
      ),
    );
  }

  Widget _navAno(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 36,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: AppColors.textMid),
    ),
  );

  Widget _cell(int mes) {
    final desabilitado = _futuro(mes);
    final selecionado =
        _ano == widget.selecionado.year && mes == widget.selecionado.month;
    final cor = desabilitado
        ? AppColors.textMuted
        : (selecionado ? AppColors.green : AppColors.textMid);
    return GestureDetector(
      onTap: desabilitado
          ? null
          : () => Navigator.of(context).pop(DateTime(_ano, mes)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.green.withValues(alpha: 0.12)
              : AppColors.bg2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _abrev[mes - 1],
          style: GoogleFonts.outfit(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: cor,
          ),
        ),
      ),
    );
  }
}
