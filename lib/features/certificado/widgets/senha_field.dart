// lib/features/certificado/widgets/senha_field.dart

import 'package:flutter/material.dart';

/// Campo de entrada de senha para certificado digital A1 (PFX/P12).
///
/// Diferenças sobre um `TextFormField` cru:
/// - `obscureText` com toggle de visibilidade via ícone (acessível).
/// - `autofillHints: const []` para impedir gerenciadores de senha do SO de
///   capturar/sugerir a senha do PFX — a senha do certificado é segredo de
///   uso transitório e não deve entrar em cofres de credenciais do dispositivo.
/// - `enableSuggestions: false` e `autocorrect: false` para evitar exposição em
///   barras de sugestão do teclado.
/// - `keyboardType: visiblePassword` para teclado consistente entre plataformas.
///
/// O controller é a única fonte do valor — este widget NÃO armazena a senha em
/// estado próprio nem manipula clipboard.
class SenhaField extends StatefulWidget {
  final TextEditingController controller;
  final String? labelText;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  const SenhaField({
    super.key,
    required this.controller,
    this.labelText,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  });

  @override
  State<SenhaField> createState() => _SenhaFieldState();
}

class _SenhaFieldState extends State<SenhaField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      autofillHints: const [],
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction ?? TextInputAction.done,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
        ),
      ),
    );
  }
}
