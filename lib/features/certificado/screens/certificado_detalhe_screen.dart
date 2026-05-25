// lib/features/certificado/screens/certificado_detalhe_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/certificado_error_codes.dart';
import '../../../core/models/certificado_metadata.dart';
import '../../../core/providers/certificado_provider.dart';
import '../widgets/certificado_status_card.dart';
import 'certificado_upload_screen.dart';

/// Tela de detalhe do certificado digital A1 ativo de um CNPJ próprio.
///
/// Estados renderizados via [Selector] sobre `CertificadoProvider.state`:
/// - [CertificadoIdle]: empty state com CTA "Enviar certificado".
/// - [CertificadoSuccess]: card de status + ações "Substituir" / "Remover".
/// - [CertificadoErro]: mensagem traduzida + CTA "Tentar novamente".
/// - [CertificadoUploading]: spinner (transitório, raramente visível aqui).
///
/// Remoção é confirmada via [AlertDialog] destrutivo. O código 409
/// `Certificado.JaRemovido` é tratado como sucesso idempotente.
class CertificadoDetalheScreen extends StatefulWidget {
  final String cnpjId;

  const CertificadoDetalheScreen({super.key, required this.cnpjId});

  @override
  State<CertificadoDetalheScreen> createState() =>
      _CertificadoDetalheScreenState();
}

class _CertificadoDetalheScreenState extends State<CertificadoDetalheScreen> {
  bool _carregandoInicial = true;

  @override
  void initState() {
    super.initState();
    // TODO(T091): FlagSecure.enable() — proteção contra screenshot (S6).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarInicial();
    });
  }

  Future<void> _carregarInicial() async {
    final prov = context.read<CertificadoProvider>();
    await prov.carregar(widget.cnpjId);
    if (!mounted) return;
    setState(() => _carregandoInicial = false);
  }

  Future<void> _abrirUpload() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CertificadoUploadScreen(cnpjId: widget.cnpjId),
      ),
    );
    // Provider já atualizou state via enviar(); pop(true) só sinaliza UX.
  }

  Future<void> _confirmarRemocao() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remover certificado?'),
        content: const Text(
          'Sem certificado ativo, novas notas fiscais não poderão ser '
          'emitidas até que um novo certificado seja enviado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    if (!mounted) return;
    final provider = context.read<CertificadoProvider>();
    await provider.remover(widget.cnpjId);
    if (!mounted) return;
    final s = provider.state;
    if (s is CertificadoErro) {
      if (s.codigo == 'Certificado.JaRemovido') {
        await provider.carregar(widget.cnpjId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificado já estava removido.'),
            backgroundColor: AppColors.green,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(traduzir(s.codigo, fallback: s.mensagem)),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Certificado removido.'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Certificado'),
        backgroundColor: AppColors.bg,
        elevation: 0,
      ),
      body: SafeArea(
        child: Selector<CertificadoProvider, CertificadoState>(
          selector: (_, p) => p.state,
          builder: (context, state, _) {
            if (_carregandoInicial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CertificadoUploading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is CertificadoErro) {
              return _ErrorState(
                mensagem: traduzir(state.codigo, fallback: state.mensagem),
                onRetry: () {
                  context
                      .read<CertificadoProvider>()
                      .carregar(widget.cnpjId);
                },
              );
            }
            if (state is CertificadoSuccess) {
              return _SuccessContent(
                metadata: state.metadata,
                onSubstituir: () { _abrirUpload(); },
                onRemover: () { _confirmarRemocao(); },
              );
            }
            return _EmptyState(onEnviar: () { _abrirUpload(); });
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onEnviar;
  const _EmptyState({required this.onEnviar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              color: AppColors.textMid,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum certificado enviado.',
              style: TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onEnviar,
                child: const Text(
                  'Enviar certificado',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String mensagem;
  final VoidCallback onRetry;
  const _ErrorState({required this.mensagem, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onRetry,
                child: const Text(
                  'Tentar novamente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  final CertificadoMetadata metadata;
  final VoidCallback onSubstituir;
  final VoidCallback onRemover;

  const _SuccessContent({
    required this.metadata,
    required this.onSubstituir,
    required this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CertificadoStatusCard(metadata: metadata),
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
            onPressed: onSubstituir,
            child: const Text(
              'Substituir certificado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onRemover,
            child: const Text(
              'Remover certificado',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
