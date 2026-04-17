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
import '../syncview/widgets/add_servico_modal.dart';

class NotasScreen extends StatefulWidget {
  const NotasScreen({super.key});

  @override
  State<NotasScreen> createState() => _NotasScreenState();
}

class _NotasScreenState extends State<NotasScreen> {
  DateTime _mesSelecionado =
      DateTime(DateTime.now().year, DateTime.now().month);
  StatusNota? _filtroStatus;
  bool _processandoLote = false;

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

  Future<void> _emitirUma(String servicoId) async {
    if (_processandoLote) return;
    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();
    final cnpj = _cnpjEmissor(context);

    final ok = await servicoProvider.emitirNf(servicoId, notaProvider, cnpj);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.green : AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          ok
              ? 'NFS-e autorizada com sucesso!'
              : 'Rejeição do ADN — verifique os dados e reenvie.',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _emitirTodas() async {
    if (_processandoLote) return;

    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();
    final cnpj = _cnpjEmissor(context);
    final total = servicoProvider.countPendentesNf;

    if (total == 0) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Emitir em lote',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        content: Text(
          'Deseja emitir NFS-e para todos os $total ${total == 1 ? 'serviço pendente' : 'serviços pendentes'}?',
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: AppColors.textMid,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style:
                  TextStyle(color: AppColors.textDim, fontFamily: 'Outfit'),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Emitir todos',
              style: TextStyle(
                  fontFamily: 'Outfit', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _processandoLote = true);

    final resultado = await servicoProvider.emitirTodasNfsPendentes(
        notaProvider, cnpj);

    if (!mounted) return;
    setState(() => _processandoLote = false);

    final autorizadas = resultado['autorizadas'] ?? 0;
    final rejeitadas = resultado['rejeitadas'] ?? 0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            rejeitadas == 0 ? AppColors.green : AppColors.amber,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        content: Text(
          rejeitadas == 0
              ? '$autorizadas NFS-e${autorizadas > 1 ? 's' : ''} autorizada${autorizadas > 1 ? 's' : ''} com sucesso!'
              : '$autorizadas autorizada${autorizadas > 1 ? 's' : ''} · $rejeitadas rejeitada${rejeitadas > 1 ? 's' : ''} — verifique a aba Notas.',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
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
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.3)),
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
  final Future<void> Function(String) onEmitirUm;
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
          border: Border.all(color: AppColors.amber.withOpacity(0.4)),
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
                  onEmitir: () => onEmitirUm(s.id),
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
                          ? AppColors.amber.withOpacity(0.4)
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
                  color: AppColors.indigo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.indigo.withOpacity(0.3)),
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
                      color: AppColors.cyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.cyan.withOpacity(0.4)),
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
      _FiltroOpcao(label: 'Todas', valor: null, cor: AppColors.textMid),
      _FiltroOpcao(
          label: 'Autorizadas',
          valor: StatusNota.autorizada,
          cor: AppColors.cyan),
      _FiltroOpcao(
          label: 'Em processamento',
          valor: StatusNota.emProcessamento,
          cor: AppColors.indigo),
      _FiltroOpcao(
          label: 'Rejeitadas',
          valor: StatusNota.rejeitada,
          cor: AppColors.red),
      _FiltroOpcao(
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
                    ? f.cor.withOpacity(0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      ativo ? f.cor.withOpacity(0.6) : AppColors.border,
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
                    color: _corStatus.withOpacity(0.12),
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
              color: AppColors.textDim.withOpacity(0.4),
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

  const _DetalheNotaSheet({
    required this.nota,
    required this.valorFormatado,
    required this.dataFormatada,
    required this.cnpjFormatado,
    required this.onReenviar,
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
                  color: _corStatus.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _corStatus.withOpacity(0.4)),
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
                color: AppColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red.withOpacity(0.3)),
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
          _BotoesAcao(nota: nota, onReenviar: onReenviar),
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
  const _BotoesAcao({required this.nota, required this.onReenviar});

  @override
  Widget build(BuildContext context) {
    switch (nota.status) {
      case StatusNota.autorizada:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMid,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text(
                  'Compartilhar',
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Compartilhamento disponível no produto final.',
                        style: TextStyle(fontFamily: 'Outfit'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text(
                  'Ver DANFSe',
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Visualização do DANFSe disponível no produto final.',
                        style: TextStyle(fontFamily: 'Outfit'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
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