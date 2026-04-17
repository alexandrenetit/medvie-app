// lib/features/auth/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/onboarding_provider.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSucesso;
  final VoidCallback onCriarConta;

  const AuthScreen({
    super.key,
    required this.onLoginSucesso,
    required this.onCriarConta,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscureSenha = true;
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    if (provider.cpfDigitsSalvo != null) {
      _cpfController.text = _formatarCpf(provider.cpfDigitsSalvo!);
    }
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  String _formatarCpf(String digits) {
    if (digits.length != 11) return digits;
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }

  String _aplicarMascaraCpf(String valor) {
    final n = valor.replaceAll(RegExp(r'\D'), '');
    if (n.length <= 3) return n;
    if (n.length <= 6) return '${n.substring(0, 3)}.${n.substring(3)}';
    if (n.length <= 9) return '${n.substring(0, 3)}.${n.substring(3, 6)}.${n.substring(6)}';
    return '${n.substring(0, 3)}.${n.substring(3, 6)}.${n.substring(6, 9)}-'
        '${n.substring(9, n.length > 11 ? 11 : n.length)}';
  }

  void _onCpfChanged(String valor) {
    final masked = _aplicarMascaraCpf(valor);
    if (masked != _cpfController.text) {
      _cpfController.value = TextEditingValue(
        text: masked,
        selection: TextSelection.collapsed(offset: masked.length),
      );
    }
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final provider = context.read<OnboardingProvider>();
      await provider.loginERestaurar(
        _cpfController.text.trim(),
        _senhaController.text,
      );
      if (mounted) widget.onLoginSucesso();
    } catch (e) {
      if (mounted) {
        setState(() => _erro = 'CPF ou senha inválidos. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF07090F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const SizedBox(height: 40),

                // Logo / título
                Text(
                  'Medvie',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bem-vindo de volta',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 40),

                // CPF
                _buildLabel('CPF'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _cpfController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('000.000.000-00'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onCpfChanged,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe seu CPF';
                    if (!OnboardingProvider.validarCpf(v)) return 'CPF inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Senha
                _buildLabel('Senha'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _senhaController,
                  obscureText: _obscureSenha,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Digite sua senha').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSenha ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textDim,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureSenha = !_obscureSenha),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                ),

                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Text(_erro!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],

                const SizedBox(height: 32),

                // Botão entrar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _entrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _carregando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text('Entrar',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 20),

                // Link criar conta
                Center(
                  child: TextButton(
                    onPressed: widget.onCriarConta,
                    child: Text(
                      'Não tem conta? Criar conta',
                      style: TextStyle(color: AppColors.green, fontSize: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: TextStyle(
          color: AppColors.textMid,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textDim),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.green)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent)),
      );
}
