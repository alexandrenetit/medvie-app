// lib/features/onboarding/screens/step1a_dados_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../widgets/password_strength_indicator.dart';

class Step1aDadosScreen extends StatefulWidget {
  final VoidCallback onNext;
  const Step1aDadosScreen({super.key, required this.onNext});

  @override
  State<Step1aDadosScreen> createState() => _Step1aDadosScreenState();
}

class _Step1aDadosScreenState extends State<Step1aDadosScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl        = TextEditingController();
  final _cpfCtrl         = TextEditingController();
  final _crmCtrl         = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _telefoneCtrl    = TextEditingController();
  final _senhaCtrl       = TextEditingController();
  final _confirmarCtrl   = TextEditingController();
  final _cpfFocus        = FocusNode();

  String _ufSelecionada  = 'SP';
  bool _obscureSenha     = true;
  bool _obscureConfirmar = true;
  bool _salvando         = false;
  bool _carregandoCpf    = false;

  static const _ufs = [
    'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS',
    'MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC',
    'SP','SE','TO',
  ];

  @override
  void initState() {
    super.initState();
    _cpfFocus.addListener(_onCpfFocusChange);
    final p = context.read<OnboardingProvider>();
    _nomeCtrl.text     = p.nome;
    _cpfCtrl.text      = p.cpf;
    _crmCtrl.text      = p.crm;
    _emailCtrl.text    = p.email;
    _telefoneCtrl.text = p.telefone;
    if (p.ufCrm.isNotEmpty) _ufSelecionada = p.ufCrm;
  }

  @override
  void dispose() {
    _cpfFocus.removeListener(_onCpfFocusChange);
    for (final c in [_nomeCtrl, _cpfCtrl, _crmCtrl, _emailCtrl,
                      _telefoneCtrl, _senhaCtrl, _confirmarCtrl]) {
      c.dispose();
    }
    _cpfFocus.dispose();
    super.dispose();
  }

  // ── Máscaras ─────────────────────────────────────────────────────────────────

  void _onCpfChanged(String v) {
    final n = v.replaceAll(RegExp(r'\D'), '');
    String masked = n;
    if (n.length > 3)  masked = '${n.substring(0,3)}.${n.substring(3)}';
    if (n.length > 6)  masked = '${n.substring(0,3)}.${n.substring(3,6)}.${n.substring(6)}';
    if (n.length > 9)  masked = '${n.substring(0,3)}.${n.substring(3,6)}.${n.substring(6,9)}-${n.substring(9, n.length > 11 ? 11 : n.length)}';
    if (masked != _cpfCtrl.text) {
      _cpfCtrl.value = TextEditingValue(
        text: masked, selection: TextSelection.collapsed(offset: masked.length));
    }
  }

  void _onTelefoneChanged(String v) {
    final n = v.replaceAll(RegExp(r'\D'), '');
    String masked = n;
    if (n.length > 2) masked = '(${n.substring(0,2)}) ${n.substring(2)}';
    if (n.length > 7) masked = '(${n.substring(0,2)}) ${n.substring(2,7)}-${n.substring(7, n.length > 11 ? 11 : n.length)}';
    if (masked != _telefoneCtrl.text) {
      _telefoneCtrl.value = TextEditingValue(
        text: masked, selection: TextSelection.collapsed(offset: masked.length));
    }
  }

  // ── Auto-fill por CPF ─────────────────────────────────────────────────────────

  void _onCpfFocusChange() {
    if (!_cpfFocus.hasFocus) _autoFillPorCpf();
  }

  Future<void> _autoFillPorCpf() async {
    final cpf = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cpf.length != 11) return;
    if (!mounted) return;
    setState(() => _carregandoCpf = true);
    try {
      final p = context.read<OnboardingProvider>();
      final resultado = await p.api.getMedicoByCpf(cpf);
      final m = resultado.medico;
      if (!mounted) return;
      setState(() {
        _nomeCtrl.text  = m.nome;
        _crmCtrl.text   = m.crm;
        _ufSelecionada  = m.ufCrm;
        _emailCtrl.text = m.email;
        _telefoneCtrl.text = m.telefone;
      });
    } catch (_) {
      // 404 → médico novo, ignorar
    } finally {
      if (mounted) setState(() => _carregandoCpf = false);
    }
  }

  // ── Avançar ──────────────────────────────────────────────────────────────────

  Future<void> _avancar() async {
    if (!_formKey.currentState!.validate()) return;

    final p = context.read<OnboardingProvider>();
    p.setPerfil(
      nome:       _nomeCtrl.text.trim(),
      cpf:        _cpfCtrl.text.trim(),
      crm:        _crmCtrl.text.trim(),
      ufCrm:      _ufSelecionada,
      especialidade: p.especialidade, // preserva se já carregado
      email:      _emailCtrl.text.trim(),
      telefone:   _telefoneCtrl.text.trim(),
    );

    setState(() => _salvando = true);
    try {
      await p.salvarMedico(_senhaCtrl.text);
      if (mounted) widget.onNext();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Text('Seus dados',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Vamos configurar seu perfil médico.',
                style: TextStyle(color: AppColors.textMid, fontSize: 14)),
            const SizedBox(height: 28),

            // Nome
            _label('Nome completo'),
            const SizedBox(height: 8),
            _field(_nomeCtrl, 'Dr. Alexandre Silva',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null),
            const SizedBox(height: 20),

            // CPF
            _label('CPF'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _cpfCtrl,
                  focusNode: _cpfFocus,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decor('000.000.000-00'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onCpfChanged,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe seu CPF';
                    if (!OnboardingProvider.validarCpf(v)) return 'CPF inválido';
                    return null;
                  },
                ),
              ),
              if (_carregandoCpf) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54)),
                ),
              ],
            ]),
            const SizedBox(height: 20),

            // CRM + UF
            _label('CRM'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 3,
                child: _field(_crmCtrl, '123456',
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o CRM' : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _ufSelecionada,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decor('UF'),
                  items: _ufs.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
                  onChanged: (v) => setState(() => _ufSelecionada = v!),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Email
            _label('E-mail'),
            const SizedBox(height: 8),
            _field(_emailCtrl, 'seu.email@example.com',
                keyboard: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe seu e-mail';
                  if (!v.contains('@')) return 'E-mail inválido';
                  return null;
                }),
            const SizedBox(height: 20),

            // Telefone
            _label('Telefone celular'),
            const SizedBox(height: 8),
            _field(_telefoneCtrl, '(11) 99999-9999',
                keyboard: TextInputType.phone,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onTelefoneChanged,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe seu telefone' : null),
            const SizedBox(height: 24),

            // Separador — seção de senha
            const Divider(color: Colors.white12, thickness: 1),
            const SizedBox(height: 16),
            Text('Crie sua senha',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Senha
            _label('Senha'),
            const SizedBox(height: 8),
            StatefulBuilder(builder: (_, set) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: _obscureSenha,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decor('Mínimo 8 caracteres').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSenha ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textDim, size: 20),
                      onPressed: () => set(() => _obscureSenha = !_obscureSenha),
                    ),
                  ),
                  onChanged: (_) => set(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe uma senha';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
                PasswordStrengthIndicator(senha: _senhaCtrl.text),
              ],
            )),
            const SizedBox(height: 20),

            // Confirmar senha
            _label('Confirmar senha'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmarCtrl,
              obscureText: _obscureConfirmar,
              style: const TextStyle(color: Colors.white),
              decoration: _decor('Repita a senha').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmar ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textDim, size: 20),
                  onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirme sua senha';
                if (v != _senhaCtrl.text) return 'As senhas não conferem';
                return null;
              },
            ),
            const SizedBox(height: 40),

            // Botão continuar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _salvando ? null : _avancar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.green.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black54)))
                    : const Text('Continuar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: AppColors.textMid, fontSize: 13, fontWeight: FontWeight.w500));

  InputDecoration _decor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border:             OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder:      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cyan)),
        errorBorder:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter> formatters = const [],
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) =>
      TextFormField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: _decor(hint),
        keyboardType: keyboard,
        inputFormatters: formatters,
        validator: validator,
        onChanged: onChanged,
      );
}
