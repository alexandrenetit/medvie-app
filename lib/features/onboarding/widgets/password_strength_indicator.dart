// lib/features/onboarding/widgets/password_strength_indicator.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

enum _PasswordStrength { vazio, fraco, medio, forte }

_PasswordStrength _avaliar(String senha) {
  if (senha.isEmpty) return _PasswordStrength.vazio;
  if (senha.length < 8) return _PasswordStrength.fraco;
  final temNumero = senha.contains(RegExp(r'[0-9]'));
  final temEspecial = senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  if (temNumero && temEspecial) return _PasswordStrength.forte;
  return _PasswordStrength.medio;
}

class PasswordStrengthIndicator extends StatelessWidget {
  final String senha;

  const PasswordStrengthIndicator({super.key, required this.senha});

  @override
  Widget build(BuildContext context) {
    final forca = _avaliar(senha);
    if (forca == _PasswordStrength.vazio) return const SizedBox.shrink();

    final (cor, label, fracao) = switch (forca) {
      _PasswordStrength.fraco  => (Colors.redAccent,  'Fraca',  1 / 3),
      _PasswordStrength.medio  => (AppColors.amber,   'Média',  2 / 3),
      _PasswordStrength.forte  => (AppColors.green,   'Forte',  1.0),
      _ => (Colors.transparent, '', 0.0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fracao),
            duration: const Duration(milliseconds: 300),
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(cor),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Senha $label',
          style: TextStyle(color: cor, fontSize: 11),
        ),
      ],
    );
  }
}
