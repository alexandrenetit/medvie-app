// lib/core/utils/formatters.dart
//
// M-07: formatadores centralizados de CPF, CNPJ e entrada monetária.
// Use via extension: '12345678901'.formatCpf()  ou  '12345678000195'.formatCnpj()

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

extension StringFormatters on String {
  /// Formata digits de CPF para xxx.xxx.xxx-xx.
  /// Aceita string com ou sem máscara; retorna a original se o comprimento for inválido.
  String formatCpf() {
    final d = replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return this;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }

  /// Formata digits de CNPJ para xx.xxx.xxx/xxxx-xx.
  /// Aceita string com ou sem máscara; retorna a original se o comprimento for inválido.
  String formatCnpj() {
    final d = replaceAll(RegExp(r'\D'), '');
    if (d.length != 14) return this;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
  }

  /// Remove toda pontuação, retornando apenas dígitos.
  String get digitsOnly => replaceAll(RegExp(r'\D'), '');

  /// Valida o dígito verificador de um CNPJ — numérico OU alfanumérico
  /// (IN RFB 2.229/2024, vigente desde 2026: 12 posições alfanuméricas +
  /// 2 DV numéricos). Aceita string com ou sem máscara. Para CNPJ puramente
  /// numérico reduz ao algoritmo módulo-11 tradicional.
  bool get isCnpjValido {
    final s = toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (s.length != 14) return false;
    // Os dois DV são sempre numéricos.
    if (!RegExp(r'^[0-9]{2}$').hasMatch(s.substring(12))) return false;
    // Rejeita sequência trivial repetida (ex.: 00000000000000).
    if (RegExp(r'^(.)\1{13}$').hasMatch(s)) return false;

    // Valor de cada caractere = código ASCII − 48 ('0'→0 … 'Z'→42).
    int valorEm(int i) => s.codeUnitAt(i) - 48;
    int calcularDv(int len, List<int> pesos) {
      var soma = 0;
      for (var i = 0; i < len; i++) {
        soma += valorEm(i) * pesos[i];
      }
      final resto = soma % 11;
      return resto < 2 ? 0 : 11 - resto;
    }

    const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    return calcularDv(12, pesos1) == valorEm(12) &&
        calcularDv(13, pesos2) == valorEm(13);
  }
}

/// Aplica a máscara de CNPJ (xx.xxx.xxx/xxxx-xx) durante a digitação.
/// Suporta CNPJ alfanumérico (uppercase, 12 alfanum + 2 DV); limita a 14
/// posições cruas. O cursor fica no fim — entrada típica é sequencial.
class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final entrada = newValue.text;
    final sel = newValue.selection.baseOffset;

    // Quantos caracteres válidos (alfanum) existem antes do cursor — preserva a
    // posição ao editar no meio. -1 = cursor indefinido → vai para o fim.
    final rawAntesCursor = sel < 0
        ? -1
        : entrada
            .substring(0, sel.clamp(0, entrada.length))
            .replaceAll(RegExp(r'[^0-9A-Za-z]'), '')
            .length;

    var cru = entrada.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (cru.length > 14) cru = cru.substring(0, 14);

    final buffer = StringBuffer();
    var novoCursor = 0;
    for (var i = 0; i < cru.length; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(cru[i]);
      if (rawAntesCursor > 0 && (i + 1) <= rawAntesCursor) {
        novoCursor = buffer.length;
      }
    }

    final texto = buffer.toString();
    final offset =
        rawAntesCursor < 0 ? texto.length : novoCursor.clamp(0, texto.length);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Formata entrada monetária pt-BR (centavos): 1234 → "12,34".
/// Reutilizável em qualquer campo de valor (PF/CNPJ).
class CurrencyInputFormatter extends TextInputFormatter {
  static final NumberFormat _fmt = NumberFormat('#,##0.00', 'pt_BR');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return const TextEditingValue(text: '');
    final limitado = digitos.length > 15 ? digitos.substring(0, 15) : digitos;
    final texto = _fmt.format(int.parse(limitado) / 100.0);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}