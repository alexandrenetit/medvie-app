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

  /// Valor pré-preenchido (ex.: vindo do simulador). Aplicado em [initState]
  /// no `_valor` e em `_valorAtual` para que gates/preview já reflitam o
  /// valor sem o usuário precisar digitá-lo.
  final double? valorInicial;

  /// Tomador pré-selecionado (ex.: vindo do simulador fiscal). Hidratado em
  /// [initState] via postFrame pra resolver após `OnboardingProvider`
  /// carregar a lista. Só modo criação — modo edição já hidrata de
  /// [servicoInicial].
  final Tomador? tomadorInicial;

  /// Modo edição: pré-popula state de [servicoInicial], oculta toggle
  /// "emitir agora" e preview fiscal, troca label do CTA para
  /// "Salvar alterações" e injeta botão de excluir/cancelar via
  /// [onExcluirOuCancelar]. `false` (default) = modo criação.
  final bool modoEdicao;

  /// Serviço pré-existente (somente `modoEdicao: true`). Usado em
  /// [initState] para hidratar tipo, tomador, valor, data, descrição,
  /// status e horários.
  final Servico? servicoInicial;

  /// Callback do modo edição: recebe o [Servico] atualizado pronto para
  /// `ServicoProvider.atualizarServico`. Não emite NFS-e (regra: edição
  /// não reemite). Pode ser assíncrono.
  final Future<void> Function(Servico atualizado)? onSalvarEdicao;

  /// Callback do modo edição: abre modal "Excluir serviço" (status
  /// pendente) ou "Cancelar NFS-e" (status já emitido). O flow não decide
  /// qual ação tomar — o parent (modal) tem a regra fiscal/regatória.
  /// Pode ser assíncrono.
  final Future<void> Function()? onExcluirOuCancelar;

  // Tipos disponíveis para o ramo CNPJ (empresa / convênio).
  // Códigos NBS residem em `TipoServico.codigoNbs` (`servico.dart:52`) —
  // ver §10 do plano (validação oficial pendente; decisão humana externa).
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
    this.valorInicial,
    this.tomadorInicial,
    this.modoEdicao = false,
    this.servicoInicial,
    this.onSalvarEdicao,
    this.onExcluirOuCancelar,
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

  // Toggle pré-submit "Emitir NFS-e agora?" (espelha protótipo v15).
  // Se true, _confirmar pula o sheet pós-salvar e emite direto.
  bool _emitirAgora = false;

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
    if (widget.valorInicial != null) {
      _valor.text = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
      ).format(widget.valorInicial);
      _valorAtual = widget.valorInicial!;
      // Valor pré-preenchido (ex.: simulador fiscal) não passa pelo onChanged
      // do campo, então dispara o preview fiscal aqui. postFrame: precisa do
      // ServicoProvider no contexto (igual à resolução do tomador).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_recalcularPreview());
      });
    }
    if (widget.modoEdicao && widget.servicoInicial != null) {
      _hidratarEdicao(widget.servicoInicial!);
    } else if (widget.tomadorInicial != null &&
        widget.tomadorInicial!.tipo == TipoTomador.cnpj) {
      // Pré-seleção vinda do parent (ex.: simulador fiscal). Mesmo padrão
      // de _hidratarEdicao: postFrame para resolver após
      // OnboardingProvider carregar a lista de tomadores. Empresa/Convênio é
      // exclusivo CNPJ — descarta tomadorInicial se for PF (feature 017).
      final t = widget.tomadorInicial!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _tomadorSelecionado = t);
      });
    }
  }

  /// Hidrata o state a partir de um [Servico] pré-existente (modo edição).
  /// Tomador é resolvido após o primeiro frame (precisa do
  /// [OnboardingProvider] no contexto).
  void _hidratarEdicao(Servico s) {
    _tipoServico = s.tipo;
    _descricao.text = s.observacao.isNotEmpty
        ? s.observacao
        : s.discriminacaoPadrao;
    _statusPagto = s.status;
    _competencia = s.data;
    if (s.valor > 0) {
      _valor.text = NumberFormat.currency(
        locale: 'pt_BR',
        symbol: '',
      ).format(s.valor);
      _valorAtual = s.valor;
    }
    if (s.tipo == TipoServico.plantao) {
      _horaInicio = s.horaInicio;
      _horaFim = s.horaFim;
    }
    final id = s.tomadorId;
    final cnpj = s.tomadorCnpj;
    if (id == null && cnpj.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Empresa/Convênio é exclusivo CNPJ — ignora match se o tomador do
      // serviço salvo for PF (feature 017).
      final tomadores = context
          .read<OnboardingProvider>()
          .tomadores
          .where((t) => t.tipo == TipoTomador.cnpj);
      Tomador? match;
      for (final t in tomadores) {
        if ((id != null && t.id == id) || t.cnpj == cnpj) {
          match = t;
          break;
        }
      }
      if (match != null) {
        setState(() => _tomadorSelecionado = match);
      }
    });
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

  /// Gate do toggle "Emitir NFS-e agora?": tomador escolhido + valor > 0.
  /// Sem isso, toggle fica desabilitado e hint pede seleção (v15).
  bool get _podeEmitir => _tomadorSelecionado != null && _valorAtual > 0;

  void _alternarEmitir() {
    if (!_podeEmitir) return; // gate: sem estado, toggle não liga
    setState(() => _emitirAgora = !_emitirAgora);
  }

  String get _hintEmitir {
    if (!_podeEmitir) return 'Selecione tomador e valor para emitir';
    return _emitirAgora
        ? 'Tomador e valor prontos — será emitida'
        : 'Fica salva para emitir depois';
  }


  // ─── Tomador ─────────────────────────────────────────────────────────────

  Future<void> _abrirSeletorTomador() async {
    if (!mounted) return;
    // Filtra tomadores CNPJ — feature 017 (PF) não se aplica ao ramo
    // Empresa/Convênio. Fonte: TipoTomador em core/models/medico.dart.
    final tomadoresCnpj = context
        .read<OnboardingProvider>()
        .tomadores
        .where((t) => t.tipo == TipoTomador.cnpj)
        .toList(growable: false);
    final resultado = await showTomadorSelectorSheet(
      context: context,
      tomadores: tomadoresCnpj,
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

    // ─── Modo edição: monta Servico atualizado e delega ao parent ─────
    if (widget.modoEdicao) {
      if (widget.onSalvarEdicao == null) {
        _erro('Modo edição sem handler de salvar.');
        return;
      }
      final ehPlantao = _tipoServico == TipoServico.plantao;
      final atualizado = widget.servicoInicial!.copyWith(
        tipo: _tipoServico,
        data: _competencia,
        tomadorId: _tomadorSelecionado!.id,
        tomadorCnpj: _tomadorSelecionado!.cnpj,
        tomadorNome: _tomadorSelecionado!.razaoSocial,
        valor: _valorNumerico,
        status: _statusPagto,
        observacao: _descricao.text.trim().isEmpty
            ? widget.servicoInicial!.discriminacaoPadrao
            : _descricao.text.trim(),
        horaInicio: ehPlantao ? _horaInicio : null,
        horaFim: ehPlantao ? _horaFim : null,
        clearHoraInicio: !ehPlantao,
        clearHoraFim: !ehPlantao,
      );
      widget.onSalvarEdicao!(atualizado);
      widget.onConcluido();
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
      if (_emitirAgora) {
        // Toggle on: usuário já decidiu emitir agora. Pula o sheet
        // pós-salvar e chama `emitirNf` direto.
        await _emitirDireto(servico.id, servicoProvider, notaProvider);
      } else {
        await _finalizarPosSalvar(servico.id, servicoProvider, notaProvider);
      }
    } on ApiException catch (e) {
      _erro(e.error.description ?? 'Não foi possível salvar o atendimento.');
    } catch (_) {
      _erro('Não foi possível salvar o atendimento.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _emitirDireto(
    String servicoId,
    ServicoProvider servicoProvider,
    NotaFiscalProvider notaProvider,
  ) async {
    // Toggle "Emitir agora" ligado: pula sheet pós-salvar, emite direto.
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
      // T8.2: feedback de sucesso ao "deixar para depois". Sem isso o modal
      // fechava silencioso e o usuário podia achar que nada foi salvo.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.green,
          content: Text('Serviço salvo. Emita a NFS-e depois em Notas.'),
        ),
      );
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
        // Empty state antecipatório (T3.4): médico sem NENHUM tomador
        // cadastrado não precisa do TomadorResumoCard pedindo pra escolher
        // (não há o que escolher). CTA direta abre o sheet em modo cadastro
        // inline — fluxo de 1 tap em vez de 3.
        if (tomadores.isEmpty)
          _SemTomadoresCard(onCadastrar: () => unawaited(_abrirSeletorTomador()))
        else
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
        const SizedBox(height: 12),
        // Toggle "emitir agora" e preview fiscal: só no modo criação.
        // No modo edição, a NFS-e já foi tratada antes (ou não cabe).
        if (!widget.modoEdicao) ...[
          _emitirToggleRow(),
          const SizedBox(height: 16),
          PreviewFiscalCnpjCard(
            bruto: _valorAtual,
            retemIss: _tomadorSelecionado?.retemIss ?? false,
            // Cadastro sem declaração de IRRF cai no default legal exibido — um
            // tomador recém-cadastrado inline chega aqui como "não informado", e
            // "não retém" seria falso (F-04 / D9).
            retemIrrf: _tomadorSelecionado?.retemIrrfExibicao ?? false,
            ibs: _ibs,
            cbs: _cbs,
            liquido: _liquido,
            backendCalculado: _backendCalculado,
            prontoParaEmitir: _emitirAgora && _backendCalculado,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: ValueKey(
              widget.modoEdicao ? 'cnpj-cta-salvar' : 'cnpj-cta-registrar',
            ),
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
                    widget.modoEdicao
                        ? 'Salvar alterações'
                        : (_emitirAgora
                            ? 'Confirmar e emitir NFS-e'
                            : 'Registrar serviço'),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        // T8.2: helper text do CTA quando gates não passam. Informa o usuário
        // o que falta para liberar o botão (espelha o hint do toggle emitir).
        // Copy menciona "cadastrar" (não só "selecionar") quando não há tomador
        // — coerente com o card antecipatório _SemTomadoresCard acima.
        if (_tomadorSelecionado == null || _valorAtual <= 0) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Cadastre ou selecione um tomador para continuar',
              key: const ValueKey('cnpj-cta-helper'),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textFaint,
              ),
            ),
          ),
        ],
        // Modo edição: botão excluir/cancelar (parent decide qual ação).
        if (widget.modoEdicao && widget.onExcluirOuCancelar != null) ...[
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF1e2433)),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const ValueKey('cnpj-editar-excluir'),
              onPressed: _salvando
                  ? null
                  : () => unawaited(widget.onExcluirOuCancelar!()),
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFEF4444)),
              label: Text(
                'Excluir / Cancelar',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ),
          ),
        ],
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
    return Semantics(
      container: true,
      label: 'Tipo de serviço',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: AtendimentoCnpjFlow.tiposCnpj.map((t) {
          final sel = t == _tipoServico;
          return Semantics(
            button: true,
            inMutuallyExclusiveGroup: true,
            selected: sel,
            label: t.label,
            child: Material(
              color: sel
                  ? AppColors.green.withValues(alpha: 0.10)
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
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
              ),
            ),
          );
        }).toList(),
      ),
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
    return Semantics(
      container: true,
      label: 'Status do pagamento',
      child: Row(
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
      ),
    );
  }

  // Toggle "Emitir NFS-e agora?" (espelha protótipo v15 linha 698-700).
  // Habilitado só com tomador + valor > 0. Hint dinâmico em 3 estados.
  Widget _emitirToggleRow() {
    final habilitado = _podeEmitir;
    final ativo = _emitirAgora && habilitado;
    return Semantics(
      toggled: ativo,
      enabled: habilitado,
      label: 'Emitir NFS-e agora. $_hintEmitir',
      child: InkWell(
        key: const ValueKey('cnpj-toggle-emitir'),
        onTap: habilitado ? _alternarEmitir : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ativo ? AppColors.cyan : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emitir NFS-e agora?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hintEmitir,
                      style: TextStyle(
                        fontSize: 12,
                        color: habilitado
                            ? AppColors.textDim
                            : AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Switch visual (knob deslizante), espelha v15.
              _SwitchKnob(
                ativo: ativo,
                onTap: habilitado ? _alternarEmitir : null,
              ),
            ],
          ),
        ),
      ),
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
    return Semantics(
      button: true,
      label: '$label. $hora',
      child: InkWell(
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
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selecionado,
      label: label,
      child: Material(
        color: selecionado
            ? AppColors.green.withValues(alpha: 0.15)
            : AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
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
        ),
      ),
    );
  }
}

// ─── Switch knob (toggle "Emitir NFS-e agora?") ─────────────────────────────

class _SwitchKnob extends StatelessWidget {
  final bool ativo;
  final VoidCallback? onTap;

  const _SwitchKnob({required this.ativo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('cnpj-toggle-emitir-knob'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ativo
              ? AppColors.cyan
              : AppColors.border.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: ativo ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state: médico sem nenhum tomador cadastrado ──────────────────────

/// Renderizado no lugar do TomadorResumoCard quando OnboardingProvider não tem
/// nenhum tomador. CTA primária abre o sheet de seleção em modo cadastro inline
/// (T3.4) — médico vai direto pro cadastro, sem o passo intermediário "escolher"
/// que não leva a lugar nenhum quando a lista está vazia.
class _SemTomadoresCard extends StatelessWidget {
  final VoidCallback onCadastrar;

  const _SemTomadoresCard({required this.onCadastrar});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('cnpj-sem-tomadores-card'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.cyan.withValues(alpha: 0.06),
        border: Border.all(
          color: AppColors.cyan.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  size: 18,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cadastre seu primeiro tomador',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Para registrar atendimentos como Empresa / Convênio, '
            'adicione o hospital ou clínica que te contratou.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textFaint,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('cnpj-sem-tomadores-cadastrar'),
              onPressed: onCadastrar,
              icon: const Icon(Icons.add, size: 16, color: Colors.black),
              label: Text(
                'Cadastrar tomador',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
