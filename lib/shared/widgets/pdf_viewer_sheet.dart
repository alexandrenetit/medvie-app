import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';

class PdfViewerSheet extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() carregar;

  const PdfViewerSheet({
    super.key,
    required this.titulo,
    required this.carregar,
  });

  static Future<void> abrir(
    BuildContext context, {
    required String titulo,
    required Future<Uint8List> Function() carregar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF07090F),
      builder: (_) => PdfViewerSheet(titulo: titulo, carregar: carregar),
    );
  }

  @override
  State<PdfViewerSheet> createState() => _PdfViewerSheetState();
}

class _PdfViewerSheetState extends State<PdfViewerSheet> {
  static const _bg      = Color(0xFF07090F);
  static const _appBar  = Color(0xFF111827);
  static const _green   = Color(0xFF00C98A);

  _Status _status = _Status.loading;
  Uint8List? _bytes;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() { _status = _Status.loading; _erro = null; });
    try {
      final bytes = await widget.carregar();
      if (!mounted) return;
      setState(() { _bytes = bytes; _status = _Status.ok; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _erro = e.toString(); _status = _Status.erro; });
    }
  }

  Future<void> _compartilhar() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final xFile = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: '${widget.titulo.replaceAll(' ', '_')}.pdf',
    );
    await Share.shareXFiles([xFile], subject: widget.titulo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appBar,
        title: Text(
          widget.titulo,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_status == _Status.ok)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: _green),
              onPressed: _compartilhar,
            ),
        ],
      ),
      body: switch (_status) {
        _Status.loading => const Center(
            child: CircularProgressIndicator(color: _green),
          ),
        _Status.erro => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    _erro ?? 'Erro desconhecido',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _carregar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente',
                        style: TextStyle(fontFamily: 'Outfit')),
                  ),
                ],
              ),
            ),
          ),
        _Status.ok => PDFView(
            pdfData: _bytes!,
            fitPolicy: FitPolicy.BOTH,
          ),
      },
    );
  }
}

enum _Status { loading, ok, erro }
