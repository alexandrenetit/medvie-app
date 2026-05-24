// lib/core/providers/certificado_provider.dart

import 'package:flutter/foundation.dart';

import '../errors/api_exception.dart';
import '../models/certificado_metadata.dart';
import '../services/medvie_api_service.dart';

/// Estado público do certificado A1 gerenciado pelo [CertificadoProvider].
///
/// Renomeado com prefixo `Certificado` para evitar colisão de nomes com
/// `dart:core.Error` e classes do framework que importadores possam ter
/// em escopo.
sealed class CertificadoState {
  const CertificadoState();
}

class CertificadoIdle extends CertificadoState {
  const CertificadoIdle();
}

class CertificadoUploading extends CertificadoState {
  const CertificadoUploading();
}

class CertificadoSuccess extends CertificadoState {
  final CertificadoMetadata metadata;
  const CertificadoSuccess(this.metadata);
}

class CertificadoErro extends CertificadoState {
  final String codigo;
  final String mensagem;
  const CertificadoErro(this.codigo, this.mensagem);
}

/// Provider isolado do domínio Certificado Digital A1.
///
/// Regras invioláveis:
/// - ZERO dependência de outros providers (NotaFiscal/Onboarding/Dashboard).
/// - Tradução de `codigo` → mensagem PT-BR é responsabilidade da camada de UI
///   via `certificado_error_codes.traduzir`. Aqui apenas propagamos o código e
///   a description original retornada pelo backend.
/// - `senha` e `bytes` nunca são logados (delegado ao service).
class CertificadoProvider extends ChangeNotifier {
  CertificadoProvider(this._api);

  final MedvieApiService _api;

  CertificadoState _state = const CertificadoIdle();
  CertificadoState get state => _state;

  /// Sincroniza estado a partir do backend. `null` (sem certificado ativo)
  /// é mapeado para [CertificadoIdle] — estado normal, não-erro.
  Future<void> carregar(String cnpjId) async {
    try {
      final metadata = await _api.consultarCertificado(cnpjId);
      _state = metadata == null
          ? const CertificadoIdle()
          : CertificadoSuccess(metadata);
    } on ApiException catch (e) {
      _state = CertificadoErro(
        e.code ?? 'Erro.Desconhecido',
        e.description ?? 'Falha ao carregar certificado.',
      );
    } finally {
      notifyListeners();
    }
  }

  /// Envia certificado A1. Transições: `Idle/Success/Erro → Uploading → Success/Erro`.
  /// O service zera `bytes` ao final (best-effort) — ver `uploadCertificado`.
  Future<void> enviar(
    String cnpjId,
    Uint8List bytes,
    String senha,
    bool restritoAoCnpj,
  ) async {
    _state = const CertificadoUploading();
    notifyListeners();
    try {
      final metadata = await _api.uploadCertificado(
        cnpjId,
        bytes,
        senha,
        restritoAoCnpj,
      );
      _state = CertificadoSuccess(metadata);
    } on ApiException catch (e) {
      _state = CertificadoErro(
        e.code ?? 'Erro.Desconhecido',
        e.description ?? 'Falha ao enviar certificado.',
      );
    } finally {
      notifyListeners();
    }
  }

  /// Remove certificado ativo. Sucesso volta para [CertificadoIdle].
  /// `Certificado.JaRemovido` (409) é exposto como erro — UI decide se trata
  /// como idempotente ou exibe mensagem.
  Future<void> remover(String cnpjId) async {
    try {
      await _api.removerCertificado(cnpjId);
      _state = const CertificadoIdle();
    } on ApiException catch (e) {
      _state = CertificadoErro(
        e.code ?? 'Erro.Desconhecido',
        e.description ?? 'Falha ao remover certificado.',
      );
    } finally {
      notifyListeners();
    }
  }
}
