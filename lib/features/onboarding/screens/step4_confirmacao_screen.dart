// lib/features/onboarding/screens/step4_confirmacao_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/medico.dart';
import '../../../core/providers/onboarding_provider.dart';

class Step4ConfirmacaoScreen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onAdicionarOutroCnpj;

  const Step4ConfirmacaoScreen({
    super.key,
    required this.onNext,
    required this.onAdicionarOutroCnpj,
  });

  @override
  State<Step4ConfirmacaoScreen> createState() => _Step4ConfirmacaoScreenState();
}

class _Step4ConfirmacaoScreenState extends State<Step4ConfirmacaoScreen> {
  bool _finalizando = false;

  // ── Concluir onboarding ───────────────────────────────────────────────────

  Future<void> _concluir() async {
    setState(() => _finalizando = true);
    try {
      final provider = context.read<OnboardingProvider>();
      await provider.finalizar();

      if (!mounted) return;
      if (provider.erroFinalizar != null) {
        _snack(provider.erroFinalizar!);
        setState(() => _finalizando = false);
        return;
      }
      widget.onNext();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
      setState(() => _finalizando = false);
    }
  }

  // ── Adicionar outro CNPJ ──────────────────────────────────────────────────

  Future<void> _adicionarOutroCnpj() async {
    setState(() => _finalizando = true);
    try {
      final provider = context.read<OnboardingProvider>();
      await provider.confirmarCnpjAtual();
      provider.iniciarNovoCnpj();
      if (mounted) {
        setState(() => _finalizando = false);
        widget.onAdicionarOutroCnpj();
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
      setState(() => _finalizando = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    // Snapshot do CNPJ atual para exibição (já salvo no backend pela step 2a)
    final todosOsCnpjs = [
      ...provider.cnpjsFinalizados,
      if (provider.cnpjAtual.isNotEmpty &&
          !provider.cnpjsFinalizados
              .any((c) => c.cnpj == provider.cnpjAtual))
        CnpjComTomadores(
          cnpj: provider.cnpjAtual,
          razaoSocial: provider.razaoSocialAtual,
          municipio: provider.municipioAtual,
          tomadores: provider.tomadoresAtual,
          inscricaoMunicipal: provider.inscricaoMunicipalAtual,
          regime: provider.regimeAtual,
          metodoAssinatura: provider.metodoAssinaturaAtual,
          statusCertificado: provider.statusCertificadoAtual,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tudo certo!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Confira seus dados antes de concluir.',
              style: TextStyle(color: AppColors.textMid, fontSize: 14)),
          const SizedBox(height: 24),

          // ── Card médico ──────────────────────────────────────────────────
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Médico'),
                const SizedBox(height: 12),
                _row('Nome', provider.nome),
                _row('CPF', _mascaraCpf(provider.cpf)),
                _row('CRM', '${provider.crm}-${provider.ufCrm}'),
                _row('Especialidade', provider.especialidade?.nome ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Lista de CNPJs ───────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              itemCount: todosOsCnpjs.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cnpj = todosOsCnpjs[index];
                return _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _sectionTitle('CNPJ ${index + 1}'),
                        const Spacer(),
                        if (provider.mostrarStep3)
                          _badge(
                            '${cnpj.tomadores.length} tomador'
                            '${cnpj.tomadores.length != 1 ? 'es' : ''}',
                            AppColors.green,
                          ),
                      ]),
                      const SizedBox(height: 12),
                      _row('CNPJ', cnpj.cnpj),
                      _row('Razão Social', cnpj.razaoSocial),
                      _row('Município', cnpj.municipio),
                      _row('Regime', cnpj.regime.label),
                      const SizedBox(height: 8),

                      _MetodoBadge(
                        metodo: cnpj.metodoAssinatura,
                        status: cnpj.statusCertificado,
                      ),

                      if (provider.mostrarStep3 && cnpj.tomadores.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 8),
                        ...cnpj.tomadores.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                Icon(Icons.local_hospital_outlined,
                                    size: 14, color: AppColors.cyan),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(t.razaoSocial,
                                      style: const TextStyle(
                                          color: AppColors.textMid,
                                          fontSize: 13)),
                                ),
                                if (t.valorPadrao > 0)
                                  Text(
                                    'R\$ ${t.valorPadrao.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: AppColors.green,
                                        fontSize: 12,
                                        fontFamily: 'JetBrainsMono'),
                                  ),
                              ]),
                            )),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Adicionar outro CNPJ ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _finalizando ? null : _adicionarOutroCnpj,
              icon: const Icon(Icons.add, color: AppColors.cyan),
              label: const Text('Adicionar outro CNPJ',
                  style: TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.cyan),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Concluir ─────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _finalizando ? null : _concluir,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    AppColors.green.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _finalizando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black54))
                  : const Text('Concluir',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _mascaraCpf(String cpf) {
    final n = cpf.replaceAll(RegExp(r'\D'), '');
    if (n.length != 11) return cpf;
    return '${n.substring(0, 3)}.${n.substring(3, 6)}.${n.substring(6, 9)}-${n.substring(9)}';
  }

  Widget _buildCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: child,
      );

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          color: AppColors.green,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5));

  Widget _badge(String label, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: cor, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 100,
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13))),
          ],
        ),
      );
}

// ─── Badge método de assinatura ────────────────────────────────────────────

class _MetodoBadge extends StatelessWidget {
  final MetodoAssinatura metodo;
  final StatusCertificado status;
  const _MetodoBadge({required this.metodo, required this.status});

  @override
  Widget build(BuildContext context) {
    final isCert = metodo == MetodoAssinatura.certificadoA1;
    final cor    = isCert ? AppColors.cyan : AppColors.indigo;
    final icone  = isCert
        ? Icons.verified_user_outlined
        : Icons.account_circle_outlined;
    final titulo = isCert ? 'Certificado A1 (e-CNPJ)' : 'gov.br';

    final statusColor =
        status == StatusCertificado.ativo ? AppColors.green : AppColors.amber;
    final statusLabel =
        status == StatusCertificado.ativo ? 'Configurado' : 'Pendente';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icone, color: cor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Assinatura: $titulo',
              style: const TextStyle(
                  color: AppColors.textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(statusLabel,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
