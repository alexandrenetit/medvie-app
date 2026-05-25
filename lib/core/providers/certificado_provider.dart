// lib/core/providers/certificado_provider.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../errors/api_exception.dart';
import '../models/certificado_alerta.dart';
import '../models/certificado_metadata.dart';
import '../services/medvie_api_service.dart';
import '../services/sse_service.dart';

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
///
/// ## Wiring com SSE
///
/// Bind via `ChangeNotifierProxyProvider<SseService, CertificadoProvider>`:
///
/// ```dart
/// ChangeNotifierProxyProvider<SseService, CertificadoProvider>(
///   create: (_) => CertificadoProvider(api),
///   update: (_, sse, prov) => prov!..bindSse(sse),
/// )
/// ```
///
/// [bindSse] é idempotente — ProxyProvider re-chama em cada rebuild da árvore;
/// chamadas com a mesma instância são no-op. Trocar de [SseService] cancela a
/// subscription anterior antes de assinar a nova.
class CertificadoProvider extends ChangeNotifier {
  CertificadoProvider(this._api);

  final MedvieApiService _api;

  CertificadoState _state = const CertificadoIdle();
  CertificadoState get state => _state;

  StreamSubscription<CertificadoAlerta>? _sseSub;
  SseService? _sseAtual;

  /// CNPJ ativo na visão atual — alimenta filtro de alerta e guard de stale.
  String? _cnpjIdAtual;

  /// Flag de fetch em voo — usada como coalesce de burst de alertas.
  bool _carregando = false;

  /// Token monotônico de geração — evita que uma chamada antiga sobrescreva
  /// resultado de uma chamada mais recente (race entre `carregar` concorrentes).
  int _geracao = 0;

  @visibleForTesting
  bool get carregando => _carregando;

  /// Conecta a stream de alertas do [SseService] a este provider. Idempotente.
  ///
  /// - Mesma instância → no-op (segura para `ProxyProvider.update`).
  /// - Instância diferente → cancela subscription anterior antes de assinar nova.
  void bindSse(SseService sse) {
    if (identical(_sseAtual, sse)) return;
    _sseSub?.cancel();
    _sseAtual = sse;
    _sseSub = sse.certificadoAlertas.listen((alerta) {
      unawaited(_onAlerta(alerta));
    });
  }

  Future<void> _onAlerta(CertificadoAlerta alerta) async {
    final atual = _cnpjIdAtual;
    if (atual == null) return; // sem CNPJ ativo
    if (alerta.cnpjProprioId != atual) return; // alerta de outro CNPJ
    if (_carregando) return; // já tem fetch em voo — coalesce burst
    await carregar(atual);
  }

  /// Sincroniza estado a partir do backend. `null` (sem certificado ativo)
  /// é mapeado para [CertificadoIdle] — estado normal, não-erro.
  ///
  /// Race-safe: chamadas concorrentes são protegidas por token [_geracao] — a
  /// resposta de uma chamada antiga é descartada se outra chamada mais recente
  /// já estiver em andamento, garantindo que o `_state` final corresponda ao
  /// último cnpjId solicitado.
  Future<void> carregar(String cnpjId) async {
    final geracao = ++_geracao;
    _cnpjIdAtual = cnpjId;
    _carregando = true;
    notifyListeners();
    debugPrint(
      '[certificado.provider] carregar:start cnpjId=$cnpjId geracao=$geracao',
    );
    try {
      final metadata = await _api.consultarCertificado(cnpjId);
      if (geracao != _geracao) {
        debugPrint(
          '[certificado.provider] carregar:stale cnpjId=$cnpjId '
          'geracao=$geracao atual=$_geracao',
        );
        return;
      }
      _state = metadata == null
          ? const CertificadoIdle()
          : CertificadoSuccess(metadata);
      debugPrint(
        '[certificado.provider] carregar:ok cnpjId=$cnpjId '
        'hasMetadata=${metadata != null}',
      );
    } on ApiException catch (e) {
      if (geracao != _geracao) return; // stale — chamada mais nova em voo
      _state = CertificadoErro(
        e.code ?? 'Erro.Desconhecido',
        e.description ?? 'Falha ao carregar certificado.',
      );
      debugPrint(
        '[certificado.provider] carregar:erro cnpjId=$cnpjId code=${e.code} '
        'statusCode=${e.statusCode}',
      );
    } finally {
      // Só zera a flag de carregamento e notifica se ainda for a chamada
      // mais recente — evita liberar coalesce/notify enquanto outra carga
      // mais nova continua em voo.
      if (geracao == _geracao) {
        _carregando = false;
        notifyListeners();
      }
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
    debugPrint(
      '[certificado.provider] enviar:start cnpjId=$cnpjId '
      'bytesLen=${bytes.length} senhaLen=${senha.length} '
      'restritoAoCnpj=$restritoAoCnpj',
    );
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
      debugPrint(
        '[certificado.provider] enviar:success cnpjId=$cnpjId '
        'status=${metadata.status} subjectCnpj=${metadata.subjectCnpj} '
        'validUntil=${metadata.validUntil} '
        'fingerprint=${metadata.fingerprintSha256.substring(0, 8)}',
      );
    } on ApiException catch (e) {
      _state = CertificadoErro(
        e.code ?? 'Erro.Desconhecido',
        e.description ?? 'Falha ao enviar certificado.',
      );
      debugPrint(
        '[certificado.provider] enviar:erro cnpjId=$cnpjId code=${e.code} '
        'description=${e.description} statusCode=${e.statusCode}',
      );
    } finally {
      notifyListeners();
    }
  }

  /// Remove certificado ativo. Sucesso volta para [CertificadoIdle].
  /// `Certificado.JaRemovido` (409) é exposto como erro — UI decide se trata
  /// como idempotente ou exibe mensagem.
  Future<void> remover(String cnpjId) async {
    debugPrint('[certificado.provider] remover:start cnpjId=$cnpjId');
    try {
      await _api.removerCertificado(cnpjId);
      _state = const CertificadoIdle();
      debugPrint('[certificado.provider] remover:ok cnpjId=$cnpjId');
    } on ApiException catch (e) {
      _state = CertificadoErro(
        e.code ?? 'Erro.Desconhecido',
        e.description ?? 'Falha ao remover certificado.',
      );
      debugPrint(
        '[certificado.provider] remover:erro cnpjId=$cnpjId code=${e.code} '
        'statusCode=${e.statusCode}',
      );
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _sseSub = null;
    _sseAtual = null;
    super.dispose();
  }
}
