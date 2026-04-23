// lib/features/syncview/widgets/mini_calendar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/servico.dart';
import '../../../core/providers/servico_provider.dart';
import 'servico_dia_sheet.dart';

class MiniCalendar extends StatefulWidget {
  final VoidCallback? onVerAgenda;

  const MiniCalendar({super.key, this.onVerAgenda});

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  late DateTime _mesAtual;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _mesAtual = DateTime(hoje.year, hoje.month);
    _selectedDay = hoje.day;
  }

  void _mesAnterior() => setState(() {
        _mesAtual = DateTime(_mesAtual.year, _mesAtual.month - 1);
        _selectedDay = null;
      });

  void _proximoMes() => setState(() {
        _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + 1);
        _selectedDay = null;
      });

  Color? _dotColor(List<Servico> servicos, int dia) {
    final doDia = servicos.where((s) =>
        s.data.year == _mesAtual.year &&
        s.data.month == _mesAtual.month &&
        s.data.day == dia);
    if (doDia.isEmpty) return null;
    // Prioridade: cancelado > pago > aguardandoPagamento > nfEmitida > nfEmProcessamento > pendente
    if (doDia.any((s) => s.status == StatusServico.cancelado)) return AppColors.red;
    if (doDia.any((s) => s.status == StatusServico.pago)) return AppColors.green;
    if (doDia.any((s) => s.status == StatusServico.aguardandoPagamento)) {
      return const Color(0xFFF97316);
    }
    if (doDia.any((s) => s.status == StatusServico.nfEmitida)) return AppColors.indigo;
    if (doDia.any((s) => s.status == StatusServico.nfEmProcessamento)) return AppColors.cyan;
    return AppColors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final servicos = context.watch<ServicoProvider>().servicos;
    final diasNoMes = DateUtils.getDaysInMonth(_mesAtual.year, _mesAtual.month);
    final primeiroDia = DateTime(_mesAtual.year, _mesAtual.month, 1);
    final offsetInicio = primeiroDia.weekday % 7;
    final hoje = DateTime.now();

    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Header navegação
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CalNavBtn(icon: Icons.chevron_left, onTap: _mesAnterior),
              GestureDetector(
                onTap: widget.onVerAgenda,
                child: Row(
                  children: [
                    Text(
                      '${meses[_mesAtual.month - 1]} ${_mesAtual.year}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (widget.onVerAgenda != null) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new,
                          size: 12, color: AppColors.textDim),
                    ],
                  ],
                ),
              ),
              _CalNavBtn(icon: Icons.chevron_right, onTap: _proximoMes),
            ],
          ),
          const SizedBox(height: 14),

          // Cabeçalho dias da semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                .map((d) => SizedBox(
                      width: 32,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDim,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Grid de dias
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: offsetInicio + diasNoMes,
            itemBuilder: (context, index) {
              if (index < offsetInicio) return const SizedBox();
              final dia = index - offsetInicio + 1;
              final isHoje = hoje.year == _mesAtual.year &&
                  hoje.month == _mesAtual.month &&
                  hoje.day == dia;
              final isSelected = _selectedDay == dia;
              final dotColor = _dotColor(servicos, dia);

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDay = dia);
                  final data = DateTime(_mesAtual.year, _mesAtual.month, dia);
                  context.read<ServicoProvider>().filtrarPorDia(data);
                  final servicosDoDia = servicos
                      .where((s) =>
                          s.data.year == _mesAtual.year &&
                          s.data.month == _mesAtual.month &&
                          s.data.day == dia)
                      .toList();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ServicosDiaSheet(
                      servicos: servicosDoDia,
                      dia: data,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.green.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dia',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isHoje || isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.green
                              : isHoje
                                  ? AppColors.text
                                  : AppColors.textMid,
                        ),
                      ),
                      if (dotColor != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // Legenda padronizada
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppColors.amber, label: 'Pendente'),
              const SizedBox(width: 10),
              _Legend(color: AppColors.cyan, label: 'Processando'),
              const SizedBox(width: 10),
              _Legend(color: AppColors.indigo, label: 'NF emitida'),
              const SizedBox(width: 10),
              _Legend(color: AppColors.green, label: 'Pago'),
              const SizedBox(width: 10),
              _Legend(color: AppColors.red, label: 'Cancelado'),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _selectedDay = null);
                context.read<ServicoProvider>().limparFiltro();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Ver todos',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CalNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(icon, color: AppColors.textMid, size: 18),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textDim),
        ),
      ],
    );
  }
}