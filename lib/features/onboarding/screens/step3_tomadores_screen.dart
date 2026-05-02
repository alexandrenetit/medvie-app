// lib/features/onboarding/screens/step3_tomadores_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/onboarding_provider.dart';

class Step3TomadoresScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step3TomadoresScreen({super.key, required this.onNext});

  @override
  State<Step3TomadoresScreen> createState() => _Step3TomadoresScreenState();
}

class _Step3TomadoresScreenState extends State<Step3TomadoresScreen> {
  final _cnpjCtrl      = TextEditingController();
  final _valorCtrl     = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _aliquotaCtrl      = TextEditingController();
  final _aliquotaIrrfCtrl  = TextEditingController();
  final _cnpjFocus         = FocusNode();
  bool _adicionando    = false;
  bool _avancando      = false;
  bool _retemIss       = false;
  bool _retemIrrf      = false;

  @override
  void dispose() {
    _cnpjCtrl.dispose();
    _valorCtrl.dispose();
    _emailCtrl.dispose();
    _aliquotaCtrl.dispose();
    _aliquotaIrrfCtrl.dispose();
    _cnpjFocus.dispose();
    super.dispose();
  }

  // ── Formatação CNPJ ───────────────────────────────────────────────────────

  String _formatarCnpj(String v) {
    v = v.replaceAll(RegExp(r'\D'), '');
    if (v.length > 14) v = v.substring(0, 14);
    if (v.length <= 2) return v;
    if (v.length <= 5) return '${v.substring(0, 2)}.${v.substring(2)}';
    if (v.length <= 8) return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5)}';
    if (v.length <= 12) return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5, 8)}/${v.substring(8)}';
    return '${v.substring(0, 2)}.${v.substring(2, 5)}.${v.substring(5, 8)}/${v.substring(8, 12)}-${v.substring(12)}';
  }

  bool _emailValido(String email) {
    if (email.isEmpty) return true;
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    ).hasMatch(email);
  }

  // ── Adicionar tomador ─────────────────────────────────────────────────────

  Future<void> _adicionar() async {
    if (_adicionando) return;
    final cnpjLimpo = _cnpjCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cnpjLimpo.length != 14) {
      _snack('CNPJ deve ter 14 dígitos');
      return;
    }
    final provider = context.read<OnboardingProvider>();
    final jaExiste = provider.tomadoresAtual
        .any((t) => t.cnpj.replaceAll(RegExp(r'\D'), '') == cnpjLimpo);
    if (jaExiste) {
      _snack('Este CNPJ já foi adicionado.');
      return;
    }
    final emailTexto = _emailCtrl.text.trim();
    if (!_emailValido(emailTexto)) {
      _snack('E-mail do financeiro inválido.');
      return;
    }
    final valorPadrao =
        double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

    double aliquotaIss = 0.0;
    if (_retemIss) {
      aliquotaIss =
          double.tryParse(_aliquotaCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      if (aliquotaIss < 0 || aliquotaIss > 10) {
        _snack('Alíquota ISS deve estar entre 0,00% e 10,00%.');
        return;
      }
    }

    double aliquotaIrrf = 1.5;
    if (_retemIrrf) {
      aliquotaIrrf =
          double.tryParse(_aliquotaIrrfCtrl.text.trim().replaceAll(',', '.')) ?? 1.5;
      if (aliquotaIrrf < 0.1 || aliquotaIrrf > 5.0) {
        _snack('Alíquota IRRF deve estar entre 0,10% e 5,00%.');
        return;
      }
    }

    setState(() => _adicionando = true);
    final ok = await provider.adicionarTomador(
      _cnpjCtrl.text,
      valorPadrao: valorPadrao,
      emailFinanceiro: emailTexto.isEmpty ? null : emailTexto,
      retemIss: _retemIss,
      aliquotaIss: aliquotaIss,
      retemIrrf: _retemIrrf,
      aliquotaIrrf: aliquotaIrrf,
    );
    if (mounted) {
      setState(() => _adicionando = false);
      if (ok) {
        _cnpjCtrl.clear();
        _valorCtrl.clear();
        _emailCtrl.clear();
        _aliquotaCtrl.clear();
        _aliquotaIrrfCtrl.clear();
        setState(() {
          _retemIss = false;
          _retemIrrf = false;
        });
        _cnpjFocus.requestFocus();
      } else {
        _snack('CNPJ do tomador não encontrado na Receita Federal.');
      }
    }
  }

  // ── Avançar ───────────────────────────────────────────────────────────────

  Future<void> _avancar() async {
    setState(() => _avancando = true);
    try {
      await context.read<OnboardingProvider>().confirmarCnpjAtual();
      if (mounted) widget.onNext();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _avancando = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.outfit()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tomadores de serviço',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Adicione os hospitais e clínicas onde você trabalha. '
            'O CNPJ do tomador é obrigatório para emitir a NFS-e.',
            style: TextStyle(color: AppColors.textMid, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),

          // ── Card de busca ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BUSCAR HOSPITAL / CLÍNICA',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDim,
                        letterSpacing: 1.2)),
                const SizedBox(height: 14),

                // CNPJ
                TextFormField(
                  controller: _cnpjCtrl,
                  focusNode: _cnpjFocus,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 15, color: Colors.white, letterSpacing: 1),
                  inputFormatters: [
                    TextInputFormatter.withFunction((old, newVal) {
                      final f = _formatarCnpj(newVal.text);
                      return newVal.copyWith(
                          text: f,
                          selection: TextSelection.collapsed(offset: f.length));
                    }),
                  ],
                  decoration: _inputDec(
                    label: 'CNPJ do tomador',
                    hint: '00.000.000/0000-00',
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(height: 12),

                // Valor padrão
                TextFormField(
                  controller: _valorCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 15, color: Colors.white),
                  decoration: _inputDec(
                    label: 'Valor padrão do serviço',
                    hint: 'Ex: 2500',
                    icon: Icons.attach_money,
                    opcional: true,
                  ),
                ),
                const SizedBox(height: 12),

                // E-mail financeiro
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.white),
                  decoration: _inputDec(
                    label: 'E-mail do financeiro',
                    hint: 'financeiro@hospital.com.br',
                    icon: Icons.email_outlined,
                    opcional: true,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'O DANFSe será enviado automaticamente para este e-mail após a emissão.',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.textDim, height: 1.5),
                ),
                const SizedBox(height: 20),

                // ── Bloco retenção fiscal ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1E293B), width: 1),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFF111827),
                  ),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                            child: Divider(
                                color: AppColors.textDim.withValues(alpha: 0.2),
                                thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('RETENÇÃO FISCAL',
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDim,
                                  letterSpacing: 1.1)),
                        ),
                        Expanded(
                            child: Divider(
                                color: AppColors.textDim.withValues(alpha: 0.2),
                                thickness: 1)),
                      ]),
                      const SizedBox(height: 14),

                      // Toggle — Retém ISS?
                      _ToggleRow(
                        icon: Icons.account_balance_outlined,
                        label: 'Retém ISS?',
                        value: _retemIss,
                        onChanged: (v) => setState(() => _retemIss = v),
                        tooltip: 'Verifique seu contrato com o hospital ou clínica. '
                            'Se retiverem ISS, o valor já vem descontado no pagamento.',
                      ),

                      // Campo Alíquota ISS — aparece apenas quando _retemIss == true
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: _retemIss
                            ? Padding(
                                key: const ValueKey('aliquota_field'),
                                padding: const EdgeInsets.only(top: 10),
                                child: TextFormField(
                                  controller: _aliquotaCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]')),
                                  ],
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 15, color: Colors.white),
                                  decoration: _inputDec(
                                    label: 'Alíquota ISS (%)',
                                    hint: 'Ex: 2,00',
                                    icon: Icons.percent,
                                  ).copyWith(
                                    helperText: 'Entre 0,00% e 10,00%',
                                    helperStyle: GoogleFonts.outfit(
                                        fontSize: 11, color: AppColors.textDim),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('aliquota_hidden')),
                      ),

                      const SizedBox(height: 10),

                      // Toggle — Retém IRRF?
                      _ToggleRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Retém IRRF?',
                        sublabel: 'Alíquota legal: 1,5%',
                        value: _retemIrrf,
                        onChanged: (v) => setState(() => _retemIrrf = v),
                        tooltip: 'A retenção de IRRF de 1,5% é feita pelo tomador sobre '
                            'honorários médicos. Consulte seu contrato ou o financeiro do hospital.',
                      ),

                      // Campo Alíquota IRRF — aparece apenas quando _retemIrrf == true
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: _retemIrrf
                            ? Padding(
                                key: const ValueKey('aliquota_irrf_field'),
                                padding: const EdgeInsets.only(top: 10),
                                child: TextFormField(
                                  controller: _aliquotaIrrfCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]')),
                                  ],
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 15, color: Colors.white),
                                  decoration: _inputDec(
                                    label: 'Alíquota IRRF (%)',
                                    hint: 'Ex: 1,50',
                                    icon: Icons.percent,
                                  ).copyWith(
                                    helperText: 'Entre 0,10% e 5,00%',
                                    helperStyle: GoogleFonts.outfit(
                                        fontSize: 11, color: AppColors.textDim),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('aliquota_irrf_hidden')),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Botão Adicionar
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _adicionando ? null : _adicionar,
                    icon: _adicionando
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.green))
                        : const Icon(Icons.add, size: 18),
                    label: Text(
                      _adicionando
                          ? 'Buscando na Receita Federal...'
                          : 'Adicionar tomador',
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.green,
                      side: BorderSide(
                          color: _adicionando
                              ? AppColors.textDim
                              : AppColors.green),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Lista de tomadores ────────────────────────────────────────────
          if (provider.tomadoresAtual.isNotEmpty) ...[
            Text(
              'TOMADORES CADASTRADOS (${provider.tomadoresAtual.length})',
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDim,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            ...provider.tomadoresAtual.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.25)),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_hospital_outlined,
                        color: AppColors.green, size: 20),
                  ),
                  title: Text(
                    t.razaoSocial,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        '${t.cnpj}  ·  ${t.municipio}/${t.uf}',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: AppColors.textDim),
                      ),
                      if (t.valorPadrao > 0)
                        Text(
                          'Serviço: R\$ ${t.valorPadrao.toStringAsFixed(0)}',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AppColors.green,
                              fontWeight: FontWeight.w600),
                        ),
                      if (t.emailFinanceiro != null &&
                          t.emailFinanceiro!.isNotEmpty)
                        Text(
                          t.emailFinanceiro!,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.cyan),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (t.retemIss || t.retemIrrf)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              if (t.retemIss)
                                _RetencaoBadge(
                                    label: 'ISS ${t.aliquotaIss.toStringAsFixed(2)}%'),
                              if (t.retemIrrf)
                                _RetencaoBadge(label: 'IRRF ${t.aliquotaIrrf.toStringAsFixed(2)}%'),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textDim, size: 18),
                    onPressed: () => provider.removerTomador(i),
                    tooltip: 'Remover',
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 24),

          // ── Botão continuar / pular ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _avancando ? null : _avancar,
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.tomadoresAtual.isNotEmpty
                    ? AppColors.green
                    : AppColors.surface,
                foregroundColor: provider.tomadoresAtual.isNotEmpty
                    ? Colors.black
                    : AppColors.textMid,
                disabledBackgroundColor:
                    AppColors.green.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: provider.tomadoresAtual.isEmpty
                    ? const BorderSide(color: Colors.white12)
                    : BorderSide.none,
              ),
              child: _avancando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black54)))
                  : Text(
                      provider.tomadoresAtual.isNotEmpty
                          ? 'Continuar  (${provider.tomadoresAtual.length})'
                          : 'Pular por agora',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper de InputDecoration ─────────────────────────────────────────────

  InputDecoration _inputDec({
    required String label,
    required String hint,
    required IconData icon,
    bool opcional = false,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: AppColors.textDim, fontSize: 14),
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
            color: AppColors.textDim.withValues(alpha: 0.5), fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textDim, size: 20),
        suffixIcon: opcional
            ? Container(
                margin: const EdgeInsets.all(8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textDim.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('opcional',
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppColors.textDim,
                        fontWeight: FontWeight.w500)),
              )
            : null,
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.textDim.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      );
}

// ── Widget auxiliar: linha de toggle ─────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final String? tooltip;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.sublabel,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textDim),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: Colors.white)),
                  if (tooltip != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: tooltip!,
                      triggerMode: TooltipTriggerMode.tap,
                      preferBelow: true,
                      showDuration: const Duration(seconds: 4),
                      child: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
              if (sublabel != null)
                Text(sublabel!,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.textDim)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.green,
          inactiveThumbColor: AppColors.textDim,
          inactiveTrackColor: AppColors.textDim.withValues(alpha: 0.2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

// ── Widget auxiliar: badge de retenção na lista ───────────────────────────────

class _RetencaoBadge extends StatelessWidget {
  final String label;
  const _RetencaoBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.green),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppColors.green,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
