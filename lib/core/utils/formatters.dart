// lib/core/utils/formatters.dart
//
// M-07: formatadores centralizados de CPF e CNPJ.
// Use via extension: '12345678901'.formatCpf()  ou  '12345678000195'.formatCnpj()

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
}
