// test/utils/app_colors_test.dart
//
// Garante que os valores hex da paleta de cores não regridam silenciosamente.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/constants/app_colors.dart';

void main() {
  group('AppColors — valores hex não regridem', () {
    // Backgrounds
    test('bg é 0xFF07090F', () => expect(AppColors.bg, const Color(0xFF07090F)));
    test('bg2 é 0xFF0D1117', () => expect(AppColors.bg2, const Color(0xFF0D1117)));
    test('surface é 0xFF111827', () => expect(AppColors.surface, const Color(0xFF111827)));
    test('surface2 é 0xFF1A2235', () => expect(AppColors.surface2, const Color(0xFF1A2235)));
    test('border é 0xFF1E2D40', () => expect(AppColors.border, const Color(0xFF1E2D40)));

    // Brand
    test('green é 0xFF00C98A', () => expect(AppColors.green, const Color(0xFF00C98A)));
    test('greenDim é 0xFF004D35', () => expect(AppColors.greenDim, const Color(0xFF004D35)));
    test('cyan é 0xFF0EA5E9', () => expect(AppColors.cyan, const Color(0xFF0EA5E9)));
    test('indigo é 0xFF818CF8', () => expect(AppColors.indigo, const Color(0xFF818CF8)));
    test('amber é 0xFFF59E0B', () => expect(AppColors.amber, const Color(0xFFF59E0B)));
    test('red é 0xFFEF4444', () => expect(AppColors.red, const Color(0xFFEF4444)));

    // Text
    test('text é branco puro (0xFFFFFFFF)', () => expect(AppColors.text, const Color(0xFFFFFFFF)));
    test('textMid é 0xFFCBD5E1', () => expect(AppColors.textMid, const Color(0xFFCBD5E1)));
    test('textDim é 0xFF94A3B8', () => expect(AppColors.textDim, const Color(0xFF94A3B8)));
    test('textFaint é 0xFF475569', () => expect(AppColors.textFaint, const Color(0xFF475569)));
  });

  group('AppColors — propriedades semânticas', () {
    int channelInt(double channel) => (channel * 255.0).round().clamp(0, 255);
    int alphaOf(Color c) => channelInt(c.a);
    int sumRgb(Color c) => channelInt(c.r) + channelInt(c.g) + channelInt(c.b);

    test('todas as cores têm alpha 0xFF (totalmente opacas)', () {
      final cores = [
        AppColors.bg, AppColors.bg2, AppColors.surface, AppColors.surface2,
        AppColors.border, AppColors.green, AppColors.greenDim, AppColors.cyan,
        AppColors.indigo, AppColors.amber, AppColors.red,
        AppColors.text, AppColors.textMid, AppColors.textDim, AppColors.textFaint,
      ];
      for (final cor in cores) {
        expect(alphaOf(cor), 255, reason: '$cor deve ser totalmente opaca');
      }
    });

    test('green é mais claro que greenDim (maior valor luminoso)', () {
      expect(sumRgb(AppColors.green), greaterThan(sumRgb(AppColors.greenDim)));
    });

    test('text é mais claro que textFaint', () {
      expect(sumRgb(AppColors.text), greaterThan(sumRgb(AppColors.textFaint)));
    });

    test('bg é mais escuro que surface', () {
      expect(sumRgb(AppColors.bg), lessThan(sumRgb(AppColors.surface)));
    });
  });
}
