// lib/features/syncview/widgets/atendimento_cnpj_flow.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/models/medico.dart';
import '../../../core/models/servico.dart';
import '../../../core/providers/nota_fiscal_provider.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../notas/widgets/emissao_confirmacao_sheet.dart';
import 'preview_fiscal_cnpj_card.dart';
import 'tomador_selector_sheet.dart';

/// Fluxo de captura de atendimento Empresa/Convênio (ramo CNPJ).
///
/// Orquestra [TomadorResumoCard] + seleção de serviço + valor + horário
/// (condicional Plantão) + data/descrição + status pagamento + preview fiscal
/// live ([PreviewFiscalCnpjCard]). Ao salvar, chama
/// [ServicoProvider.confirmarAtendimentoCnpj] e abre o sheet pós-salvar
/// ([EmissaoConfirmacaoSheet.showPosSalvar]).
class AtendimentoCnpjFlow extends StatefulWidget {
  /// Guid do CNPJ próprio do médico.
  final String cnpjProprioId;

  /// CNPJ emissor (somente dígitos) — usado na emissão via `POST /notas`.
  final String cnpjEmissor;

  /// Chamado após salvar/emitir com sucesso (fecha o modal).
  final VoidCallback onConcluido;

  // Tipos disponíveis para o ramo CNPJ (empresa / convênio).
  // ⚠ NBS são placeholders — confirmar tabela oficial antes de produção (F4.T4.3 §10).
  static const List<TipoServico> tiposCnpj = [
    TipoServico.plantao,
    TipoServico.procedimentoCirurgico,
    TipoServico.atoAnestesico,
    TipoServico.outros,
  ];

  const AtendimentoCnpjFlow({
    super.key,
    required this.cnpjProprioId,
    required this.cnpjEmissor,
    required this.onConcluido,
  });

  @override
  State<AtendimentoCnpjFlow> createState() => _AtendimentoCnpjFlowState();
}

class _AtendimentoCnpjFlowState extends State<AtendimentoCnpjFlow> {
  final _valor = TextEditingController();
  final _descricao = TextEditingController();

  Tomador? _tomadorSelecionado;
  TipoServico _tipoServico = TipoServico.plantao;
  DateTime _competencia = DateTime.now();
  double _valorAtual = 0;
  bool _salvando = false;

  // pendente = "A receber"; pago = "Já recebi".
  StatusServico _statusPagto = StatusServico.pendente;

  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;

  // Preview fiscal live (debounce 400ms → backend).
  // ISS/IRRF vêm do Tomador (cadastro); IBS/CBS/líquido vêm do backend
  // (`previewFiscalAtendimento`). A UI nunca infere alíquota local.
  Timer? _previewDebounce;
  double _ibs = 0;
  double _cbs = 0;
  double _liquido = 0;
  bool _backendCalculado = false;

  @override
  void initState() {
    super.initState();
    _descricao.text = _tipoServico.label;
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  // ─── Preview fiscal (debounce + backend) ────────────────────────────────

  void _agendarPreview() {
    _previewDebounce?.cancel();
    if (_valorNumerico <= 0) {
      setState(() {
        _ibs = 0;
        _cbs = 0;
        _liquido = 0;
        _backendCalculado = false;
      });
      return;
    }
    _previewDebounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_recalcularPreview()),
    );
  }

  Future<void> _recalcularPreview() async {
    if (!mounted) return;
    final valor = _valorNumerico;
    if (valor <= 0) return;
    try {
      final preview = await context
          .read<ServicoProvider>()
          .previewFiscalAtendimento(
            cnpjProprioId: widget.cnpjProprioId,
            valor: valor,
            competencia: _competencia,
          );
      if (!mounted) return;
      if (_valorNumerico != valor) return; // valor mudou durante o await
      setState(() {
        _ibs = preview.ibs;
        _cbs = preview.cbs;
        _liquido = preview.liquidoEstimado;
        _backendCalculado = true;
      });
    } catch (_) {
      // Falha de rede: preserva o último preview válido.
    }
  }

  // ─── Valor ──────────────────────────────────────────────────────────────

  double get _valorNumerico {
    final raw = _valor.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }


  // ─── Tomador ─────────────────────────────────────────────────────────────

  Future<void> _abrirSeletorTomador() async {
    if (!mounted) return;
    final tomadores = context.read<OnboardingProvider>().tomadores;
    final resultado = await showTomadorSelectorSheet(
      context: context,
      tomadores: tomadores,
      selecionadoId: _tomadorSelecionado?.id,
      onResolverCnpj: (cnpj) async {
        try {
          return await context
              .read<ServicoProvider>()
              .buscarTomadorPorCnpj(cnpj);
        } catch (_) {
          return null;
        }
      },
      onSalvarTomador: (tomador) async {
        if (!mounted) return null;
        final servicoProvider = context.read<ServicoProvider>();
        final onboardingProvider = context.read<OnboardingProvider>();
        try {
          final persistido = await servicoProvider.criarTomadorCnpj(
            cnpjProprioId: widget.cnpjProprioId,
            tomador: tomador,
          );
          onboardingProvider.adicionarTomadorEmMemoria(persistido);
          return persistido;
        } catch (_) {
          return null;
        }
      },
    );
    if (!mounted) return;
    if (resultado != null) {
      setState(() => _tomadorSelecionado = resultado);
    }
  }

  // ─── Horário (Plantão) ───────────────────────────────────────────────────

  Future<void> _selecionarHora({required bool inicio}) async {
    final inicial = inicio
        ? (_horaInicio ?? const TimeOfDay(hour: 7, minute: 0))
        : (_horaFim ?? const TimeOfDay(hour: 19, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: inicial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.green,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (inicio) {
          _horaInicio = picked;
        } else {
          _horaFim = picked;
        }
      });
    }
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _competencia,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _competencia = picked);
      _agendarPreview();
    }
  }

  // ─── Confirmação ──────────────────────────────────────────────────────────

  void _erro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  Future<void> _confirmar() async {
    if (_salvando) return;
    if (_tomadorSelecionado == null) {
      _erro('Selecione o tomador (empresa / convênio).');
      return;
    }
    if (_valorNumerico <= 0) {
      _erro('Informe o valor do atendimento.');
      return;
    }

    setState(() => _salvando = true);
    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();

    try {
      final servico = await servicoProvider.confirmarAtendimentoCnpj(
        cnpjProprioId: widget.cnpjProprioId,
        tomador: _tomadorSelecionado!,
        tipoServico: _tipoServico,
        descricao: _descricao.text.trim().isEmpty
            ? _tipoServico.label
            : _descricao.text.trim(),
        valor: _valorNumerico,
        competencia: _competencia,
        status: _statusPagto,
        horaInicio: _tipoServico == TipoServico.plantao ? _horaInicio : null,
        horaFim: _tipoServico == TipoServico.plantao ? _horaFim : null,
      );
      if (!mounted) return;
      setState(() => _salvando = false);
      await _finalizarPosSalvar(servico.id, servicoProvider, notaProvider);
    } on ApiException catch (e) {
      _erro(e.error.description ?? 'Não foi possível salvar o atendimento.');
    } catch (_) {
      _erro('Não foi possível salvar o atendimento.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _finalizarPosSalvar(
    String servicoId,
    ServicoProvider servicoProvider,
    NotaFiscalProvider notaProvider,
  ) async {
    Servico? servico;
    for (final s in servicoProvider.servicos) {
      if (s.id == servicoId) {
        servico = s;
        break;
      }
    }
    if (servico == null) {
      widget.onConcluido();
      return;
    }

    final emitirAgora =
        await EmissaoConfirmacaoSheet.showPosSalvar(context, servico);
    if (!mounted) return;
    if (!emitirAgora) {
      widget.onConcluido();
      return;
    }

    try {
      await servicoProvider.emitirNf(
        servicoId,
        notaProvider,
        widget.cnpjEmissor,
        cnpjProprioGuidParaReload: widget.cnpjProprioId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.green,
          content: Text('Nota enviada para processamento ✓'),
        ),
      );
    } catch (_) {
      _erro('Falha ao emitir a NFS-e. Tente novamente em Notas.');
    } finally {
      widget.onConcluido();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tomadores = context.watch<OnboardingProvider>().tomadores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TomadorResumoCard(
          selecionado: _tomadorSelecionado,
          totalCadastrados: tomadores.length,
          onTrocar: () => unawaited(_abrirSeletorTomador()),
        ),
        const SizedBox(height: 18),
        _label('Tipo de serviço'),
        const SizedBox(height: 8),
        _seletorServico(),
        const SizedBox(height: 18),
        _label('Valor do atendimento'),
        const SizedBox(height: 8),
        _campoValor(),
        const SizedBox(height: 16),
        if (_tipoServico == TipoServico.plantao) ...[
          _linhaHorario(),
          const SizedBox(height: 12),
        ],
        _linhaDataDescricao(),
        _statusPagamento(),
        PreviewFiscalCnpjCard(
          bruto: _valorAtual,
          retemIss: _tomadorSelecionado?.retemIss ?? false,
          retemIrrf: _tomadorSelecionado?.retemIrrf ?? false,
          ibs: _ibs,
          cbs: _cbs,
          liquido: _liquido,
          backendCalculado: _backendCalculado,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('cnpj-cta-registrar'),
            onPressed: (_salvando ||
                    _tomadorSelecionado == null ||
                    _valorAtual <= 0)
                ? null
                : () => unawaited(_confirmar()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _salvando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    'Registrar serviço',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ─── Helpers de UI ────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDim,
        ),
      );

  Widget _seletorServico() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AtendimentoCnpjFlow.tiposCnpj.map((t) {
        final sel = t == _tipoServico;
        return GestureDetector(
          key: ValueKey('cnpj-servico-${t.name}'),
          onTap: () => setState(() {
            final labelAnterior = _tipoServico.label;
            _tipoServico = t;
            // Atualiza descrição apenas se estava no valor padrão anterior.
            if (_descricao.text.trim() == labelAnterior ||
                _descricao.text.trim().isEmpty) {
              _descricao.text = t.label;
            }
            // Limpa horários ao sair do tipo Plantão.
            if (t != TipoServico.plantao) {
              _horaInicio = null;
              _horaFim = null;
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.green.withValues(alpha: 0.10)
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel
                    ? AppColors.green.withValues(alpha: 0.45)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.icone, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.green : AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _campoValor() {
    return TextField(
      key: const ValueKey('cnpj-valor'),
      controller: _valor,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [CurrencyInputFormatter()],
      onChanged: (_) {
        setState(() => _valorAtual = _valorNumerico);
        _agendarPreview();
      },
      style: GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        isDense: true,
        prefixText: 'R\$ ',
        prefixStyle: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          color: AppColors.textDim,
        ),
        hintText: '0,00',
        hintStyle: const TextStyle(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green),
        ),
      ),
    );
  }

  Widget _linhaHorario() {
    String fmt(TimeOfDay? t) => t == null
        ? '--:--'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Expanded(
          child: _HorarioBtn(
            label: 'Início',
            hora: fmt(_horaInicio),
            onTap: () => unawaited(_selecionarHora(inicio: true)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HorarioBtn(
            label: 'Fim',
            hora: fmt(_horaFim),
            onTap: () => unawaited(_selecionarHora(inicio: false)),
          ),
        ),
      ],
    );
  }

  Widget _linhaDataDescricao() {
    final fmtData = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => unawaited(_selecionarData()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data: ${fmtData.format(_competencia)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textDim),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descricao,
          maxLines: 2,
          minLines: 1,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Descrição da NFS-e',
            labelStyle: const TextStyle(color: AppColors.textDim),
            filled: true,
            fillColor: AppColors.bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _statusPagamento() {
    return Row(
      children: [
        _ChipStatus(
          key: const ValueKey('cnpj-status-pendente'),
          label: 'A receber',
          selecionado: _statusPagto == StatusServico.pendente,
          onTap: () => setState(() => _statusPagto = StatusServico.pendente),
        ),
        const SizedBox(width: 8),
        _ChipStatus(
          key: const ValueKey('cnpj-status-pago'),
          label: 'Já recebi',
          selecionado: _statusPagto == StatusServico.pago,
          onTap: () => setState(() => _statusPagto = StatusServico.pago),
        ),
      ],
    );
  }
}

// ─── Botão de horário ─────────────────────────────────────────────────────────

class _HorarioBtn extends StatelessWidget {
  final String label;
  final String hora;
  final VoidCallback onTap;

  const _HorarioBtn({
    required this.label,
    required this.hora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textDim),
            ),
            Text(
              hora,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chip de status pagamento ─────────────────────────────────────────────────

class _ChipStatus extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipStatus({
    super.key,
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.green.withValues(alpha: 0.15)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado
                ? AppColors.green.withValues(alpha: 0.55)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selecionado ? AppColors.green : AppColors.textMid,
          ),
        ),
      ),
    );
  }
}
