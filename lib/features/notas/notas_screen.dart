// lib/features/notas/notas_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/nota_fiscal.dart';
import '../../core/models/servico.dart';
import '../../core/providers/nota_fiscal_provider.dart';
import '../../core/providers/servico_provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/services/medvie_api_service.dart';
import '../../shared/widgets/pdf_viewer_sheet.dart';
import '../syncview/widgets/add_servico_modal.dart';
import 'widgets/emissao_confirmacao_sheet.dart';
import '../../main.dart' show routeObserver;

class NotasScreen extends StatefulWidget {
  const NotasScreen({super.key});

  @override
  State<NotasScreen> createState() => _NotasScreenState();
}

class _NotasScreenState extends State<NotasScreen> with RouteAware {
  DateTime _mesSelecionado =
      DateTime(DateTime.now().year, DateTime.now().month);
  StatusNota? _filtroStatus;
  bool _processandoLote = false;

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotaFiscalProvider>().conectarSse();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    context.read<NotaFiscalProvider>().desconectarSse();
    super.dispose();
  }

  // RouteAware — dispara ao entrar na rota pela primeira vez
  @override
  void didPush() {
    context.read<NotaFiscalProvider>().conectarSse();
    _carregarDados();
  }

  // RouteAware — dispara ao voltar para esta rota (pop de outra)
  @override
  void didPopNext() {
    context.read<NotaFiscalProvider>().conectarSse();
    _carregarDados();
  }

  void _carregarDados() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final medico = context.read<OnboardingProvider>().medico;
      if (medico == null || medico.cnpjs.isEmpty) return;
      final cnpjStr = medico.cnpjs.first.cnpj.replaceAll(RegExp(r'\D'), '');
      final cnpjUuid = medico.cnpjs.first.id;
      context.read<NotaFiscalProvider>().carregar(cnpjStr);
      context.read<ServicoProvider>().carregar(cnpjProprioId: cnpjUuid);
    });
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  String _cnpjEmissor(BuildContext context) {
    final medico = context.read<OnboardingProvider>().medico;
    if (medico == null || medico.cnpjs.isEmpty) return '00000000000000';
    return medico.cnpjs.first.cnpj.replaceAll(RegExp(r'\D'), '');
  }

  String _mesAno(DateTime dt) {
    const meses = [
      '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    return '${meses[dt.month]} ${dt.year}';
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

  String _cnpjFormatado(String cnpj) {
    final d = cnpj.replaceAll(RegExp(r'\D'), '');
    if (d.length != 14) return cnpj;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
        '${d.substring(8, 12)}-${d.substring(12)}';
  }

  void _navegarMes(int delta) {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + delta,
      );
    });
  }

  // ─────────────────────────────────────────────
  // Edição antes de emitir
  // ─────────────────────────────────────────────

  void _abrirEdicao(Servico servico) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddServicoModal(servicoInicial: servico),
    );
  }

  // ─────────────────────────────────────────────
  // Emissão
  // ─────────────────────────────────────────────

  Future<void> _emitirUma(Servico servico) async {
    if (_processandoLote) return;

    final confirmar =
        await EmissaoConfirmacaoSheet.showIndividual(context, servico);
    if (!confirmar || !mounted) return;

    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();
    final cnpj = _cnpjEmissor(context);

    try {
      await servicoProvider.emitirNf(servico.id, notaProvider, cnpj);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Text(
            'Nota enviada para processamento ✓',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            e.toString(),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _emitirTodas() async {
    if (_processandoLote) return;

    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();
    final cnpj = _cnpjEmissor(context);
    final pendentes = servicoProvider.pendentesDEmissao;
    if (pendentes.isEmpty) return;

    final confirmar =
        await EmissaoConfirmacaoSheet.showLote(context, pendentes);

    if (confirmar != true || !mounted) return;

    setState(() => _processandoLote = true);

    try {
      final resultado = await servicoProvider.emitirTodasNfsPendentes(
          notaProvider, cnpj);

      if (!mounted) return;
      final enviadas = (resultado['autorizadas'] ?? 0) + (resultado['rejeitadas'] ?? 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
          content: Text(
            '$enviadas nota${enviadas > 1 ? 's' : ''} enviada${enviadas > 1 ? 's' : ''} para processamento ✓',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            e.toString(),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _processandoLote = false);
    }
  }

  // ─────────────────────────────────────────────
  // Cancelamento de NF
  // ─────────────────────────────────────────────

  Future<void> _confirmarCancelamento(
    BuildContext sheetCtx,
    BuildContext scaffoldCtx,
    NotaFiscal nota,
  ) async {
    final motivoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmar = await showDialog<bool>(
      context: sheetCtx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancelar NFS-e',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: motivoCtrl,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'Outfit', color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Descreva o motivo do cancelamento',
              hintStyle:
                  const TextStyle(fontFamily: 'Outfit', color: AppColors.textDim),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Motivo obrigatório' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text(
              'Voltar',
              style: TextStyle(color: AppColors.textDim, fontFamily: 'Outfit'),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dCtx, true);
              }
            },
            child: const Text(
              'Confirmar cancelamento',
              style:
                  TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!scaffoldCtx.mounted) return;

    final motivo = motivoCtrl.text.trim();
    final cnpjProprioId = _cnpjEmissor(scaffoldCtx);
    final notaProvider = scaffoldCtx.read<NotaFiscalProvider>();

    try {
      if (sheetCtx.mounted) Navigator.pop(sheetCtx); // fecha o bottom sheet
      await notaProvider.cancelar(
            nota.id,
            motivo,
            cnpjProprioId,
          );
      if (!scaffoldCtx.mounted) return;
      ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.textDim,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Text(
            'NFS-e cancelada com sucesso.',
            style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!scaffoldCtx.mounted) return;
      ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Erro ao cancelar: $e',
            style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                color: Colors.white),
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Bottom sheet de detalhe
  // ─────────────────────────────────────────────

void _abrirDetalhe(NotaFiscal nota) {
  final scaffoldContext = context; // ← captura o context do State antes do sheet
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _DetalheNotaSheet(
      nota: nota,
      valorFormatado: _valorFormatado(nota.valor),
      dataFormatada: _dataFormatada(nota.competencia),
      cnpjFormatado: _cnpjFormatado,
      onReenviar: () {
        Navigator.pop(ctx);
        final sp = scaffoldContext.read<ServicoProvider>();
        final np = scaffoldContext.read<NotaFiscalProvider>();
        sp.reenviarNfRejeitada(nota.servicoId, np);
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.amber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            content: const Text(
              'Serviço voltou para a fila. Toque em "Emitir NF" para reenviar.',
              style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
        );
      },
      onCancelar: nota.status == StatusNota.autorizada
          ? () => _confirmarCancelamento(ctx, scaffoldContext, nota)
          : null,
    ),
  );
}

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final servicoProvider = context.watch<ServicoProvider>();
    final notaProvider = context.watch<NotaFiscalProvider>();

    final pendentes = servicoProvider.pendentesDEmissao;
    final notasDoMes = notaProvider.notasDoMes(
        _mesSelecionado.year, _mesSelecionado.month);
    final totalFaturado = notaProvider.totalAutorizadoDoMes(
        _mesSelecionado.year, _mesSelecionado.month);
    final countAutorizadas = notaProvider.countAutorizadasDoMes(
        _mesSelecionado.year, _mesSelecionado.month);

    final notasFiltradas = _filtroStatus == null
        ? notasDoMes
        : notasDoMes.where((n) => n.status == _filtroStatus).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                mesSelecionado: _mesSelecionado,
                mesAno: _mesAno(_mesSelecionado),
                countAutorizadas: countAutorizadas,
                totalFaturado: _valorFormatado(totalFaturado),
                onAnterior: () => _navegarMes(-1),
                onProximo: () => _navegarMes(1),
              ),
            ),
            if (pendentes.isNotEmpty)
              SliverToBoxAdapter(
                child: _SecaoPendentes(
                  pendentes: pendentes,
                  valorFormatado: _valorFormatado,
                  dataFormatada: _dataFormatada,
                  processandoLote: _processandoLote,
                  onEmitirUm: _emitirUma,
                  onEmitirTodos: _emitirTodas,
                  onEditar: _abrirEdicao,
                ),
              ),
            SliverToBoxAdapter(
              child: _FiltrosChip(
                filtroAtual: _filtroStatus,
                onFiltroChanged: (f) => setState(() => _filtroStatus = f),
              ),
            ),
            if (notasFiltradas.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EstadoVazio(temPendentes: pendentes.isNotEmpty),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final nota = notasFiltradas[index];
                      return _CardNota(
                        nota: nota,
                        valorFormatado: _valorFormatado(nota.valor),
                        dataFormatada: _dataFormatada(nota.competencia),
                        onTap: () => _abrirDetalhe(nota),
                      );
                    },
                    childCount: notasFiltradas.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════
// _Header
// ═════════════════════════════════════════════

class _Header extends StatelessWidget {
  final DateTime mesSelecionado;
  final String mesAno;
  final int countAutorizadas;
  final String totalFaturado;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;

  const _Header({
    required this.mesSelecionado,
    required this.mesAno,
    required this.countAutorizadas,
    required this.totalFaturado,
    required this.onAnterior,
    required this.onProximo,
  });

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final isMesAtual = mesSelecionado.year == agora.year &&
        mesSelecionado.month == agora.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Notas Fiscais',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              _BotaoMes(icon: Icons.chevron_left, onTap: onAnterior),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  mesAno,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
              ),
              _BotaoMes(
                icon: Icons.chevron_right,
                onTap: isMesAtual ? null : onProximo,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ChipResumo(
                label:
                    '$countAutorizadas nota${countAutorizadas != 1 ? 's' : ''} emitida${countAutorizadas != 1 ? 's' : ''}',
                cor: AppColors.cyan,
                icone: Icons.check_circle_outline,
              ),
              const SizedBox(width: 10),
              _ChipResumo(
                label: totalFaturado,
                cor: AppColors.green,
                icone: Icons.attach_money,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BotaoMes extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _BotaoMes({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.textDim : AppColors.textMid,
        ),
      ),
    );
  }
}

class _ChipResumo extends StatelessWidget {
  final String label;
  final Color cor;
  final IconData icone;
  const _ChipResumo(
      {required this.label, required this.cor, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// _SecaoPendentes
// ═════════════════════════════════════════════

class _SecaoPendentes extends StatelessWidget {
  final List<Servico> pendentes;
  final String Function(double) valorFormatado;
  final String Function(DateTime) dataFormatada;
  final bool processandoLote;
  final Future<void> Function(Servico) onEmitirUm;
  final Future<void> Function() onEmitirTodos;
  final void Function(Servico) onEditar;

  const _SecaoPendentes({
    required this.pendentes,
    required this.valorFormatado,
    required this.dataFormatada,
    required this.processandoLote,
    required this.onEmitirUm,
    required this.onEmitirTodos,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Prontos para emitir',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber,
                    ),
                  ),
                  const Spacer(),
                  // ✅ plural correto: "1 serviço" / "N serviços"
                  Text(
                    '${pendentes.length} ${pendentes.length == 1 ? 'serviço' : 'serviços'}',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            ...pendentes.map((s) => _ItemPendente(
                  servico: s,
                  valorFormatado: valorFormatado(s.valor),
                  dataFormatada: dataFormatada(s.data),
                  bloqueado: processandoLote,
                  onEmitir: () => onEmitirUm(s),
                  onEditar: () => onEditar(s),
                )),
            if (pendentes.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: processandoLote
                          ? AppColors.amber.withValues(alpha: 0.4)
                          : AppColors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: processandoLote
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(
                      processandoLote
                          ? 'Emitindo...'
                          : 'Emitir todos (${pendentes.length})',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: processandoLote ? null : onEmitirTodos,
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _ItemPendente extends StatefulWidget {
  final Servico servico;
  final String valorFormatado;
  final String dataFormatada;
  final bool bloqueado;
  final Future<void> Function() onEmitir;
  final VoidCallback onEditar;

  const _ItemPendente({
    required this.servico,
    required this.valorFormatado,
    required this.dataFormatada,
    required this.bloqueado,
    required this.onEmitir,
    required this.onEditar,
  });

  @override
  State<_ItemPendente> createState() => _ItemPendenteState();
}

class _ItemPendenteState extends State<_ItemPendente> {
  bool _emitindo = false;

  @override
  Widget build(BuildContext context) {
    final ocupado = _emitindo || widget.bloqueado;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Text(widget.servico.tipo.icone,
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.servico.tomadorNome,
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
                  '${widget.dataFormatada} · ${widget.servico.tipo.label}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 11,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.valorFormatado,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 8),

          // ── Botão editar ──────────────────────
          if (!ocupado)
            GestureDetector(
              onTap: widget.onEditar,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.indigo.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: AppColors.indigo,
                ),
              ),
            ),
          const SizedBox(width: 6),

          // ── Botão emitir / loading ────────────
          ocupado
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cyan,
                  ),
                )
              : GestureDetector(
                  onTap: () async {
                    setState(() => _emitindo = true);
                    await widget.onEmitir();
                    if (mounted) setState(() => _emitindo = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.cyan.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Emitir NF',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// _FiltrosChip
// ═════════════════════════════════════════════

class _FiltrosChip extends StatelessWidget {
  final StatusNota? filtroAtual;
  final ValueChanged<StatusNota?> onFiltroChanged;

  const _FiltrosChip(
      {required this.filtroAtual, required this.onFiltroChanged});

  @override
  Widget build(BuildContext context) {
    final filtros = <_FiltroOpcao>[
      const _FiltroOpcao(label: 'Todas', valor: null, cor: AppColors.textMid),
      const _FiltroOpcao(
          label: 'Autorizadas',
          valor: StatusNota.autorizada,
          cor: AppColors.cyan),
      const _FiltroOpcao(
          label: 'Em processamento',
          valor: StatusNota.emProcessamento,
          cor: AppColors.indigo),
      const _FiltroOpcao(
          label: 'Rejeitadas',
          valor: StatusNota.rejeitada,
          cor: AppColors.red),
      const _FiltroOpcao(
          label: 'Canceladas',
          valor: StatusNota.cancelada,
          cor: AppColors.textDim),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filtros.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filtros[i];
          final ativo = filtroAtual == f.valor;
          return GestureDetector(
            onTap: () => onFiltroChanged(f.valor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ativo
                    ? f.cor.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      ativo ? f.cor.withValues(alpha: 0.6) : AppColors.border,
                ),
              ),
              child: Text(
                f.label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 12,
                  fontWeight:
                      ativo ? FontWeight.w700 : FontWeight.w500,
                  color: ativo ? f.cor : AppColors.textDim,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FiltroOpcao {
  final String label;
  final StatusNota? valor;
  final Color cor;
  const _FiltroOpcao(
      {required this.label, required this.valor, required this.cor});
}

// ═════════════════════════════════════════════
// _CardNota
// ═════════════════════════════════════════════

class _CardNota extends StatelessWidget {
  final NotaFiscal nota;
  final String valorFormatado;
  final String dataFormatada;
  final VoidCallback onTap;

  const _CardNota({
    required this.nota,
    required this.valorFormatado,
    required this.dataFormatada,
    required this.onTap,
  });

  Color get _corStatus {
    switch (nota.status) {
      case StatusNota.autorizada:
        return AppColors.cyan;
      case StatusNota.emProcessamento:
        return AppColors.indigo;
      case StatusNota.rejeitada:
        return AppColors.red;
      case StatusNota.cancelada:
        return AppColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: _corStatus,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nota.tomadorRazaoSocial,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        dataFormatada,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: AppColors.textDim,
                        ),
                      ),
                      if (nota.numeroNota != null) ...[
                        const Text(
                          ' · NF ',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: AppColors.textDim,
                          ),
                        ),
                        Text(
                          nota.numeroNota!,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  valorFormatado,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _corStatus.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    nota.status.label,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _corStatus,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════
// _EstadoVazio
// ═════════════════════════════════════════════

class _EstadoVazio extends StatelessWidget {
  final bool temPendentes;
  const _EstadoVazio({required this.temPendentes});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textDim.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma NFS-e emitida\nneste mês',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDim,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              temPendentes
                  ? 'Emita as NFs dos serviços acima\npara elas aparecerem aqui.'
                  : 'Registre um serviço para começar.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: AppColors.textDim,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════
// _DetalheNotaSheet
// ═════════════════════════════════════════════

class _DetalheNotaSheet extends StatelessWidget {
  final NotaFiscal nota;
  final String valorFormatado;
  final String dataFormatada;
  final String Function(String) cnpjFormatado;
  final VoidCallback onReenviar;
  final VoidCallback? onCancelar;

  const _DetalheNotaSheet({
    required this.nota,
    required this.valorFormatado,
    required this.dataFormatada,
    required this.cnpjFormatado,
    required this.onReenviar,
    this.onCancelar,
  });

  Color get _corStatus {
    switch (nota.status) {
      case StatusNota.autorizada:
        return AppColors.cyan;
      case StatusNota.emProcessamento:
        return AppColors.indigo;
      case StatusNota.rejeitada:
        return AppColors.red;
      case StatusNota.cancelada:
        return AppColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _corStatus.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _corStatus.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _corStatus,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      nota.status.label,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _corStatus,
                      ),
                    ),
                  ],
                ),
              ),
              if (nota.numeroNota != null) ...[
                const Spacer(),
                Text(
                  'NF ${nota.numeroNota}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text(
            valorFormatado,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Competência: $dataFormatada',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          _LinhaDados(label: 'Tomador', valor: nota.tomadorRazaoSocial),
          const SizedBox(height: 10),
          _LinhaDados(
              label: 'CNPJ Tomador',
              valor: cnpjFormatado(nota.tomadorCnpj)),
          const SizedBox(height: 10),
          _LinhaDados(
              label: 'CNPJ Emissor',
              valor: cnpjFormatado(nota.cnpjEmissor)),
          if (nota.chaveAcesso != null) ...[
            const SizedBox(height: 10),
            _LinhaDados(
              label: 'Chave de acesso',
              valor: nota.chaveAcesso!,
              mono: true,
              copiavel: true,
            ),
          ],
          if (nota.status == StatusNota.rejeitada &&
              nota.motivoRejeicao != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nota.motivoRejeicao!,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        color: AppColors.red,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _BotoesAcao(nota: nota, onReenviar: onReenviar, onCancelar: onCancelar),
        ],
      ),
    );
  }
}

class _LinhaDados extends StatelessWidget {
  final String label;
  final String valor;
  final bool mono;
  final bool copiavel;

  const _LinhaDados({
    required this.label,
    required this.valor,
    this.mono = false,
    this.copiavel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: AppColors.textDim,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onLongPress: copiavel
                ? () {
                    Clipboard.setData(ClipboardData(text: valor));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Chave copiada',
                          style: TextStyle(fontFamily: 'Outfit'),
                        ),
                        backgroundColor: AppColors.surface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
            child: Text(
              valor,
              style: TextStyle(
                fontFamily: mono ? 'JetBrainsMono' : 'Outfit',
                fontSize: mono ? 11 : 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMid,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BotoesAcao extends StatelessWidget {
  final NotaFiscal nota;
  final VoidCallback onReenviar;
  final VoidCallback? onCancelar;
  const _BotoesAcao({
    required this.nota,
    required this.onReenviar,
    this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    switch (nota.status) {
      case StatusNota.autorizada:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text(
                  'Baixar Recibo',
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  final api =
                      context.read<NotaFiscalProvider>().api;
                  PdfViewerSheet.abrir(
                    context,
                    titulo: 'Recibo de Serviço',
                    carregar: () => api.baixarPdf(
                      tipo: TipoPdf.reciboServico,
                      referenciaId: nota.servicoId,
                    ),
                  );
                },
              ),
            ),
            if (onCancelar != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text(
                    'Cancelar NF',
                    style: TextStyle(
                        fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                  ),
                  onPressed: onCancelar,
                ),
              ),
            ],
          ],
        );

      case StatusNota.rejeitada:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_outlined, size: 18),
            label: const Text(
              'Corrigir e reenviar',
              style: TextStyle(
                  fontFamily: 'Outfit', fontWeight: FontWeight.w700),
            ),
            onPressed: onReenviar,
          ),
        );

      case StatusNota.emProcessamento:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.indigo,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Aguardando resposta do ADN...',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: AppColors.textDim,
              ),
            ),
          ],
        );

      case StatusNota.cancelada:
        return const SizedBox.shrink();
    }
  }
}
