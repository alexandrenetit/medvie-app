// lib/features/agenda/agenda_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/servico.dart';
import '../../core/models/medico.dart';
import '../../core/providers/servico_provider.dart';
import '../../core/providers/onboarding_provider.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  late DateTime _mesAtual;
  DateTime? _diaSelecionado;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _mesAtual = DateTime(hoje.year, hoje.month);
    _diaSelecionado = DateTime(hoje.year, hoje.month, hoje.day);
  }

  void _mesAnterior() => setState(() {
        _mesAtual = DateTime(_mesAtual.year, _mesAtual.month - 1);
        _diaSelecionado = null;
      });

  void _proximoMes() => setState(() {
        _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + 1);
        _diaSelecionado = null;
      });

  List<Servico> _servicosDoDia(List<Servico> todos, int dia) {
    return todos
        .where((s) =>
            s.data.year == _mesAtual.year &&
            s.data.month == _mesAtual.month &&
            s.data.day == dia)
        .toList()
      ..sort((a, b) {
        if (a.horaInicio == null && b.horaInicio == null) return 0;
        if (a.horaInicio == null) return 1;
        if (b.horaInicio == null) return -1;
        final aMin = a.horaInicio!.hour * 60 + a.horaInicio!.minute;
        final bMin = b.horaInicio!.hour * 60 + b.horaInicio!.minute;
        return aMin.compareTo(bMin);
      });
  }

  List<Servico> _servicosDoDiaObj(List<Servico> todos, DateTime dia) {
    return _servicosDoDia(todos, dia.day);
  }

  List<Tomador> _getTomadores() {
    return context.read<OnboardingProvider>().medicoSalvo?.tomadores ??
        context.read<OnboardingProvider>().tomadores;
  }

  void _abrirDetalhe(Servico servico) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ServicoDetalheSheet(
        servico: servico,
        tomadores: _getTomadores(),
      ),
    );
  }

  void _abrirAddServico(DateTime data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddServicoAgendaSheet(
        dataInicial: data,
        tomadores: _getTomadores(),
      ),
    );
  }

  void _onDiaTap(DateTime dia, List<Servico> servicosDoDia) {
    final jaSelecionado = _diaSelecionado != null &&
        _diaSelecionado!.year == dia.year &&
        _diaSelecionado!.month == dia.month &&
        _diaSelecionado!.day == dia.day;

    if (jaSelecionado && servicosDoDia.isEmpty) {
      _abrirAddServico(dia);
    } else {
      setState(() => _diaSelecionado = dia);
      if (servicosDoDia.isEmpty) {
        Future.microtask(() => _abrirAddServico(dia));
      }
    }
  }

  // ── helper centralizado de cor por status ──────────────────────────────
  Color _corStatus(StatusServico status) {
    switch (status) {
      case StatusServico.nfEmitida:
        return AppColors.cyan;
      case StatusServico.confirmado:
      case StatusServico.aguardandoNf:
      case StatusServico.nfEmProcessamento:
        return AppColors.green;
      case StatusServico.cancelado:
      case StatusServico.nfRejeitada:
        return AppColors.red;
      case StatusServico.planejado:
        return AppColors.amber;
    }
  }

  // ── cor do dot com prioridade: cancelado > NF emitida > confirmado > planejado
  Color? _dotColor(List<Servico> servicosNoDia) {
    if (servicosNoDia.isEmpty) return null;
    if (servicosNoDia.any((s) =>
        s.status == StatusServico.cancelado ||
        s.status == StatusServico.nfRejeitada)) {
      return AppColors.red;
    }
    if (servicosNoDia.any((s) => s.status == StatusServico.nfEmitida)) {
      return AppColors.cyan;
    }
    if (servicosNoDia.any((s) =>
        s.status == StatusServico.confirmado ||
        s.status == StatusServico.aguardandoNf ||
        s.status == StatusServico.nfEmProcessamento)) {
      return AppColors.green;
    }
    return AppColors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final servicos = context.watch<ServicoProvider>().servicos;
    final diasNoMes = DateUtils.getDaysInMonth(_mesAtual.year, _mesAtual.month);
    final primeiroDia = DateTime(_mesAtual.year, _mesAtual.month, 1);
    final offsetInicio = primeiroDia.weekday % 7;

    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];

    final servicosDiaSelecionado = _diaSelecionado != null
        ? _servicosDoDiaObj(servicos, _diaSelecionado!)
        : <Servico>[];

    final servicosMes = servicos
        .where((s) =>
            s.data.year == _mesAtual.year &&
            s.data.month == _mesAtual.month)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Agenda',
                  style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              Row(
                children: [
                  _NavBtn(icon: Icons.chevron_left, onTap: _mesAnterior),
                  const SizedBox(width: 8),
                  _NavBtn(icon: Icons.chevron_right, onTap: _proximoMes),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${meses[_mesAtual.month - 1]} ${_mesAtual.year}',
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textDim)),
          const SizedBox(height: 24),

          // ── Calendário ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              children: [
                Row(
                  children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                      .map((d) => Expanded(
                            child: Center(
                              child: Text(d,
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDim)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app_outlined,
                        size: 10, color: AppColors.textDim),
                    const SizedBox(width: 4),
                    Text(
                      'Toque em um dia para adicionar serviço',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: AppColors.textDim.withOpacity(0.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: offsetInicio + diasNoMes,
                  itemBuilder: (_, index) {
                    if (index < offsetInicio) return const SizedBox.shrink();
                    final dia = index - offsetInicio + 1;
                    final diaDateTime =
                        DateTime(_mesAtual.year, _mesAtual.month, dia);
                    final servicosNoDia = _servicosDoDia(servicos, dia);
                    final hoje = DateTime.now();
                    final isHoje = hoje.year == _mesAtual.year &&
                        hoje.month == _mesAtual.month &&
                        hoje.day == dia;
                    final isSelecionado = _diaSelecionado != null &&
                        _diaSelecionado!.year == _mesAtual.year &&
                        _diaSelecionado!.month == _mesAtual.month &&
                        _diaSelecionado!.day == dia;
                    final temServico = servicosNoDia.isNotEmpty;
                    final dotColor = _dotColor(servicosNoDia);

                    return GestureDetector(
                      onTap: () => _onDiaTap(diaDateTime, servicosNoDia),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: isSelecionado
                                ? BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.green,
                                        AppColors.cyan
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  )
                                : isHoje
                                    ? BoxDecoration(
                                        color: AppColors.green
                                            .withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.green,
                                            width: 1),
                                      )
                                    : temServico
                                        ? BoxDecoration(
                                            color: dotColor!.withOpacity(0.08),
                                            shape: BoxShape.circle,
                                          )
                                        : null,
                            child: Center(
                              child: Text('$dia',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: isSelecionado ||
                                            isHoje ||
                                            temServico
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isSelecionado
                                        ? Colors.black
                                        : isHoje
                                            ? AppColors.green
                                            : temServico
                                                ? dotColor
                                                : AppColors.text,
                                  )),
                            ),
                          ),
                          if (temServico)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: servicosNoDia.take(3).map((s) {
                                return Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(
                                      top: 2, left: 1, right: 1),
                                  decoration: BoxDecoration(
                                    color: isSelecionado
                                        ? Colors.white.withOpacity(0.8)
                                        : _corStatus(s.status),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            const SizedBox(height: 6),
                        ],
                      ),
                    );
                  },
                ),

                // ── Legenda padronizada ──────────────────────────────
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legenda(color: AppColors.green, label: 'Confirmado'),
                    const SizedBox(width: 12),
                    _Legenda(color: AppColors.amber, label: 'Planejado'),
                    const SizedBox(width: 12),
                    _Legenda(color: AppColors.cyan, label: 'NF emitida'),
                    const SizedBox(width: 12),
                    _Legenda(color: AppColors.red, label: 'Cancelado'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Day Sheet ────────────────────────────────────────────────
          if (_diaSelecionado != null &&
              servicosDiaSelecionado.isNotEmpty) ...[
            _DaySheet(
              dia: _diaSelecionado!,
              servicos: servicosDiaSelecionado,
              onAdicionar: () => _abrirAddServico(_diaSelecionado!),
              onVerDetalhe: _abrirDetalhe,
              corStatus: _corStatus,
            ),
            const SizedBox(height: 20),
          ],

          // ── Lista do mês ─────────────────────────────────────────────
          Text('Serviços do mês (${servicosMes.length})',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDim)),
          const SizedBox(height: 12),

          if (servicosMes.isEmpty)
            _buildVazio()
          else
            ...servicosMes.map((s) => GestureDetector(
                  onTap: () => _abrirDetalhe(s),
                  child: _AgendaTile(servico: s, corStatus: _corStatus),
                )),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Center(
        child: Text('Nenhum serviço neste mês.',
            style:
                GoogleFonts.outfit(fontSize: 13, color: AppColors.textDim)),
      ),
    );
  }
}

// ─── Day Sheet ────────────────────────────────────────────────────────────

class _DaySheet extends StatelessWidget {
  final DateTime dia;
  final List<Servico> servicos;
  final VoidCallback onAdicionar;
  final ValueChanged<Servico> onVerDetalhe;
  final Color Function(StatusServico) corStatus;

  const _DaySheet({
    required this.dia,
    required this.servicos,
    required this.onAdicionar,
    required this.onVerDetalhe,
    required this.corStatus,
  });

  @override
  Widget build(BuildContext context) {
    const meses = [
      '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    const diasSemana = [
      '', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'
    ];

    final diaStr =
        '${diasSemana[dia.weekday]}, ${dia.day} de ${meses[dia.month].toUpperCase()}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(diaStr,
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMid,
                            letterSpacing: 0.3)),
                    if (servicos.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${servicos.length}',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.green)),
                      ),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: onAdicionar,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.green.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.add,
                        size: 18, color: AppColors.green),
                  ),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: Colors.white.withOpacity(0.05),
              indent: 16,
              endIndent: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: servicos.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.04),
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (_, i) {
              final s = servicos[i];
              final color = corStatus(s.status);
              return GestureDetector(
                onTap: () => onVerDetalhe(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: s.horaInicio != null
                            ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '${s.horaInicio!.hour.toString().padLeft(2, '0')}:${s.horaInicio!.minute.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMid),
                                  ),
                                  if (s.duracaoFormatada != null)
                                    Text(
                                      s.duracaoFormatada!,
                                      style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          color: AppColors.textDim),
                                    ),
                                ],
                              )
                            : Center(
                                child: Text(s.tipo.icone,
                                    style:
                                        const TextStyle(fontSize: 18)),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.tomadorNome,
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text),
                                overflow: TextOverflow.ellipsis),
                            Text(s.tipo.label,
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.textDim)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            s.valor > 0
                                ? 'R\$ ${s.valor.toStringAsFixed(0)}'
                                : 'A definir',
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                color: s.valor > 0
                                    ? AppColors.textMid
                                    : AppColors.textDim),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(s.status.label,
                                style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: color)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Modal de adicionar serviço pela agenda ───────────────────────────────

class _AddServicoAgendaSheet extends StatefulWidget {
  final DateTime dataInicial;
  final List<Tomador> tomadores;

  const _AddServicoAgendaSheet({
    required this.dataInicial,
    required this.tomadores,
  });

  @override
  State<_AddServicoAgendaSheet> createState() =>
      _AddServicoAgendaSheetState();
}

class _AddServicoAgendaSheetState extends State<_AddServicoAgendaSheet> {
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();

  late DateTime _dataSelecionada;
  StatusServico _statusSelecionado = StatusServico.planejado;
  TipoServico _tipoSelecionado = TipoServico.plantao;
  Tomador? _tomadorSelecionado;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _dataSelecionada = widget.dataInicial;
    if (widget.tomadores.isNotEmpty) {
      _tomadorSelecionado = widget.tomadores.first;
      if (_tomadorSelecionado!.valorPadrao > 0) {
        _valorController.text =
            _tomadorSelecionado!.valorPadrao.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarHora(bool isInicio) async {
    final inicial = isInicio
        ? (_horaInicio ?? const TimeOfDay(hour: 7, minute: 0))
        : (_horaFim ?? const TimeOfDay(hour: 19, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.green,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _horaInicio = picked;
        } else {
          _horaFim = picked;
        }
      });
    }
  }

  Future<void> _salvar() async {
    if (_tomadorSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o hospital / clínica'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }

    double valor = 0.0;
    final textoValor = _valorController.text.trim();
    if (textoValor.isNotEmpty) {
      final parsed = double.tryParse(textoValor.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Valor inválido'),
              backgroundColor: AppColors.surface),
        );
        return;
      }
      valor = parsed;
    }

    setState(() => _salvando = true);

    await context.read<ServicoProvider>().adicionarServico(
          tipo: _tipoSelecionado,
          data: _dataSelecionada,
          tomadorCnpj: _tomadorSelecionado!.cnpj,
          tomadorNome: _tomadorSelecionado!.razaoSocial,
          valor: valor,
          status: _statusSelecionado,
          observacao: _observacaoController.text.trim(),
          horaInicio: _horaInicio,
          horaFim: _horaFim,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const meses = [
      '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];
    const diasSemana = [
      '', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'
    ];

    final diaLabel =
        '${diasSemana[_dataSelecionada.weekday]}, ${_dataSelecionada.day} ${meses[_dataSelecionada.month].toUpperCase()}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textDim,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                Text('Novo serviço',
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppColors.green),
                      const SizedBox(width: 5),
                      Text(
                        diaLabel,
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildLabel('Tipo de serviço'),
            const SizedBox(height: 8),
            _buildDropdownContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TipoServico>(
                  value: _tipoSelecionado,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  items: TipoServico.values.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Row(
                        children: [
                          Text(tipo.icone,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Text(tipo.label,
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.text)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (t) {
                    if (t != null) setState(() => _tipoSelecionado = t);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Hospital / Clínica'),
            const SizedBox(height: 8),
            widget.tomadores.isEmpty
                ? _buildSemTomadores()
                : _buildDropdownContainer(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Tomador>(
                        value: _tomadorSelecionado,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        hint: Text('Selecione o hospital / clínica',
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: AppColors.textDim)),
                        items: widget.tomadores.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(t.razaoSocial,
                                    style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text),
                                    overflow: TextOverflow.ellipsis),
                                Text(
                                  t.valorPadrao > 0
                                      ? '${t.municipio}  ·  R\$ ${t.valorPadrao.toStringAsFixed(0)}'
                                      : t.municipio,
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppColors.textDim),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (t) {
                          setState(() {
                            _tomadorSelecionado = t;
                            if (t != null && t.valorPadrao > 0) {
                              _valorController.text =
                                  t.valorPadrao.toStringAsFixed(0);
                            } else {
                              _valorController.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildLabel('Valor bruto (R\$)'),
                const SizedBox(width: 6),
                _badge('opcional'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valorController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 15, color: AppColors.text),
              decoration: _inputDec(hint: 'A definir'),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildLabel('Horário'),
                const SizedBox(width: 6),
                _badge('opcional'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HorarioBtn(
                    label: 'Início',
                    hora: _horaInicio,
                    onTap: () => _selecionarHora(true),
                    onClear: _horaInicio != null
                        ? () => setState(() => _horaInicio = null)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HorarioBtn(
                    label: 'Fim',
                    hora: _horaFim,
                    onTap: () => _selecionarHora(false),
                    onClear: _horaFim != null
                        ? () => setState(() => _horaFim = null)
                        : null,
                  ),
                ),
              ],
            ),
            if (_horaInicio != null && _horaFim != null) ...[
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final inicioMin =
                    _horaInicio!.hour * 60 + _horaInicio!.minute;
                final fimMin = _horaFim!.hour * 60 + _horaFim!.minute;
                int diff = fimMin - inicioMin;
                if (diff <= 0) diff += 24 * 60;
                final h = diff ~/ 60;
                final m = diff % 60;
                final durStr = m == 0
                    ? '${h}h de duração'
                    : '${h}h${m.toString().padLeft(2, '0')} de duração';
                return Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 13, color: AppColors.cyan),
                    const SizedBox(width: 4),
                    Text(durStr,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.cyan)),
                  ],
                );
              }),
            ],
            const SizedBox(height: 16),

            _buildLabel('Status'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip(
                    StatusServico.planejado, 'Planejado', AppColors.amber),
                const SizedBox(width: 8),
                _buildStatusChip(
                    StatusServico.confirmado, 'Confirmado', AppColors.green),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _buildLabel('Observação'),
                const SizedBox(width: 6),
                _badge('opcional · discriminação da NFS-e'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _observacaoController,
              maxLines: 2,
              style:
                  GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              decoration:
                  _inputDec(hint: 'Preenchido automaticamente se vazio'),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text('Salvar serviço',
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textDim));

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.textDim.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: GoogleFonts.outfit(
                fontSize: 9,
                color: AppColors.textDim,
                fontWeight: FontWeight.w500)),
      );

  Widget _buildDropdownContainer({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: child,
      );

  Widget _buildSemTomadores() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.textDim, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nenhum tomador cadastrado. Adicione hospitais nas configurações.',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.textDim),
              ),
            ),
          ],
        ),
      );

  InputDecoration _inputDec({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.outfit(color: AppColors.textDim, fontSize: 14),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E293B))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E293B))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.green)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _buildStatusChip(StatusServico status, String label, Color color) {
    final selected = _statusSelecionado == status;
    return GestureDetector(
      onTap: () => setState(() => _statusSelecionado = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFF1E293B),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textDim)),
      ),
    );
  }
}

// ─── Bottom sheet de detalhes + edição ───────────────────────────────────

class _ServicoDetalheSheet extends StatefulWidget {
  final Servico servico;
  final List<Tomador> tomadores;

  const _ServicoDetalheSheet({
    required this.servico,
    required this.tomadores,
  });

  @override
  State<_ServicoDetalheSheet> createState() => _ServicoDetalheSheetState();
}

class _ServicoDetalheSheetState extends State<_ServicoDetalheSheet> {
  bool _editando = false;
  bool _salvando = false;
  bool _excluindo = false;

  late Tomador? _tomadorSelecionado;
  late TextEditingController _valorController;
  late DateTime _dataSelecionada;
  late StatusServico _statusSelecionado;
  late TipoServico _tipoSelecionado;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;

  Color _corStatus(StatusServico s) {
    switch (s) {
      case StatusServico.nfEmitida:
        return AppColors.cyan;
      case StatusServico.confirmado:
      case StatusServico.aguardandoNf:
      case StatusServico.nfEmProcessamento:
        return AppColors.green;
      case StatusServico.cancelado:
      case StatusServico.nfRejeitada:
        return AppColors.red;
      case StatusServico.planejado:
        return AppColors.amber;
    }
  }

  @override
  void initState() {
    super.initState();
    _dataSelecionada = widget.servico.data;
    _statusSelecionado = widget.servico.status;
    _tipoSelecionado = widget.servico.tipo;
    _horaInicio = widget.servico.horaInicio;
    _horaFim = widget.servico.horaFim;
    _valorController = TextEditingController(
      text: widget.servico.valor > 0
          ? widget.servico.valor.toStringAsFixed(0)
          : '',
    );
    try {
      _tomadorSelecionado = widget.tomadores.firstWhere(
        (t) => t.cnpj == widget.servico.tomadorCnpj,
      );
    } catch (_) {
      _tomadorSelecionado =
          widget.tomadores.isNotEmpty ? widget.tomadores.first : null;
    }
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  String _formatMoeda(double valor) {
    if (valor == 0) return 'A definir';
    final inteiro = valor.toInt();
    final str = inteiro.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'R\$ ${buffer.toString()}';
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.green,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  Future<void> _selecionarHora(bool isInicio) async {
    final inicial = isInicio
        ? (_horaInicio ?? const TimeOfDay(hour: 7, minute: 0))
        : (_horaFim ?? const TimeOfDay(hour: 19, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.green,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _horaInicio = picked;
        } else {
          _horaFim = picked;
        }
      });
    }
  }

  Future<void> _salvar() async {
    double valor = 0.0;
    final textoValor = _valorController.text.trim();
    if (textoValor.isNotEmpty) {
      final parsed = double.tryParse(textoValor.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Valor inválido'),
              backgroundColor: AppColors.surface),
        );
        return;
      }
      valor = parsed;
    }

    setState(() => _salvando = true);

    final atualizado = Servico(
      id: widget.servico.id,
      tipo: _tipoSelecionado,
      data: _dataSelecionada,
      tomadorCnpj:
          _tomadorSelecionado?.cnpj ?? widget.servico.tomadorCnpj,
      tomadorNome:
          _tomadorSelecionado?.razaoSocial ?? widget.servico.tomadorNome,
      valor: valor,
      status: _statusSelecionado,
      observacao: widget.servico.observacao,
      horaInicio: _horaInicio,
      horaFim: _horaFim,
    );

    await context.read<ServicoProvider>().atualizarServico(atualizado);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir serviço?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text('Esta ação não pode ser desfeita.',
            style: GoogleFonts.outfit(color: AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.outfit(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir',
                style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _excluindo = true);
    await context
        .read<ServicoProvider>()
        .removerServico(widget.servico.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _corStatus(_statusSelecionado);

    final dataStr =
        '${_dataSelecionada.day.toString().padLeft(2, '0')}/'
        '${_dataSelecionada.month.toString().padLeft(2, '0')}/'
        '${_dataSelecionada.year}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textDim,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _editando ? 'Editar serviço' : 'Detalhes',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text),
                ),
                Row(
                  children: [
                    if (!_editando)
                      GestureDetector(
                        onTap: _excluindo ? null : _excluir,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: _excluindo
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.redAccent))
                              : Text('Excluir',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.redAccent)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _editando = !_editando),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _editando
                              ? Colors.white.withOpacity(0.05)
                              : AppColors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _editando
                                ? Colors.white.withOpacity(0.1)
                                : AppColors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _editando ? 'Cancelar' : 'Editar',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _editando
                                  ? AppColors.textDim
                                  : AppColors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── VISUALIZAÇÃO ─────────────────────────────────────────
            if (!_editando) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.servico.tomadorNome,
                            style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.indigo.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(widget.servico.tipo.label,
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.indigo)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_statusSelecionado.label,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(dataStr,
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppColors.textDim)),
                  if (widget.servico.horarioFormatado != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time,
                        size: 13, color: AppColors.cyan),
                    const SizedBox(width: 4),
                    Text(widget.servico.horarioFormatado!,
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppColors.cyan)),
                    if (widget.servico.duracaoFormatada != null) ...[
                      const SizedBox(width: 6),
                      Text('(${widget.servico.duracaoFormatada})',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.textDim)),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BRUTO',
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDim,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 6),
                          Text(
                            _formatMoeda(widget.servico.valor),
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: widget.servico.valor > 0
                                    ? AppColors.text
                                    : AppColors.textDim),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.servico.observacao.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OBSERVAÇÃO',
                          style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDim,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      Text(widget.servico.observacao,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppColors.textMid)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDim,
                    side: BorderSide(
                        color: Colors.white.withOpacity(0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Fechar',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ),
              ),
            ],

            // ── EDIÇÃO ───────────────────────────────────────────────
            if (_editando) ...[
              _buildLabel('Tipo de serviço'),
              const SizedBox(height: 8),
              _buildDropdownContainer(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TipoServico>(
                    value: _tipoSelecionado,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: TipoServico.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.label,
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: AppColors.text)),
                      );
                    }).toList(),
                    onChanged: (t) {
                      if (t != null) {
                        setState(() => _tipoSelecionado = t);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Hospital / Clínica'),
              const SizedBox(height: 8),
              widget.tomadores.isEmpty
                  ? Text('Nenhum tomador cadastrado.',
                      style: GoogleFonts.outfit(
                          color: AppColors.textDim))
                  : _buildDropdownContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Tomador>(
                          value: _tomadorSelecionado,
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          items: widget.tomadores.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(t.razaoSocial,
                                      style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text),
                                      overflow:
                                          TextOverflow.ellipsis),
                                  Text(
                                    t.valorPadrao > 0
                                        ? '${t.municipio}/${t.uf}  ·  R\$ ${t.valorPadrao.toStringAsFixed(0)}'
                                        : '${t.municipio}/${t.uf}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.textDim),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (t) {
                            setState(() {
                              _tomadorSelecionado = t;
                              if (t != null && t.valorPadrao > 0) {
                                _valorController.text =
                                    t.valorPadrao.toStringAsFixed(0);
                              } else {
                                _valorController.clear();
                              }
                            });
                          },
                        ),
                      ),
                    ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _buildLabel('Valor bruto (R\$)'),
                          const SizedBox(width: 6),
                          _badge('opcional'),
                        ]),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _valorController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'))
                          ],
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 15, color: AppColors.text),
                          decoration: _inputDec(hint: 'A definir'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Data'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _selecionarData,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF1E293B)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: AppColors.textDim),
                                const SizedBox(width: 8),
                                Text(
                                  '${_dataSelecionada.day.toString().padLeft(2, '0')}/'
                                  '${_dataSelecionada.month.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      color: AppColors.text),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(children: [
                _buildLabel('Horário'),
                const SizedBox(width: 6),
                _badge('opcional'),
              ]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _HorarioBtn(
                      label: 'Início',
                      hora: _horaInicio,
                      onTap: () => _selecionarHora(true),
                      onClear: _horaInicio != null
                          ? () => setState(() => _horaInicio = null)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HorarioBtn(
                      label: 'Fim',
                      hora: _horaFim,
                      onTap: () => _selecionarHora(false),
                      onClear: _horaFim != null
                          ? () => setState(() => _horaFim = null)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLabel('Status'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip(StatusServico.planejado,
                      'Planejado', AppColors.amber),
                  const SizedBox(width: 8),
                  _buildStatusChip(StatusServico.confirmado,
                      'Confirmado', AppColors.green),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : Text('Salvar alterações',
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textDim));

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.textDim.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: GoogleFonts.outfit(
                fontSize: 9,
                color: AppColors.textDim,
                fontWeight: FontWeight.w500)),
      );

  Widget _buildDropdownContainer({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: child,
      );

  InputDecoration _inputDec({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.outfit(color: AppColors.textDim, fontSize: 14),
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E293B))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E293B))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.green)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _buildStatusChip(StatusServico status, String label, Color color) {
    final selected = _statusSelecionado == status;
    return GestureDetector(
      onTap: () => setState(() => _statusSelecionado = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFF1E293B),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.textDim)),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────

class _HorarioBtn extends StatelessWidget {
  final String label;
  final TimeOfDay? hora;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _HorarioBtn({
    required this.label,
    required this.hora,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final preenchido = hora != null;
    final horaStr = preenchido
        ? '${hora!.hour.toString().padLeft(2, '0')}:${hora!.minute.toString().padLeft(2, '0')}'
        : label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: preenchido
                ? AppColors.cyan.withOpacity(0.5)
                : const Color(0xFF1E293B),
            width: preenchido ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time,
                size: 16,
                color:
                    preenchido ? AppColors.cyan : AppColors.textDim),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                horaStr,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight:
                      preenchido ? FontWeight.w600 : FontWeight.w400,
                  color:
                      preenchido ? AppColors.cyan : AppColors.textDim,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.textDim),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Icon(icon, color: AppColors.textMid, size: 18),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color color;
  final String label;
  const _Legenda({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppColors.textDim,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AgendaTile extends StatelessWidget {
  final Servico servico;
  final Color Function(StatusServico) corStatus;
  const _AgendaTile({required this.servico, required this.corStatus});

  @override
  Widget build(BuildContext context) {
    final color = corStatus(servico.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${servico.data.day.toString().padLeft(2, '0')}\n'
                '${['', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'][servico.data.month]}',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(servico.tomadorNome,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(servico.tipo.label,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppColors.textDim)),
                    if (servico.horarioFormatado != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.access_time,
                          size: 11, color: AppColors.cyan),
                      const SizedBox(width: 2),
                      Text(servico.horarioFormatado!,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.cyan)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                servico.valor > 0
                    ? 'R\$ ${servico.valor.toStringAsFixed(0)}'
                    : 'A definir',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: servico.valor > 0
                        ? AppColors.textMid
                        : AppColors.textDim),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(servico.status.label,
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}