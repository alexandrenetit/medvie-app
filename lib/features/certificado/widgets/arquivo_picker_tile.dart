// lib/features/certificado/widgets/arquivo_picker_tile.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/// Callback invocado quando o usuário seleciona um arquivo PFX/P12 válido.
///
/// Contrato com o caller:
/// - Repassar [bytes] imediatamente ao `CertificadoProvider.enviar` (que delega
///   ao service que zera bytes em `finally`).
/// - NÃO armazenar [bytes] em campo de estado de longa duração.
/// - Liberar a referência (`bytes = null`) após a chamada ao provider.
typedef ArquivoPickerOnPicked = void Function(
  Uint8List bytes,
  String fileName,
  int sizeBytes,
);

/// Tile de seleção de arquivo PFX/P12 para upload de certificado digital A1.
///
/// Regras:
/// - Extensões aceitas: apenas `pfx` e `p12` (filtro nativo do `file_picker`).
/// - Tamanho máximo configurável (default 5 MB). Certificados A1 raramente
///   passam de 10 KB; o cap evita upload acidental de arquivos errados.
/// - Bytes NUNCA são armazenados em campo deste widget — apenas repassados via
///   [onPicked] e saem de escopo (GC). O caller é dono do ciclo de vida.
/// - Reentrante: enquanto um `pickFiles` está em voo, taps adicionais são
///   ignorados (`_picking` guard).
/// - Erros user-facing (cancelamento, falha de plataforma, tamanho excedido)
///   são emitidos via [onErro] — UI hospedeira decide como exibir (SnackBar).
class ArquivoPickerTile extends StatefulWidget {
  final ArquivoPickerOnPicked onPicked;
  final ValueChanged<String>? onErro;
  final int maxBytes;
  final String labelVazio;

  const ArquivoPickerTile({
    super.key,
    required this.onPicked,
    this.onErro,
    this.maxBytes = 5 * 1024 * 1024,
    this.labelVazio = 'Selecionar certificado (.pfx/.p12)',
  });

  @override
  State<ArquivoPickerTile> createState() => _ArquivoPickerTileState();
}

class _ArquivoPickerTileState extends State<ArquivoPickerTile> {
  bool _picking = false;
  String? _selectedName;
  int? _selectedSize;

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pfx', 'p12'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return; // cancelado

      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        widget.onErro?.call('Não foi possível ler o arquivo.');
        return;
      }
      if (bytes.length > widget.maxBytes) {
        final maxMb = (widget.maxBytes / (1024 * 1024)).toStringAsFixed(0);
        widget.onErro?.call('Arquivo excede ${maxMb}MB.');
        return;
      }
      if (mounted) {
        setState(() {
          _selectedName = f.name;
          _selectedSize = bytes.length;
        });
      }
      widget.onPicked(bytes, f.name, bytes.length);
    } on PlatformException catch (e) {
      widget.onErro?.call('Falha ao abrir seletor: ${e.code}');
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selecionado = _selectedName != null;
    final corFundo = selecionado
        ? AppColors.green.withValues(alpha: 0.08)
        : AppColors.surface;
    final corBorda = selecionado
        ? AppColors.green.withValues(alpha: 0.45)
        : AppColors.border;

    return InkWell(
      onTap: _picking ? null : () { _pick(); },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: corFundo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: corBorda),
        ),
        child: Row(
          children: [
            Icon(
              selecionado ? Icons.description : Icons.upload_file,
              color: selecionado ? AppColors.green : AppColors.textMid,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedName ?? widget.labelVazio,
                    style: TextStyle(
                      color: selecionado ? AppColors.text : AppColors.textMid,
                      fontSize: 14,
                      fontWeight:
                          selecionado ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_selectedSize != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatBytes(_selectedSize!),
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _picking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.green),
                    ),
                  )
                : Icon(
                    selecionado ? Icons.check_circle : Icons.arrow_forward_ios,
                    color: selecionado ? AppColors.green : AppColors.textDim,
                    size: selecionado ? 20 : 16,
                  ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}
