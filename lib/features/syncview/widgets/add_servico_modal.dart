// lib/features/syncview/widgets/add_servico_modal.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/servico.dart';
import '../../../core/models/medico.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/providers/onboarding_provider.dart';
import 'atendimento_cnpj_flow.dart';
import 'atendimento_pf_flow.dart';

class AddServicoModal extends StatefulWidget {
  /// Quando fornecido, abre em modo edição pré-populado.
  /// Quando null, abre em modo criação.
  final Servico? servicoInicial;
  final double? valorInicial;
  final Tomador? tomadorInicial;

  const AddServicoModal({
    super.key,
    this.servicoInicial,
    this.valorInicial,
    this.tomadorInicial,
  });

  bool get modoEdicao => servicoInicial != null;

  @override
  State<AddServicoModal> createState() => _AddServicoModalState();
}

class _AddServicoModalState extends State<AddServicoModal> {
  bool _salvando = false;

  /// Segmento PF (true) vs Empresa/Convênio CNPJ (false). PF é o padrão no
  /// modo criação (feature 017); edição mantém o fluxo CNPJ existente.
  /// Sobrescrito para `false` quando o parent passa [widget.tomadorInicial]
  /// (ex.: simulador fiscal) — o tomador é CNPJ, então o segmento PF não
  /// faz sentido.
  bool _segmentoPf = true;


  @override
  void initState() {
    super.initState();
    if (widget.tomadorInicial != null) {
      _segmentoPf = false;
    }
    // State do modal é inerte — a UI de criação/edição é delegada ao
    // AtendimentoCnpjFlow/AtendimentoPfFlow (F4/T7.1). [widget.valorInicial]
    // e [widget.tomadorInicial] são propagados direto no build.
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Excluir / Cancelar
  // ─────────────────────────────────────────────

  Future<void> _excluirOuCancelar() async {
    final servico = widget.servicoInicial!;
    final isPendente = servico.status == StatusServico.pendente;
    final titulo = isPendente ? 'Excluir serviço?' : 'Cancelar NFS-e?';
    final descricao = isPendente
        ? 'O serviço será removido permanentemente. Esta ação não pode ser desfeita.'
        : 'A NFS-e será cancelada junto à prefeitura. Esta ação não pode ser desfeita.';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          titulo,
          style: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          descricao,
          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Voltar',
                style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isPendente ? 'Excluir' : 'Cancelar NFS-e',
              style: GoogleFonts.outfit(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final onboarding = context.read<OnboardingProvider>();
    final cnpjProprioId = onboarding.cnpjProprioIdsPorCnpj.values.firstOrNull ?? '';

    if (cnpjProprioId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sessão expirada. Feche e abra o app novamente.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
      setState(() => _salvando = false);
      return;
    }

    setState(() => _salvando = true);
    try {
      await context
          .read<ServicoProvider>()
          .excluirServico(servico.id, cnpjProprioId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('Erro ao excluir: $e',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ─────────────────────────────────────────────
  // Salvar (modo edição via AtendimentoCnpjFlow)
  // ─────────────────────────────────────────────

  /// Callback do [AtendimentoCnpjFlow] em `modoEdicao: true`. Recebe o
  /// [Servico] já montado pelo flow (com tipo, valor, status, horários
  /// atualizados) e persiste via [ServicoProvider.atualizarServico].
  /// Mantém o id e o status fiscal (nfEmitida, nfRejeitada, etc.).
  Future<void> _salvarEdicaoCnpj(Servico atualizado) async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await context.read<ServicoProvider>().atualizarServico(atualizado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.green,
          content: Text('Serviço atualizado ✓'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text('Erro ao atualizar: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final onboardingProvider = context.watch<OnboardingProvider>();

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

            // Título muda conforme o modo. Botão fechar à direita (mesmo
            // idioma visual do _SheetHead.onClose do tomador_selector_sheet):
            // rota modal exige saída explícita — gesture de swipe-down é pouco
            // descobrível em landscape/desktop.
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.modoEdicao ? 'Editar serviço' : '+ Serviço',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                if (widget.modoEdicao) ...[
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
                  const SizedBox(width: 8),
                ],
                Semantics(
                  button: true,
                  label: 'Fechar',
                  child: Material(
                    color: AppColors.text.withValues(alpha: 0.05),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (mounted) Navigator.of(context).pop();
                      },
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textDim,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (!widget.modoEdicao) ...[
              _buildSegmentoTomador(),
              const SizedBox(height: 20),
            ],
            if (!widget.modoEdicao && _segmentoPf)
              AtendimentoPfFlow(
                cnpjProprioId: _cnpjProprioIdPf(onboardingProvider),
                cnpjEmissor: _cnpjEmissorPf(onboardingProvider),
                onConcluido: () {
                  if (mounted) Navigator.of(context).pop();
                },
              )
            else if (!widget.modoEdicao)
              AtendimentoCnpjFlow(
                cnpjProprioId: _cnpjProprioIdPf(onboardingProvider),
                cnpjEmissor: _cnpjEmissorPf(onboardingProvider),
                onConcluido: () {
                  if (mounted) Navigator.of(context).pop();
                },
                valorInicial: widget.valorInicial,
                tomadorInicial: widget.tomadorInicial,
              )
            else if (widget.modoEdicao)
              AtendimentoCnpjFlow(
                cnpjProprioId: _cnpjProprioIdPf(onboardingProvider),
                cnpjEmissor: _cnpjEmissorPf(onboardingProvider),
                onConcluido: () {
                  if (mounted) Navigator.of(context).pop();
                },
                modoEdicao: true,
                servicoInicial: widget.servicoInicial,
                onSalvarEdicao: _salvarEdicaoCnpj,
                onExcluirOuCancelar: _excluirOuCancelar,
              )
            // (Ramo legado removido em T3.4: o fluxo PF/CNPJ via
            // AtendimentoPfFlow/AtendimentoCnpjFlow acima cobre tanto criação
            // quanto edição. Lógica provada unreachable — else não dispara em
            // nenhum dos 3 ramos anteriores do if/else-if.)

          ],
        ),
      ),
    );
  }

  // ─── Segmento PF / CNPJ (feature 017) ────────────────────────────────────

  Widget _buildSegmentoTomador() {
    Widget botao(String label, bool pf) {
      final ativo = _segmentoPf == pf;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _segmentoPf = pf),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ativo
                  ? AppColors.green.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ativo ? AppColors.text : AppColors.textDim,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          botao('Paciente PF', true),
          const SizedBox(width: 4),
          botao('Empresa / Convênio', false),
        ],
      ),
    );
  }

  /// Guid do CNPJ próprio do médico para o fluxo PF.
  String _cnpjProprioIdPf(OnboardingProvider o) {
    final cnpjs = o.medico?.cnpjs;
    if (cnpjs == null || cnpjs.isEmpty) {
      return o.cnpjProprioIdsPorCnpj.values.firstOrNull ?? '';
    }
    return cnpjs.first.id;
  }

  /// CNPJ emissor (somente dígitos) para o fluxo PF.
  String _cnpjEmissorPf(OnboardingProvider o) {
    final cnpjs = o.medico?.cnpjs;
    if (cnpjs == null || cnpjs.isEmpty) return '';
    return cnpjs.first.cnpj.replaceAll(RegExp(r'\D'), '');
  }
}
