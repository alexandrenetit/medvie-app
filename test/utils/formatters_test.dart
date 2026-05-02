// test/utils/formatters_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/utils/formatters.dart';

void main() {
  // ── formatCpf ────────────────────────────────────────────────────────────

  group('formatCpf', () {
    test('formata 11 dígitos sem máscara', () {
      expect('12345678901'.formatCpf(), '123.456.789-01');
    });

    test('formata CPF já com máscara (remove e reformata)', () {
      expect('123.456.789-01'.formatCpf(), '123.456.789-01');
    });

    test('formata CPF com pontuação mista', () {
      expect('123456.789-01'.formatCpf(), '123.456.789-01');
    });

    test('retorna original quando comprimento inválido — menos de 11 dígitos', () {
      expect('1234567890'.formatCpf(), '1234567890');
    });

    test('retorna original quando comprimento inválido — mais de 11 dígitos', () {
      expect('123456789012'.formatCpf(), '123456789012');
    });

    test('retorna original quando string vazia', () {
      expect(''.formatCpf(), '');
    });

    test('retorna original quando string só com letras', () {
      expect('abcdefghijk'.formatCpf(), 'abcdefghijk');
    });

    test('CPF com zeros — formata corretamente', () {
      expect('00000000000'.formatCpf(), '000.000.000-00');
    });

    test('CPF com todos os dígitos iguais', () {
      expect('11111111111'.formatCpf(), '111.111.111-11');
    });
  });

  // ── formatCnpj ───────────────────────────────────────────────────────────

  group('formatCnpj', () {
    test('formata 14 dígitos sem máscara', () {
      expect('12345678000195'.formatCnpj(), '12.345.678/0001-95');
    });

    test('formata CNPJ já com máscara (remove e reformata)', () {
      expect('12.345.678/0001-95'.formatCnpj(), '12.345.678/0001-95');
    });

    test('formata CNPJ com pontuação parcial', () {
      expect('12345678/0001-95'.formatCnpj(), '12.345.678/0001-95');
    });

    test('retorna original quando comprimento inválido — menos de 14 dígitos', () {
      expect('1234567800019'.formatCnpj(), '1234567800019');
    });

    test('retorna original quando comprimento inválido — mais de 14 dígitos', () {
      expect('123456780001955'.formatCnpj(), '123456780001955');
    });

    test('retorna original quando string vazia', () {
      expect(''.formatCnpj(), '');
    });

    test('retorna original quando string só com letras', () {
      expect('abcdefghijklmn'.formatCnpj(), 'abcdefghijklmn');
    });

    test('CNPJ com zeros — formata corretamente', () {
      expect('00000000000000'.formatCnpj(), '00.000.000/0000-00');
    });

    test('CNPJ com dígitos verificadores variados', () {
      expect('11222333000181'.formatCnpj(), '11.222.333/0001-81');
    });
  });

  // ── digitsOnly ───────────────────────────────────────────────────────────

  group('digitsOnly', () {
    test('remove pontuação de CPF formatado', () {
      expect('123.456.789-01'.digitsOnly, '12345678901');
    });

    test('remove pontuação de CNPJ formatado', () {
      expect('12.345.678/0001-95'.digitsOnly, '12345678000195');
    });

    test('string só com dígitos permanece igual', () {
      expect('12345'.digitsOnly, '12345');
    });

    test('string sem dígitos resulta em string vazia', () {
      expect('abc.def-ghi'.digitsOnly, '');
    });

    test('string vazia permanece vazia', () {
      expect(''.digitsOnly, '');
    });

    test('remove espaços e caracteres especiais', () {
      expect('(11) 99999-0001'.digitsOnly, '11999990001');
    });

    test('mantém todos os dígitos de um telefone formatado', () {
      expect('+55 (21) 98888-1234'.digitsOnly, '552198888​1234'.replaceAll('\u200b', ''));
    });
  });

  // ── round-trip: formatCpf ↔ digitsOnly ───────────────────────────────────

  group('round-trip CPF', () {
    test('formatar e extrair dígitos preserva os 11 dígitos', () {
      const raw = '12345678901';
      final formatted = raw.formatCpf();
      expect(formatted.digitsOnly, raw);
    });

    test('formatar dois vezes é idempotente', () {
      const raw = '12345678901';
      expect(raw.formatCpf().formatCpf(), raw.formatCpf());
    });
  });

  // ── round-trip: formatCnpj ↔ digitsOnly ──────────────────────────────────

  group('round-trip CNPJ', () {
    test('formatar e extrair dígitos preserva os 14 dígitos', () {
      const raw = '12345678000195';
      final formatted = raw.formatCnpj();
      expect(formatted.digitsOnly, raw);
    });

    test('formatar dois vezes é idempotente', () {
      const raw = '12345678000195';
      expect(raw.formatCnpj().formatCnpj(), raw.formatCnpj());
    });
  });
}
