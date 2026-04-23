// lib/features/syncview/widgets/add_servico_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/servico.dart';
import '../../../core/models/medico.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/providers/onboarding_provider.dart';

class AddServicoModal extends StatefulWidget {
  /// Quando fornecido, abre em modo edição pré-populado.
  /// Quando null, abre em modo criação.
  final Servico? servicoInicial;

  const AddServicoModal({super.key, this.servicoInicial});

  bool get modoEdicao => servicoInicial != null;

  @override
  State<AddServicoModal> createState() => _AddServicoModalState();
}

class _AddServicoModalState extends State<AddServicoModal> {
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();

  late DateTime _dataSelecionada;
  late StatusServico _statusSelecionado;
  late TipoServico _tipoSelecionado;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;
  bool _salvando = false;
  bool _carregandoSugestao = false;
  Tomador? _tomadorSelecionado;


  @override
  void initState() {
    super.initState();
    final s = widget.servicoInicial;
    if (s != null) {
      // Modo edição — pré-popula com os dados existentes
      _dataSelecionada = s.data;
      // Status fiscal não é editável pelo médico — mantém o status atual
      // mas expõe apenas planejado/confirmado nos chips (os únicos editáveis)
      _statusSelecionado =
          s.status.foiExecutado ? StatusServico.pago : StatusServico.pendente;
      _tipoSelecionado = s.tipo;
      _horaInicio = s.horaInicio;
      _horaFim = s.horaFim;
      _valorController.text = s.valor > 0 ? s.valor.toStringAsFixed(0) : '';
      _observacaoController.text = s.observacao;
      // _tomadorSelecionado é resolvido no build após carregar a lista de tomadores
    } else {
      // Modo criação — valores padrão; sugestão fiscal carregada assincronamente
      _dataSelecionada = DateTime.now();
      _statusSelecionado = StatusServico.pendente;
      _tipoSelecionado = TipoServico.plantao;
      _carregarSugestao();
    }
  }

  // ─────────────────────────────────────────────
  // Sugestão fiscal (apenas modo criação)
  // ─────────────────────────────────────────────

  Future<void> _carregarSugestao() async {
    final provider = context.read<OnboardingProvider>();
    final medicoId = provider.medicoIdSalvo;
    if (medicoId == null) return;

    setState(() => _carregandoSugestao = true);
    try {
      final sugestao = await provider.api.getSugestaoFiscal(medicoId);
      if (!mounted) return;
      setState(() {
        _tipoSelecionado = _mapearTipoServico(sugestao.tipoServicoDefault);
      });
    } catch (_) {
      // Sugestão é best-effort — falha silenciosa, defaults permanecem
    } finally {
      if (mounted) setState(() => _carregandoSugestao = false);
    }
  }

  /// Mapeia o nome do enum backend para o enum Flutter.
  static TipoServico _mapearTipoServico(String backendName) =>
      switch (backendName) {
        'PlantaoClinico'          => TipoServico.plantao,
        'AtoAnestesico'           => TipoServico.atoAnestesico,
        'LaudoImagem'             => TipoServico.laudo,
        'ProcedimentoEndoscopico' => TipoServico.procedimentoCirurgico,
        'Consulta'                => TipoServico.consulta,
        'AtoCirurgico'            => TipoServico.procedimentoCirurgico,
        'MedicinaTrabalho'        => TipoServico.outros,
        _                         => TipoServico.plantao,
      };

  @override
  void dispose() {
    _valorController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Seleção de data e hora
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  // Salvar
  // ─────────────────────────────────────────────

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
            backgroundColor: AppColors.surface,
          ),
        );
        return;
      }
      valor = parsed;
    }

    setState(() => _salvando = true);

    final provider = context.read<ServicoProvider>();

    if (widget.modoEdicao) {
      // Modo edição — atualiza o serviço existente preservando o id e o
      // status fiscal (nfEmitida, nfRejeitada, etc.) que não são editáveis aqui.
      final atualizado = widget.servicoInicial!.copyWith(
        tipo: _tipoSelecionado,
        data: _dataSelecionada,
        tomadorCnpj: _tomadorSelecionado!.cnpj,
        tomadorNome: _tomadorSelecionado!.razaoSocial,
        valor: valor,
        status: _statusSelecionado,
        observacao: _observacaoController.text.trim(),
        horaInicio: _horaInicio,
        horaFim: _horaFim,
        clearHoraInicio: _horaInicio == null,
        clearHoraFim: _horaFim == null,
      );
      await provider.atualizarServico(atualizado);
    } else {
      // Modo criação
      final onboarding = context.read<OnboardingProvider>();
      final cnpj = onboarding.medico?.cnpjs.firstOrNull?.cnpj;
      final cnpjProprioId = cnpj != null
          ? onboarding.cnpjProprioIdsPorCnpj[cnpj]
          : null;

      await provider.adicionarServico(
        tipo: _tipoSelecionado,
        data: _dataSelecionada,
        tomadorCnpj: _tomadorSelecionado!.cnpj,
        tomadorNome: _tomadorSelecionado!.razaoSocial,
        valor: valor,
        status: _statusSelecionado,
        observacao: _observacaoController.text.trim(),
        horaInicio: _horaInicio,
        horaFim: _horaFim,
        cnpjProprioId: cnpjProprioId,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onboardingProvider = context.watch<OnboardingProvider>();
    final tomadores = onboardingProvider.medico?.todosTomadores ??
        onboardingProvider.tomadores;

    // Modo edição: resolve o tomador selecionado na primeira renderização
    if (widget.modoEdicao && _tomadorSelecionado == null) {
      final s = widget.servicoInicial!;
      try {
        _tomadorSelecionado = tomadores.firstWhere(
          (t) => t.cnpj == s.tomadorCnpj,
        );
      } catch (_) {
        // Tomador não encontrado na lista atual — mantém null
        // O médico precisará selecionar novamente
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            const SizedBox(height: 20),

            // Título muda conforme o modo
            Row(
              children: [
                Text(
                  widget.modoEdicao ? 'Editar serviço' : '+ Serviço',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (widget.modoEdicao) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Antes de emitir',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Tipo de serviço
            Row(children: [
              _buildLabel('Tipo de serviço'),
              if (_carregandoSugestao) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10, height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.cyan)),
              ],
            ]),
            const SizedBox(height: 8),
            _buildDropdownTipo(),
            const SizedBox(height: 16),

            // Tomador
            _buildLabel('Hospital / Clínica'),
            const SizedBox(height: 8),
            tomadores.isEmpty
                ? _buildSemTomadores()
                : _buildDropdownTomadores(tomadores),
            const SizedBox(height: 16),

            // Valor + Data
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
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
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF1E293B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 16, color: AppColors.textDim),
                              const SizedBox(width: 8),
                              Text(
                                '${_dataSelecionada.day.toString().padLeft(2, '0')}/'
                                '${_dataSelecionada.month.toString().padLeft(2, '0')}',
                                style: GoogleFonts.outfit(
                                    fontSize: 14, color: AppColors.text),
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

            // Horários
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

            // Status — apenas planejado/confirmado são editáveis pelo médico
            _buildLabel('Status'),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip(
                    StatusServico.pendente, 'Pendente', AppColors.amber),
                const SizedBox(width: 8),
                _buildStatusChip(
                    StatusServico.pago, 'Pago', AppColors.green),
              ],
            ),
            const SizedBox(height: 16),

            // Observação
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
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        widget.modoEdicao
                            ? 'Salvar alterações'
                            : 'Salvar serviço',
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _buildDropdownTipo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TipoServico>(
          value: _tipoSelecionado,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          items: TipoServico.values.map((tipo) {
            return DropdownMenuItem<TipoServico>(
              value: tipo,
              child: Row(
                children: [
                  Text(tipo.icone, style: const TextStyle(fontSize: 16)),
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
          onChanged: (tipo) {
            if (tipo != null) setState(() => _tipoSelecionado = tipo);
          },
        ),
      ),
    );
  }

  Widget _buildDropdownTomadores(List<Tomador> tomadores) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Tomador>(
          value: _tomadorSelecionado,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          hint: Text(
            'Selecione o hospital / clínica',
            style:
                GoogleFonts.outfit(fontSize: 14, color: AppColors.textDim),
          ),
          items: tomadores.map((t) {
            return DropdownMenuItem<Tomador>(
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
                        fontSize: 11, color: AppColors.textDim),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (t) {
            setState(() {
              _tomadorSelecionado = t;
              if (t != null && t.valorPadrao > 0) {
                _valorController.text = t.valorPadrao.toStringAsFixed(0);
              } else {
                _valorController.clear();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildSemTomadores() {
    return Container(
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
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textDim,
        ),
      );

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.textDim.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: GoogleFonts.outfit(
                fontSize: 9,
                color: AppColors.textDim,
                fontWeight: FontWeight.w500)),
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

  Widget _buildStatusChip(
      StatusServico status, String label, Color color) {
    final selected = _statusSelecionado == status;
    return GestureDetector(
      onTap: () => setState(() => _statusSelecionado = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.bg,
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

// ─── Widget de botão de horário (compartilhado com agenda_screen) ─────────

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
                ? AppColors.cyan.withValues(alpha: 0.5)
                : const Color(0xFF1E293B),
            width: preenchido ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time,
                size: 16,
                color: preenchido ? AppColors.cyan : AppColors.textDim),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                horaStr,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight:
                      preenchido ? FontWeight.w600 : FontWeight.w400,
                  color: preenchido ? AppColors.cyan : AppColors.textDim,
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