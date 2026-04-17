// lib/features/syncview/widgets/app_header.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/providers/nota_fiscal_provider.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../profile/profile_screen.dart';
import '../../syncview/syncview_screen.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  String _saudacao() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Bom dia 👋';
    if (hora < 18) return 'Boa tarde 👋';
    return 'Boa noite 👋';
  }

  void _abrirDevTools(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DevToolsSheet(),
    );
  }

  void _abrirPerfil(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    final nomeCompleto = provider.medico?.nome ?? '';
    final nomeLimpo =
        nomeCompleto.replaceAll(RegExp(r'^[Dd][Rr]\.?\s*'), '').trim();
    final nomeExibido = nomeLimpo.isNotEmpty ? 'Dr. $nomeLimpo' : 'Doutor';
    final inicial =
        nomeLimpo.isNotEmpty ? nomeLimpo[0].toUpperCase() : 'D';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _saudacao(),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textDim,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                nomeExibido,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (kDebugMode)
                GestureDetector(
                  onTap: () => _abrirDevTools(context),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bug_report_outlined,
                            color: Colors.orange, size: 12),
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
                ),
              GestureDetector(
                onTap: () => _abrirPerfil(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.green, AppColors.cyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      inicial,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Dev Tools Sheet ───────────────────────────────────────────────────────

class _DevToolsSheet extends StatelessWidget {
  const _DevToolsSheet();

  // ── Apagar apenas notas fiscais ──────────────────────────────────────────

  Future<void> _apagarNotas(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Apagar notas fiscais?',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          'Remove todas as NFS-e registradas. '
          'Os serviços voltam ao status "Aguardando NF" para poderem ser reemitidos.',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Apagar',
                style: GoogleFonts.outfit(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!context.mounted) return;

    // Limpa as notas
    await context.read<NotaFiscalProvider>().limpar();

    // Reverte status dos serviços que tinham NF para aguardandoNf
    await context.read<ServicoProvider>().reverterStatusNf();

    if (context.mounted) Navigator.of(context).pop();
  }

  // ── Apagar apenas serviços ───────────────────────────────────────────────

  Future<void> _apagarSomenteServicos(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Apagar serviços?',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          'Remove todos os serviços registrados mas mantém o médico e tomadores cadastrados.',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Apagar',
                style: GoogleFonts.outfit(
                    color: Colors.orange,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!context.mounted) return;

    await context.read<ServicoProvider>().limparServicos();
    await context.read<NotaFiscalProvider>().limpar();

    if (context.mounted) Navigator.of(context).pop();
  }

  // ── Resetar tudo ─────────────────────────────────────────────────────────

  Future<void> _resetarTudo(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Resetar tudo?',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          'Apaga médico, tomadores, serviços e todas as notas fiscais. '
          'O onboarding será exibido novamente.',
          style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Resetar',
                style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (!context.mounted) return;

    await context.read<ServicoProvider>().limparServicos();
    await context.read<NotaFiscalProvider>().limpar();
    await context.read<OnboardingProvider>().resetar();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => OnboardingScreen(
            onConcluir: () {
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const SyncViewScreen()),
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
          24, 16, 24, MediaQuery.of(context).padding.bottom + 32),
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
              const Icon(Icons.bug_report_outlined,
                  color: Colors.orange, size: 18),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DEBUG ONLY',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: Colors.orange,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Estas opções não estarão disponíveis no build de produção.',
            style: GoogleFonts.outfit(
                fontSize: 12, color: const Color(0xFF94A3B8)),
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
            descricao:
                'Apaga todos os dados e reinicia o onboarding do zero.',
            onTap: () => _resetarTudo(context),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Fechar',
                  style: GoogleFonts.outfit(fontSize: 15)),
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
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.15),
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
            Icon(Icons.chevron_right,
                color: cor.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }
}