// lib/features/certificado/screens/certificado_upload_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/certificado_error_codes.dart';
import '../../../core/platform/screenshot_guard.dart';
import '../../../core/providers/certificado_provider.dart';
import '../widgets/arquivo_picker_tile.dart';
import '../widgets/senha_field.dart';

/// Tela de upload do certificado digital A1 (PFX/P12) para um CNPJ próprio.
///
/// Segurança:
/// - Bytes do PFX permanecem em memória apenas entre seleção e envio.
/// - Após `provider.enviar` retornar (sucesso ou erro), `fillRange(0,len,0)`
///   é chamado em sucesso e a referência é descartada.
/// - Mesma limpeza ocorre em [dispose] se a tela for fechada antes do envio.
/// - Senha nunca é persistida — apenas no controller do `TextFormField`, que é
///   descartado no [dispose].
///
/// Retorna `true` via `Navigator.pop` em caso de sucesso, para que a tela
/// chamadora atualize-se se necessário.
class CertificadoUploadScreen extends StatefulWidget {
  final String cnpjId;

  const CertificadoUploadScreen({super.key, required this.cnpjId});

  @override
  State<CertificadoUploadScreen> createState() =>
      CertificadoUploadScreenState();
}

class CertificadoUploadScreenState extends State<CertificadoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();

  Uint8List? _bytes;
  bool _restritoAoCnpj = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    ScreenshotGuard.enable();
  }

  @override
  void dispose() {
    ScreenshotGuard.disable();
    _senhaController.dispose();
    if (_bytes != null) {
      _bytes!.fillRange(0, _bytes!.length, 0);
      _bytes = null;
    }
    super.dispose();
  }

  void _onPicked(Uint8List bytes, String name, int size) {
    debugPrint(
      '[certificado.upload] arquivo:picked name=$name size=$size '
      'cnpjId=${widget.cnpjId}',
    );
    setState(() => _bytes = bytes);
  }

  /// Injeta um arquivo previamente "selecionado" para testes de widget,
  /// contornando o `FilePicker` nativo (impossível em widget tests).
  /// Espelha o efeito de [_onPicked] sem invocar o seletor.
  @visibleForTesting
  void debugInjectArquivo(Uint8List bytes, String name, int size) {
    _onPicked(bytes, name, size);
  }

  void _onErroPicker(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.red,
      ),
    );
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_formKey.currentState!.validate()) return;
    if (_bytes == null) {
      debugPrint(
        '[certificado.upload] submit:bloqueado motivo=arquivoAusente '
        'cnpjId=${widget.cnpjId}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um arquivo .pfx ou .p12.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    debugPrint(
      '[certificado.upload] submit:start cnpjId=${widget.cnpjId} '
      'bytesLen=${_bytes!.length} senhaLen=${_senhaController.text.length} '
      'restritoAoCnpj=$_restritoAoCnpj',
    );
    setState(() => _enviando = true);
    final provider = context.read<CertificadoProvider>();
    await provider.enviar(
      widget.cnpjId,
      _bytes!,
      _senhaController.text,
      _restritoAoCnpj,
    );
    if (!mounted) return;
    final s = provider.state;
    if (s is CertificadoErro) {
      debugPrint(
        '[certificado.upload] submit:erro cnpjId=${widget.cnpjId} '
        'codigo=${s.codigo} mensagem=${s.mensagem}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(traduzir(s.codigo, fallback: s.mensagem)),
          backgroundColor: AppColors.red,
        ),
      );
      setState(() => _enviando = false);
      return;
    }
    if (s is CertificadoSuccess) {
      debugPrint(
        '[certificado.upload] submit:ok cnpjId=${widget.cnpjId} '
        'subjectCnpj=${s.metadata.subjectCnpj} status=${s.metadata.status}',
      );
      _bytes!.fillRange(0, _bytes!.length, 0);
      setState(() {
        _bytes = null;
        _enviando = false;
      });
      _senhaController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Certificado enviado.'),
          backgroundColor: AppColors.green,
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }
    // Estado inesperado (Uploading/Idle) — fallback defensivo.
    setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Enviar certificado'),
        backgroundColor: AppColors.bg,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Faça upload do certificado A1 (.pfx ou .p12). '
                'A senha não é armazenada.',
                style: TextStyle(color: AppColors.textMid, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ArquivoPickerTile(
                onPicked: _onPicked,
                onErro: _onErroPicker,
              ),
              const SizedBox(height: 16),
              SenhaField(
                controller: _senhaController,
                labelText: 'Senha do certificado',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  _enviar();
                },
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Informe a senha do certificado.'
                    : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Restringir ao CNPJ informado',
                  style: TextStyle(color: AppColors.text, fontSize: 14),
                ),
                subtitle: const Text(
                  'Recomendado. Bloqueia uso do certificado em outro CNPJ.',
                  style: TextStyle(color: AppColors.textMid, fontSize: 12),
                ),
                value: _restritoAoCnpj,
                onChanged: _enviando
                    ? null
                    : (v) => setState(() => _restritoAoCnpj = v),
                activeThumbColor: AppColors.green,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _enviando ? null : () { _enviar(); },
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : const Text(
                          'Anexar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
