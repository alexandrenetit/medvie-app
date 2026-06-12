// lib/features/syncview/widgets/endereco_fiscal_form.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/medico.dart';

/// Formulário de endereço fiscal nacional do paciente PF (FR-003/004/005).
///
/// CEP dispara autofill via [onResolveCep] (parent liga em
/// `ServicoProvider.buscarEnderecoFiscal`). Campos permanecem editáveis para
/// fallback manual quando o CEP falha (FR-004). Emite o endereço atual por
/// [onChanged] a cada alteração; o chip de status reflete completude (FR-005).
class EnderecoFiscalForm extends StatefulWidget {
  final EnderecoFiscalTomador? initial;

  /// Resolve o CEP (8 dígitos) no backend. Retorna `null` em falha → mantém
  /// preenchimento manual.
  final Future<EnderecoFiscalTomador?> Function(String cepNumerico)
      onResolveCep;

  final ValueChanged<EnderecoFiscalTomador> onChanged;

  const EnderecoFiscalForm({
    super.key,
    required this.onResolveCep,
    required this.onChanged,
    this.initial,
  });

  @override
  State<EnderecoFiscalForm> createState() => _EnderecoFiscalFormState();
}

class _EnderecoFiscalFormState extends State<EnderecoFiscalForm> {
  late final TextEditingController _cep;
  late final TextEditingController _numero;
  late final TextEditingController _complemento;
  late final TextEditingController _logradouro;
  late final TextEditingController _bairro;
  late final TextEditingController _municipio;
  late final TextEditingController _uf;

  String _ibge = '';
  bool _buscando = false;
  bool _cepFalhou = false;
  bool _completo = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _cep = TextEditingController(text: _mascararCep(e?.cep ?? ''));
    _numero = TextEditingController(text: e?.numero ?? '');
    _complemento = TextEditingController(text: e?.complemento ?? '');
    _logradouro = TextEditingController(text: e?.logradouro ?? '');
    _bairro = TextEditingController(text: e?.bairro ?? '');
    _municipio = TextEditingController(text: e?.municipio ?? '');
    _uf = TextEditingController(text: e?.uf ?? '');
    _ibge = e?.codigoMunicipioIbge ?? '';
    _completo = _atual.completo;
  }

  @override
  void dispose() {
    _cep.dispose();
    _numero.dispose();
    _complemento.dispose();
    _logradouro.dispose();
    _bairro.dispose();
    _municipio.dispose();
    _uf.dispose();
    super.dispose();
  }

  // ─── Endereço atual / completude ─────────────────────────────────────────

  EnderecoFiscalTomador get _atual => EnderecoFiscalTomador(
        cep: _digitos(_cep.text),
        logradouro: _logradouro.text.trim(),
        numero: _numero.text.trim(),
        complemento: _complemento.text.trim(),
        bairro: _bairro.text.trim(),
        municipio: _municipio.text.trim(),
        uf: _uf.text.trim(),
        codigoMunicipioIbge: _ibge,
      );

  bool get _vazio =>
      _digitos(_cep.text).isEmpty &&
      _numero.text.trim().isEmpty &&
      _logradouro.text.trim().isEmpty;

  void _emit() => widget.onChanged(_atual);

  /// Edição manual de campo: recomputa o chip/borda (setState) e emite.
  void _onManualChanged(String _) {
    setState(() => _completo = _atual.completo);
    _emit();
  }

  static String _digitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  static String _mascararCep(String raw) {
    final d = _digitos(raw);
    final lim = d.length > 8 ? d.substring(0, 8) : d;
    if (lim.length <= 5) return lim;
    return '${lim.substring(0, 5)}-${lim.substring(5)}';
  }

  // ─── CEP → autofill ──────────────────────────────────────────────────────

  void _onCepChanged(String _) {
    final d = _digitos(_cep.text);
    setState(() {
      _cepFalhou = false;
      _completo = _atual.completo;
    });
    _emit();
    if (d.length == 8 && !_buscando) {
      unawaited(_autoPreencher(d));
    }
  }

  Future<void> _autoPreencher(String cepNumerico) async {
    setState(() => _buscando = true);
    EnderecoFiscalTomador? resolvido;
    try {
      resolvido = await widget.onResolveCep(cepNumerico);
    } catch (_) {
      resolvido = null;
    }
    if (!mounted) return;
    setState(() {
      _buscando = false;
      if (resolvido != null) {
        _logradouro.text = resolvido.logradouro;
        _bairro.text = resolvido.bairro;
        _municipio.text = resolvido.municipio;
        _uf.text = resolvido.uf;
        _ibge = resolvido.codigoMunicipioIbge;
        _cepFalhou = false;
      } else {
        // Falha → preenchimento manual (FR-004).
        _cepFalhou = true;
      }
      _completo = _atual.completo;
    });
    _emit();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final completo = _completo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completo
              ? AppColors.green.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Endereço fiscal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              _statusChip(completo),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _campo(
                  key: const ValueKey('endereco-cep'),
                  label: 'CEP',
                  controller: _cep,
                  hint: '00000-000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CepInputFormatter()],
                  onChanged: _onCepChanged,
                  suffix: _buscando
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campo(
                  key: const ValueKey('endereco-numero'),
                  label: 'Número',
                  controller: _numero,
                  hint: 'Nº',
                  keyboardType: TextInputType.number,
                  onChanged: _onManualChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _campo(
            label: 'Logradouro',
            controller: _logradouro,
            hint: 'Rua / Avenida',
            onChanged: _onManualChanged,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _campo(
                  label: 'Bairro',
                  controller: _bairro,
                  hint: 'Bairro',
                  onChanged: _onManualChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campo(
                  label: 'UF',
                  controller: _uf,
                  hint: 'UF',
                  maxLength: 2,
                  onChanged: _onManualChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _campo(
            label: 'Município',
            controller: _municipio,
            hint: 'Cidade',
            onChanged: _onManualChanged,
          ),
          const SizedBox(height: 10),
          _campo(
            label: 'Complemento (opcional)',
            controller: _complemento,
            hint: 'Apto, bloco, sala…',
            onChanged: _onManualChanged,
          ),
          const SizedBox(height: 8),
          Text(
            _ibge.isNotEmpty ? 'IBGE: $_ibge' : 'IBGE: —',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textFaint,
            ),
          ),
          if (_cepFalhou)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'CEP não encontrado. Preencha o endereço manualmente.',
                style: TextStyle(fontSize: 11, color: AppColors.amber),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(bool completo) {
    final String texto;
    final Color cor;
    if (_vazio) {
      texto = 'Não informado';
      cor = AppColors.textFaint;
    } else if (completo) {
      texto = 'Completo';
      cor = AppColors.green;
    } else {
      texto = 'Incompleto';
      cor = AppColors.amber;
    }
    return Container(
      key: const ValueKey('endereco-status-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withValues(alpha: 0.30)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }

  Widget _campo({
    Key? key,
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
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
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
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

/// Formata o CEP como `#####-###`.
class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final lim = d.length > 8 ? d.substring(0, 8) : d;
    final buffer = StringBuffer();
    for (var i = 0; i < lim.length; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(lim[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
