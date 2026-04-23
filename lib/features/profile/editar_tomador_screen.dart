// lib/features/profile/editar_tomador_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/medico.dart';
import '../../core/providers/onboarding_provider.dart';

class EditarTomadorScreen extends StatefulWidget {
  final String cnpjProprio;
  final Tomador tomador;

  const EditarTomadorScreen({
    super.key,
    required this.cnpjProprio,
    required this.tomador,
  });

  @override
  State<EditarTomadorScreen> createState() => _EditarTomadorScreenState();
}

class _EditarTomadorScreenState extends State<EditarTomadorScreen> {
  late final TextEditingController _valorCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _aliquotaCtrl;
  late bool _retemIss;
  late bool _retemIrrf;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tomador;
    _valorCtrl = TextEditingController(
      text: t.valorPadrao > 0 ? t.valorPadrao.toStringAsFixed(2) : '',
    );
    _emailCtrl = TextEditingController(text: t.emailFinanceiro ?? '');
    _aliquotaCtrl = TextEditingController(
      text: t.aliquotaIss > 0 ? t.aliquotaIss.toStringAsFixed(2) : '',
    );
    _retemIss = t.retemIss;
    _retemIrrf = t.retemIrrf;
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _emailCtrl.dispose();
    _aliquotaCtrl.dispose();
    super.dispose();
  }

  // ── Validação ─────────────────────────────────────────────────────────────

  bool _emailValido(String email) {
    if (email.isEmpty) return true;
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    ).hasMatch(email);
  }

  // ── Salvar ────────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (_salvando) return;

    final emailTexto = _emailCtrl.text.trim();
    if (!_emailValido(emailTexto)) {
      _snack('E-mail do financeiro inválido.');
      return;
    }

    double aliquotaIss = 0.0;
    if (_retemIss) {
      aliquotaIss =
          double.tryParse(_aliquotaCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      if (aliquotaIss < 0 || aliquotaIss > 10) {
        _snack('Alíquota ISS deve estar entre 0,00% e 10,00%.');
        return;
      }
    }

    final valorPadrao =
        double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

    final tomadorAtualizado = Tomador(
      id: widget.tomador.id,
      cnpj: widget.tomador.cnpj,
      razaoSocial: widget.tomador.razaoSocial,
      municipio: widget.tomador.municipio,
      uf: widget.tomador.uf,
      codigoIbge: widget.tomador.codigoIbge,
      inscricaoMunicipal: widget.tomador.inscricaoMunicipal,
      valorPadrao: valorPadrao,
      emailFinanceiro: emailTexto.isEmpty ? null : emailTexto,
      retemIss: _retemIss,
      aliquotaIss: _retemIss ? aliquotaIss : 0.0,
      retemIrrf: _retemIrrf,
    );

    setState(() => _salvando = true);
    final erro = await context
        .read<OnboardingProvider>()
        .atualizarTomador(widget.cnpjProprio, tomadorAtualizado);
    if (!mounted) return;
    setState(() => _salvando = false);

    if (erro != null) {
      _snack(erro);
    } else {
      _snack('Tomador atualizado com sucesso!', sucesso: true);
      Navigator.of(context).pop(true);
    }
  }

  void _snack(String msg, {bool sucesso = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.outfit()),
        backgroundColor: sucesso ? AppColors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = widget.tomador;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Editar tomador',
            style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header do tomador (somente leitura) ───────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_hospital_outlined,
                        color: AppColors.green, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.razaoSocial,
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('${t.cnpj}  ·  ${t.municipio}/${t.uf}',
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 11, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Campos editáveis ──────────────────────────────────────────
            Text('DADOS DO SERVIÇO',
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDim,
                    letterSpacing: 1.2)),
            const SizedBox(height: 14),

            // Valor padrão
            TextFormField(
              controller: _valorCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style:
                  GoogleFonts.jetBrainsMono(fontSize: 15, color: Colors.white),
              decoration: _inputDec(
                label: 'Valor padrão do serviço',
                hint: 'Ex: 2500,00',
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
            const SizedBox(height: 24),

            // ── Retenção fiscal ───────────────────────────────────────────
            Text('RETENÇÃO FISCAL',
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDim,
                    letterSpacing: 1.2)),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.textDim.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  // Toggle ISS
                  _ToggleRow(
                    icon: Icons.account_balance_outlined,
                    label: 'Retém ISS?',
                    value: _retemIss,
                    onChanged: (v) => setState(() => _retemIss = v),
                  ),

                  // Campo alíquota animado
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child:
                          FadeTransition(opacity: animation, child: child),
                    ),
                    child: _retemIss
                        ? Padding(
                            key: const ValueKey('aliquota_field'),
                            padding: const EdgeInsets.only(top: 12),
                            child: TextFormField(
                              controller: _aliquotaCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                        : const SizedBox.shrink(
                            key: ValueKey('aliquota_hidden')),
                  ),

                  const SizedBox(height: 12),
                  Divider(
                      color: AppColors.textDim.withValues(alpha: 0.15),
                      height: 1),
                  const SizedBox(height: 12),

                  // Toggle IRRF
                  _ToggleRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Retém IRRF?',
                    sublabel: 'Alíquota legal: 1,5%',
                    value: _retemIrrf,
                    onChanged: (v) => setState(() => _retemIrrf = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ── Botão salvar ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      AppColors.green.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black54)))
                    : Text('Salvar alterações',
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper InputDecoration ────────────────────────────────────────────────

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
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.sublabel,
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
              Text(label,
                  style:
                      GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
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
