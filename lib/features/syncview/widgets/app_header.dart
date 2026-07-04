// lib/features/syncview/widgets/app_header.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/certificado_thresholds.dart';
import '../../../core/models/medico.dart' show StatusCertificado;
import '../../../core/providers/certificado_provider.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/providers/nota_fiscal_provider.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../profile/profile_screen.dart';
import '../../syncview/syncview_screen.dart';

class AppHeader extends StatelessWidget {
  /// Acionado ao tocar no pill de status do CNPJ (abre detalhes fiscais).
  /// Ligado pela tela na Fase 4; nulo torna o pill não-clicável.
  final VoidCallback? onCnpjTap;

  /// Competência em foco — vem do estado da tela, nunca do relógio local.
  final DateTime mes;

  /// Navegação de competência: mês anterior, próximo e abertura do seletor.
  final VoidCallback onMesAnterior;
  final VoidCallback onMesProximo;
  final VoidCallback onAbrirSeletor;

  /// Habilita o avanço (`›`): falso no mês corrente — sem competência futura.
  final bool podeAvancar;

  const AppHeader({
    super.key,
    required this.mes,
    required this.onMesAnterior,
    required this.onMesProximo,
    required this.onAbrirSeletor,
    required this.podeAvancar,
    this.onCnpjTap,
  });

  static const List<String> _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  void _abrirDevTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DevToolsSheet(),
    );
  }

  void _abrirPerfil(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final cert = context.watch<CertificadoProvider?>();

    final nomeCompleto = provider.medico?.nome ?? '';
    final nomeLimpo = nomeCompleto
        .replaceAll(RegExp(r'^[Dd][Rr]\.?\s*'), '')
        .trim();
    final nomeExibido = nomeLimpo.isNotEmpty ? 'Dr. $nomeLimpo' : 'Doutor';
    final inicial = nomeLimpo.isNotEmpty ? nomeLimpo[0].toUpperCase() : 'D';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthStepper(
                  label: '${_meses[mes.month - 1]} ${mes.year}',
                  podeAvancar: podeAvancar,
                  onAnterior: onMesAnterior,
                  onProximo: onMesProximo,
                  onAbrirSeletor: onAbrirSeletor,
                ),
                const SizedBox(height: 2),
                Text(
                  nomeExibido,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 19,
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (kDebugMode) ...[_devChip(context), const SizedBox(width: 10)],
          _CnpjPill(state: cert?.state, onTap: onCnpjTap),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _abrirPerfil(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan,
              ),
              child: Center(
                child: Text(
                  inicial,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.bg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devChip(BuildContext context) {
    return GestureDetector(
      onTap: () => _abrirDevTools(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bug_report_outlined,
              color: Colors.orange,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              'DEV',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month Stepper ─────────────────────────────────────────────────────────

/// Navegação de competência no header: `‹ mês ano ›` com rótulo tocável (abre o
/// seletor). O avanço trava no mês corrente — não há competência futura no
/// fiscal. Não deriva mês do relógio: o [label] vem do estado da tela.
class _MonthStepper extends StatelessWidget {
  final String label;
  final bool podeAvancar;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;
  final VoidCallback onAbrirSeletor;

  const _MonthStepper({
    required this.label,
    required this.podeAvancar,
    required this.onAnterior,
    required this.onProximo,
    required this.onAbrirSeletor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _seta(Icons.chevron_left, AppColors.textMid, onAnterior),
        GestureDetector(
          onTap: onAbrirSeletor,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.expand_more,
                  size: 15,
                  color: AppColors.textDim,
                ),
              ],
            ),
          ),
        ),
        _seta(
          Icons.chevron_right,
          podeAvancar ? AppColors.textMid : AppColors.textMuted,
          podeAvancar ? onProximo : null,
        ),
      ],
    );
  }

  Widget _seta(IconData icon, Color cor, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 20, color: cor),
      ),
    );
  }
}

// ─── Dev Tools Sheet ───────────────────────────────────────────────────────

/// Pill discreto de status do CNPJ no header (opção 1b).
///
/// Normal → dot verde + "CNPJ ativo". Problema (certificado expirado, removido
/// ou vencendo, ou erro de carga) → dot âmbar + "CNPJ · atenção". Estados
/// Idle/Uploading/sem-provider são tratados como normais (sem falso alarme).
class _CnpjPill extends StatelessWidget {
  final CertificadoState? state;
  final VoidCallback? onTap;

  const _CnpjPill({required this.state, required this.onTap});

  bool get _problema {
    final s = state;
    if (s is CertificadoSuccess) {
      final m = s.metadata;
      return m.status == StatusCertificado.removido ||
          m.status == StatusCertificado.expirado ||
          m.diasParaVencer <= CertificadoThresholds.diasAviso;
    }
    return s is CertificadoErro;
  }

  @override
  Widget build(BuildContext context) {
    final problema = _problema;
    final cor = problema ? AppColors.amber : AppColors.green;
    final texto = problema ? 'CNPJ · atenção' : 'CNPJ ativo';

    // Área de toque ≥ 48px (regra do handoff) sem alterar o visual do pill:
    // o Container externo expande apenas a região clicável.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                texto,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: problema ? AppColors.amber : AppColors.textMid,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevToolsSheet extends StatelessWidget {
  const _DevToolsSheet();

  // ── Apagar apenas notas fiscais ──────────────────────────────────────────

  Future<void> _apagarNotas(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Apagar notas fiscais?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Remove todas as NFS-e registradas. '
          'Os serviços voltam ao status "Aguardando NF" para poderem ser reemitidos.',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Apagar',
              style: GoogleFonts.outfit(
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!context.mounted) return;

    // Limpa as notas
    final notaProvider = context.read<NotaFiscalProvider>();
    final servicoProvider = context.read<ServicoProvider>();
    await notaProvider.limpar();

    // Reverte status dos serviços que tinham NF para aguardandoNf
    await servicoProvider.reverterStatusNf();

    if (context.mounted) Navigator.of(context).pop();
  }

  // ── Apagar apenas serviços ───────────────────────────────────────────────

  Future<void> _apagarSomenteServicos(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Apagar serviços?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Remove todos os serviços registrados mas mantém o médico e tomadores cadastrados.',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Apagar',
              style: GoogleFonts.outfit(
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!context.mounted) return;

    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();
    await servicoProvider.limparServicos();
    await notaProvider.limpar();

    if (context.mounted) Navigator.of(context).pop();
  }

  // ── Resetar tudo ─────────────────────────────────────────────────────────

  Future<void> _resetarTudo(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Resetar tudo?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Apaga médico, tomadores, serviços e todas as notas fiscais. '
          'O onboarding será exibido novamente.',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Resetar',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!context.mounted) return;

    final servicoProvider = context.read<ServicoProvider>();
    final notaProvider = context.read<NotaFiscalProvider>();
    final onboardingProvider = context.read<OnboardingProvider>();
    await servicoProvider.limparServicos();
    await notaProvider.limpar();
    await onboardingProvider.resetar();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => OnboardingScreen(
            onConcluir: () {
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SyncViewScreen()),
                (_) => false,
              );
            },
          ),
        ),
        (_) => false,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(
                Icons.bug_report_outlined,
                color: Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Dev Tools',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DEBUG ONLY',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Estas opções não estarão disponíveis no build de produção.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),

          // Opção 1 — Apagar notas fiscais
          _DevOption(
            icone: Icons.receipt_long_outlined,
            cor: AppColors.cyan,
            titulo: 'Apagar notas fiscais',
            descricao:
                'Remove todas as NFS-e. Serviços voltam para "Aguardando NF".',
            onTap: () => _apagarNotas(context),
          ),
          const SizedBox(height: 12),

          // Opção 2 — Apagar serviços (e notas vinculadas)
          _DevOption(
            icone: Icons.delete_sweep_outlined,
            cor: Colors.orange,
            titulo: 'Apagar serviços',
            descricao:
                'Mantém médico e tomadores. Útil para testar o fluxo de adição.',
            onTap: () => _apagarSomenteServicos(context),
          ),
          const SizedBox(height: 12),

          // Opção 3 — Resetar tudo
          _DevOption(
            icone: Icons.restart_alt,
            cor: Colors.redAccent,
            titulo: 'Resetar tudo',
            descricao: 'Apaga todos os dados e reinicia o onboarding do zero.',
            onTap: () => _resetarTudo(context),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Fechar', style: GoogleFonts.outfit(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _DevOption ────────────────────────────────────────────────────────────

class _DevOption extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  const _DevOption({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: cor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: cor.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
