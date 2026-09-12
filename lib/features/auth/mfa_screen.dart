// lib/features/auth/mfa_screen.dart
//
// Verificação em duas etapas por e-mail — gêmea da tela do medvie-web
// (`src/pages/Seguranca.tsx`) e do contador. Mesma dupla enviar+verificar serve o primeiro
// cadastro e o login recorrente: não existe "enroll" separado de "desafio".
//
// O código só existe no e-mail de verdade — nunca aparece na tela, em log ou em mensagem de
// erro. Erros do backend não são ecoados: copy própria, sem PII.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers/onboarding_provider.dart';

/// Não recebe callback de conclusão de propósito: quem decide o destino são os gates que
/// observam `OnboardingProvider.verificacaoPendente` (o do login e o do onboarding). Com um
/// `onVerificado` por chamador, cada um precisava lembrar de reler o progresso — e o que
/// esquecesse mostraria o wizard errado sem erro nenhum.
class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key});

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  static const _tamanhoCodigo = 6;

  final _codigoController = TextEditingController();
  bool _enviando = false;
  bool _verificando = false;
  bool _reenviado = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Dispara o envio UMA vez ao entrar na tela — nunca a cada rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) => _enviarCodigo(reenvio: false));
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo({required bool reenvio}) async {
    if (!mounted) return;
    setState(() {
      _enviando = true;
      _erro = null;
      _reenviado = false;
    });

    try {
      // `reenvio` só quando o médico pediu: abrir a tela (inclusive ao voltar ao app) vai sem
      // a flag e o backend preserva o código que já está no e-mail dele.
      await context.read<OnboardingProvider>().enviarCodigoMfa(reenviar: reenvio);
      if (!mounted) return;
      if (reenvio) {
        _codigoController.clear();
        setState(() => _reenviado = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _erro = reenvio
            ? 'Não foi possível reenviar o código. Tente novamente.'
            : 'Não foi possível enviar o código. Toque em reenviar.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _confirmar() async {
    final codigo = _codigoController.text.trim();
    if (codigo.length != _tamanhoCodigo || _verificando) return;

    setState(() {
      _verificando = true;
      _erro = null;
    });

    try {
      await context.read<OnboardingProvider>().verificarCodigoMfa(codigo);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // 409 cobre código errado, expirado, já usado e tentativas esgotadas — o backend não
        // distingue os quatro de propósito (distinguir daria um oráculo ao atacante).
        _erro = e.statusCode == 409
            ? 'Código incorreto ou expirado. Verifique e tente novamente.'
            : 'Não foi possível confirmar agora. Tente novamente em instantes.';
        // Só limpa quando o código realmente não serve: apagar o campo numa falha de rede
        // faria o médico descartar um código VÁLIDO e pedir outro.
        if (e.statusCode == 409) _codigoController.clear();
        _verificando = false;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível confirmar agora. Tente novamente em instantes.';
        _verificando = false;
      });
      return;
    }

    // Sucesso: o provider já notificou com o progresso relido, então esta tela sai de cena
    // pelo rebuild do gate. `mounted` porque o State pode já ter sido descartado aí.
    if (mounted) setState(() => _verificando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.greenDim,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mail_outline,
                      color: AppColors.green,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verifique seu e-mail',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Exigida pela política de segurança da sua conta.',
                          style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text(
                'Enviamos um código de 6 dígitos para o e-mail do seu cadastro. '
                'Ele expira em 10 minutos.',
                style: TextStyle(color: AppColors.textMid, fontSize: 14, height: 1.5),
              ),

              const SizedBox(height: 28),
              TextField(
                controller: _codigoController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: _tamanhoCodigo,
                enabled: !_verificando,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _confirmar(),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: const TextStyle(
                    color: AppColors.textFaint,
                    letterSpacing: 12,
                    fontSize: 28,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _erro == null ? Colors.white12 : Colors.redAccent,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.green),
                  ),
                ),
              ),

              if (_erro != null) ...[
                const SizedBox(height: 10),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _enviando ? null : () => _enviarCodigo(reenvio: true),
                  icon: _enviando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16, color: AppColors.green),
                  label: const Text(
                    'Reenviar código',
                    style: TextStyle(color: AppColors.green, fontSize: 13),
                  ),
                ),
              ),
              if (_reenviado && !_enviando)
                const Center(
                  child: Text(
                    'Um novo código foi enviado.',
                    style: TextStyle(color: AppColors.textDim, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (_codigoController.text.trim().length < _tamanhoCodigo || _verificando)
                      ? null
                      : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _verificando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Confirmar e continuar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 28),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: AppColors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A verificação em duas etapas protege seus dados fiscais mesmo se a '
                      'senha vazar.',
                      style: TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
