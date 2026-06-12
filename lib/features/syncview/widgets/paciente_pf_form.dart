// lib/features/syncview/widgets/paciente_pf_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/medvie_api_service.dart';

/// Dados transientes do paciente PF capturados no formulário.
///
/// `documentoCpf` é o CPF bruto — existe apenas em memória durante a captura,
/// trafega no request e é descartado. NUNCA é persistido/logado (FR-002).
class PacientePfDados {
  final String documentoCpf;
  final String nome;
  final String email;
  final String telefone;

  const PacientePfDados({
    this.documentoCpf = '',
    this.nome = '',
    this.email = '',
    this.telefone = '',
  });
}

/// Estado do reconhecimento por CPF (resultado do lookup).
enum _LookupUi { idle, buscando, reconhecido, novo, invalido }

/// Formulário do paciente PF com CPF como PRIMEIRO campo (FR-014).
///
/// Ao sair do campo CPF (blur) com CPF válido, dispara [onLookupCpf]
/// (parent liga em `ServicoProvider.lookupPacientePorCpf`, FR-015):
///   - encontrado → auto-preenche nome/contato e mostra "reconhecido" (FR-016);
///     o resultado completo é repassado por [onLookupResult] para o parent
///     preencher endereço e defaults de serviço.
///   - novoPaciente (404) → indica "novo paciente".
///   - cpfInvalido (422) → marca CPF inválido.
class PacientePfForm extends StatefulWidget {
  /// Consulta o paciente pelo CPF (somente dígitos). Disparado no blur.
  final Future<LookupTomadorResponse> Function(String cpfDigits) onLookupCpf;

  /// Repassa o resultado do lookup encontrado para o parent (endereço/serviço).
  final ValueChanged<LookupTomadorResponse> onLookupResult;

  /// Emite os dados do paciente a cada alteração.
  final ValueChanged<PacientePfDados> onChanged;

  const PacientePfForm({
    super.key,
    required this.onLookupCpf,
    required this.onLookupResult,
    required this.onChanged,
  });

  @override
  State<PacientePfForm> createState() => _PacientePfFormState();
}

class _PacientePfFormState extends State<PacientePfForm> {
  final _cpf = TextEditingController();
  final _nome = TextEditingController();
  final _tel = TextEditingController();
  final _email = TextEditingController();
  final _cpfFocus = FocusNode();

  _LookupUi _ui = _LookupUi.idle;
  String _nomeReconhecido = '';

  @override
  void initState() {
    super.initState();
    _cpfFocus.addListener(_onCpfFocusChange);
  }

  @override
  void dispose() {
    _cpfFocus.removeListener(_onCpfFocusChange);
    _cpfFocus.dispose();
    _cpf.dispose();
    _nome.dispose();
    _tel.dispose();
    _email.dispose();
    super.dispose();
  }

  // ─── Emissão de dados ────────────────────────────────────────────────────

  void _emit() => widget.onChanged(
        PacientePfDados(
          documentoCpf: _digitos(_cpf.text),
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          telefone: _digitos(_tel.text),
        ),
      );

  // Nome/tel/email não alteram nada derivado no build (o banner depende do
  // lookup, não do texto) — basta emitir, sem rebuild.
  void _onManualChanged(String _) => _emit();

  static String _digitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  // ─── CPF: validação DV + blur lookup ─────────────────────────────────────

  void _onCpfChanged(String _) {
    final d = _digitos(_cpf.text);
    // Reseta reconhecimento ao editar o CPF; lookup ocorre no blur.
    if (d.length < 11 && _ui != _LookupUi.idle) {
      setState(() => _ui = _LookupUi.idle);
    }
    _emit();
  }

  void _onCpfFocusChange() {
    if (_cpfFocus.hasFocus) return;
    final d = _digitos(_cpf.text);
    if (d.length != 11) {
      if (_ui != _LookupUi.idle) setState(() => _ui = _LookupUi.idle);
      return;
    }
    if (!_cpfValido(d)) {
      setState(() => _ui = _LookupUi.invalido);
      return;
    }
    _lookup(d);
  }

  Future<void> _lookup(String cpfDigits) async {
    setState(() => _ui = _LookupUi.buscando);
    LookupTomadorResponse res;
    try {
      res = await widget.onLookupCpf(cpfDigits);
    } catch (_) {
      if (mounted) setState(() => _ui = _LookupUi.idle);
      return;
    }
    if (!mounted) return;

    if (res.encontrado) {
      _nome.text = res.nome;
      _tel.text = _mascararTelefone(res.telefone ?? '');
      _email.text = res.email ?? '';
      setState(() {
        _ui = _LookupUi.reconhecido;
        _nomeReconhecido = res.nome;
      });
      widget.onLookupResult(res);
      _emit();
    } else if (res.cpfInvalido) {
      setState(() => _ui = _LookupUi.invalido);
    } else {
      setState(() => _ui = _LookupUi.novo);
    }
  }

  /// Validação dos dígitos verificadores do CPF.
  static bool _cpfValido(String cpf) {
    final d = cpf.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false;
    int dv(int len) {
      var soma = 0;
      for (var i = 0; i < len; i++) {
        soma += int.parse(d[i]) * ((len + 1) - i);
      }
      final r = (soma * 10) % 11;
      return r == 10 ? 0 : r;
    }

    return dv(9) == int.parse(d[9]) && dv(10) == int.parse(d[10]);
  }

  static String _mascararTelefone(String raw) {
    final d = _digitos(raw);
    final lim = d.length > 11 ? d.substring(0, 11) : d;
    final b = StringBuffer();
    for (var i = 0; i < lim.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (i == 7) b.write('-');
      b.write(lim[i]);
    }
    return b.toString();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo(
          key: const ValueKey('pf-cpf'),
          label: 'CPF do paciente',
          controller: _cpf,
          focusNode: _cpfFocus,
          hint: '000.000.000-00',
          keyboardType: TextInputType.number,
          inputFormatters: [_CpfInputFormatter()],
          onChanged: _onCpfChanged,
          suffix: _ui == _LookupUi.buscando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text(
            'Buscamos o paciente ao sair do campo. Guardamos só a forma '
            'mascarada — nunca o CPF em texto puro.',
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
        ),
        _banner(),
        const SizedBox(height: 14),
        _campo(
          key: const ValueKey('pf-nome'),
          label: 'Nome completo do paciente',
          controller: _nome,
          hint: 'Como o paciente é conhecido',
          onChanged: _onManualChanged,
        ),
        const SizedBox(height: 14),
        _campo(
          key: const ValueKey('pf-tel'),
          label: 'Celular / WhatsApp (opcional)',
          controller: _tel,
          hint: '(11) 99999-9999',
          keyboardType: TextInputType.phone,
          inputFormatters: [_TelefoneInputFormatter()],
          onChanged: _onManualChanged,
        ),
        const SizedBox(height: 14),
        _campo(
          key: const ValueKey('pf-email'),
          label: 'E-mail (opcional)',
          controller: _email,
          hint: 'paciente@email.com',
          keyboardType: TextInputType.emailAddress,
          onChanged: _onManualChanged,
        ),
      ],
    );
  }

  Widget _banner() {
    if (_ui == _LookupUi.idle || _ui == _LookupUi.buscando) {
      return const SizedBox.shrink();
    }
    final String titulo;
    final String sub;
    final Color cor;
    switch (_ui) {
      case _LookupUi.reconhecido:
        titulo = '✓ $_nomeReconhecido';
        sub = 'Paciente reconhecido — dados carregados. Revise e informe o valor.';
        cor = AppColors.green;
      case _LookupUi.novo:
        titulo = 'Novo paciente';
        sub = 'CPF não cadastrado neste CNPJ — preencha os dados abaixo.';
        cor = AppColors.green;
      case _LookupUi.invalido:
        titulo = 'CPF inválido';
        sub = 'Verifique os números do CPF.';
        cor = AppColors.red;
      case _LookupUi.idle:
      case _LookupUi.buscando:
        return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey('pf-found'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cor == AppColors.red ? cor : AppColors.text,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo({
    Key? key,
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textFaint),
            filled: true,
            fillColor: AppColors.bg,
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      ],
    );
  }
}

/// Formata o CPF como `###.###.###-##`.
class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final lim = d.length > 11 ? d.substring(0, 11) : d;
    final b = StringBuffer();
    for (var i = 0; i < lim.length; i++) {
      if (i == 3 || i == 6) b.write('.');
      if (i == 9) b.write('-');
      b.write(lim[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Formata o telefone como `(##) #####-####`.
class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final lim = d.length > 11 ? d.substring(0, 11) : d;
    final b = StringBuffer();
    for (var i = 0; i < lim.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (i == 7) b.write('-');
      b.write(lim[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
