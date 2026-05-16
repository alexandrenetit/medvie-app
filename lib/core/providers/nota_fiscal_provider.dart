// lib/core/providers/nota_fiscal_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nota_fiscal.dart';
import '../models/notas_pagina.dart';
import '../services/medvie_api_service.dart';
import '../services/sse_service.dart';

class NotaFiscalProvider extends ChangeNotifier {
  final MedvieApiService _api;
  final SseService Function(MedvieApiService api) _sseFactory;
  final Future<SharedPreferences> Function() _prefsFactory;

  NotaFiscalProvider(
    this._api, {
    SseService Function(MedvieApiService api)? sseFactory,
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _sseFactory = sseFactory ?? ((api) => SseService(api)),
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  /// Chave persistida com o último timestamp UTC de reconciliação bem-sucedida.
  /// Usada para reduzir o intervalo de notas sincronizadas a cada reconexão.
  static const _kPrefUltimaSincronizacao =
      'medvie.nota.ultima_sincronizacao_utc';

  static const _kReconciliacaoTentativasMax = 3;
  static const _kReconciliacaoBackoffInicial = Duration(seconds: 2);

  /// Janela máxima usada quando não há registro local de sincronização.
  /// 24h cobre razoavelmente o pior caso de cliente offline; o índice do
  /// banco filtra por UpdatedAt e o volume é baixo.
  static const _kJanelaSincronizacaoInicial = Duration(hours: 24);

  final List<NotaFiscal> _notas = [];
  int _total = 0;
  int _pagina = 1;
  int _tamanhoPagina = 20;
  bool _carregando = false;
  String? _erro;
  int _carregarRequestId = 0;
  Future<bool>? _sincronizacaoStatus;
  SseService? _sse;
  StreamSubscription<SseConnectionState>? _sseStateSubscription;
  final StreamController<SseConnectionState> _sseStateController =
      StreamController<SseConnectionState>.broadcast();

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  List<NotaFiscal> get notas => List.unmodifiable(_notas);
  int get total => _total;
  int get pagina => _pagina;
  int get tamanhoPagina => _tamanhoPagina;
  bool get temProximaPagina => _notas.length < _total;
  bool get carregando => _carregando;
  String? get erro => _erro;
  MedvieApiService get api => _api;
  Stream<SseConnectionState> get sseState => _sseStateController.stream;

  List<NotaFiscal> notasDoMes(int ano, int mes) =>
      _notas
          .where(
            (n) =>
                n.dataReferencia.year == ano && n.dataReferencia.month == mes,
          )
          .toList()
        ..sort((a, b) => b.dataReferencia.compareTo(a.dataReferencia));

  int countAutorizadasDoMes(int ano, int mes) => notasDoMes(
    ano,
    mes,
  ).where((n) => n.status == StatusNota.autorizada.name).length;

  List<NotaFiscal> porStatus(String status) =>
      _notas.where((n) => n.status == status).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ─────────────────────────────────────────────
  // SSE — atualizações em tempo real
  // ─────────────────────────────────────────────

  void conectarSse() {
    if (_sse != null) return;

    _sse = _sseFactory(_api)
      ..onNotaAtualizada = _onNotaAtualizada
      // Item K7 — reconciliação REST pós-reconexão SSE:
      // o backend só publica o evento Redis após o commit no banco, mas
      // se a instância cair entre o SaveChanges e o PublishAsync o cliente
      // não recebe a notificação. Buscar via REST as notas atualizadas
      // a partir do último sync conhecido garante consistência eventual
      // sem necessidade de mensageria persistente.
      ..onReconciliar = _reconciliarNotas;
    _sseStateSubscription = _sse!.state.listen(_emitirEstadoSse);
    _sse!.conectar();
  }

  void desconectarSse() {
    _sseStateSubscription?.cancel();
    _sseStateSubscription = null;
    _sse?.desconectar();
    _sse = null;
  }

  @override
  void dispose() {
    final sse = _sse;
    desconectarSse();
    sse?.dispose();
    _sseStateController.close();
    super.dispose();
  }

  void _emitirEstadoSse(SseConnectionState state) {
    if (_sseStateController.isClosed) return;
    _sseStateController.add(state);
  }

  void _onNotaAtualizada(Map<String, dynamic> json) {
    final notaId = json['notaId'] as String?;
    final status = json['status'] as String?;
    if (notaId == null || status == null) return;

    final index = _notas.indexWhere((n) => n.id == notaId);
    if (index == -1) return;

    // TODO(backend): incluir updatedAt no payload SSE; fallback mantém versao monotônica.
    final rawUpdatedAt = json['updatedAt'] as String?;
    final updatedAt = rawUpdatedAt != null
        ? DateTime.parse(rawUpdatedAt).toUtc()
        : DateTime.now().toUtc();

    final notaLocal = _notas[index];
    final notaAtualizada = notaLocal.copyWith(
      status: status,
      numeroNfse: json['numeroNfse'] as String?,
      linkPdf: json['linkPdf'] as String?,
      chaveAcesso: json['chaveAcesso'] as String?,
      updatedAt: updatedAt,
    );

    // Guarda de versão (item K7 / seção 2.7 da auditoria):
    // descarta evento SSE antigo que chegue depois de uma atualização mais
    // recente já aplicada via reconciliação REST.
    final versaoEvento =
        (json['versao'] as num?)?.toInt() ?? notaAtualizada.versao;
    final versaoLocal = notaLocal.versao;
    if (versaoEvento > versaoLocal) {
      _notas[index] = notaAtualizada;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Reconciliação pós-reconexão SSE (item K7 — RELATORIOWEBHOOK.md)
  // ─────────────────────────────────────────────

  /// Expõe a reconciliação para testes unitários sem precisar levantar SSE.
  @visibleForTesting
  Future<void> reconciliarNotasParaTeste() => _reconciliarNotas();

  Future<bool> sincronizarStatus() {
    final emAndamento = _sincronizacaoStatus;
    if (emAndamento != null) return emAndamento;

    final future = _sincronizarStatusInterno();
    _sincronizacaoStatus = future;
    unawaited(
      future.whenComplete(() {
        _sincronizacaoStatus = null;
      }),
    );
    return future;
  }

  /// Hook chamado pelo [SseService] após cada conexão estabelecida.
  ///
  /// Estratégia:
  ///   1. Carrega o timestamp da última sincronização persistido.
  ///   2. Faz GET /api/v1/notas/sincronizar?atualizadasDesde={ts}.
  ///   3. Para cada nota retornada, aplica a atualização SOMENTE se a versão
  ///      remota for maior que a versão local — protege contra sobrescrever
  ///      eventos SSE concorrentes mais recentes que tenham chegado durante
  ///      a chamada REST.
  ///   4. Em caso de falha, retenta com backoff exponencial até
  ///      [_kReconciliacaoTentativasMax]. Falhas finais são apenas logadas;
  ///      a próxima reconexão tentará novamente.
  Future<void> _reconciliarNotas() async {
    await sincronizarStatus();
  }

  Future<bool> _sincronizarStatusInterno() async {
    final desde = await _carregarUltimaSincronizacao();
    var tentativa = 0;
    var espera = _kReconciliacaoBackoffInicial;

    while (tentativa < _kReconciliacaoTentativasMax) {
      try {
        final atualizacoes = await _api.sincronizarNotas(desde);
        var alterou = false;

        for (final dto in atualizacoes) {
          final index = _notas.indexWhere((n) => n.id == dto.notaId);
          if (index == -1) continue;

          final notaLocal = _notas[index];
          final atualizacaoMaisRecente = dto.versao != null
              ? dto.versao! > notaLocal.versao
              : dto.dataAtualizacao.isAfter(notaLocal.updatedAt);
          if (!atualizacaoMaisRecente) {
            continue; // evento SSE já trouxe versão mais recente.
          }

          _notas[index] = notaLocal.copyWith(
            status: dto.status,
            updatedAt: dto.dataAtualizacao,
          );
          alterou = true;
        }

        if (alterou) notifyListeners();
        await _persistirUltimaSincronizacao(DateTime.now().toUtc());
        return true;
      } catch (e) {
        tentativa++;
        if (tentativa >= _kReconciliacaoTentativasMax) {
          if (kDebugMode) {
            debugPrint(
              '[RECONCILIACAO] desistindo após $tentativa tentativas: $e',
            );
          }
          return false;
        }
        await Future<void>.delayed(espera);
        espera *= 2;
      }
    }
    return false;
  }

  Future<DateTime> _carregarUltimaSincronizacao() async {
    try {
      final prefs = await _prefsFactory();
      final raw = prefs.getString(_kPrefUltimaSincronizacao);
      if (raw == null) {
        return DateTime.now().toUtc().subtract(_kJanelaSincronizacaoInicial);
      }
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return DateTime.now().toUtc().subtract(_kJanelaSincronizacaoInicial);
    }
  }

  Future<void> _persistirUltimaSincronizacao(DateTime ts) async {
    try {
      final prefs = await _prefsFactory();
      await prefs.setString(
        _kPrefUltimaSincronizacao,
        ts.toUtc().toIso8601String(),
      );
    } catch (_) {
      // Persistência best-effort — falha não interrompe o app.
    }
  }

  // ─────────────────────────────────────────────
  // Carregamento (session-only — sem cache em disco)
  // ─────────────────────────────────────────────

  /// Carrega notas do backend filtrando por [cnpjProprioId] e, opcionalmente,
  /// por [mes]/[ano] de competência. Dados ficam apenas em memória durante a sessão.
  Future<bool> carregar(
    String cnpjProprioId, {
    int? mes,
    int? ano,
    bool silencioso = false,
  }) async {
    final requestId = ++_carregarRequestId;
    _erro = null;
    if (!silencioso) {
      _carregando = true;
      notifyListeners();
    }
    var sucesso = false;

    try {
      DateTime? de;
      DateTime? ate;
      if (mes != null && ano != null) {
        de = DateTime(ano, mes);
        ate = DateTime(ano, mes + 1).subtract(const Duration(days: 1));
      }

      final NotasPagina paginaNotas = await _api.listarNotas(
        cnpjProprioId,
        competenciaDe: de,
        competenciaAte: ate,
        pagina: 1,
        tamanhoPagina: _tamanhoPagina,
      );

      if (requestId != _carregarRequestId) return false;
      _notas
        ..clear()
        ..addAll(paginaNotas.notas);
      _total = paginaNotas.total;
      _pagina = paginaNotas.pagina;
      _tamanhoPagina = paginaNotas.tamanhoPagina;
      sucesso = true;
    } catch (e) {
      if (requestId != _carregarRequestId) return false;
      _erro = e.toString();
    } finally {
      if (requestId == _carregarRequestId) {
        _carregando = false;
        notifyListeners();
      }
    }
    return sucesso;
  }

  // ─────────────────────────────────────────────
  // Mutações
  // ─────────────────────────────────────────────

  /// Cancela uma NFS-e autorizada no backend e recarrega a lista.
  Future<void> cancelar(
    String id,
    String cnpjProprioId,
    String motivo,
    String codigo,
  ) async {
    await _api.cancelarNota(id, cnpjProprioId, motivo, codigo);
    await carregar(cnpjProprioId);
  }

  /// Adiciona uma nota já criada pelo backend à lista local (usada pelo
  /// ServicoProvider após emitirNota bem-sucedido).
  void adicionarNotaLocal(NotaFiscal nota) {
    _notas.add(nota);
    notifyListeners();
  }

  Future<void> atualizarNota(NotaFiscal atualizada) async {
    final index = _notas.indexWhere((n) => n.id == atualizada.id);
    if (index == -1) return;
    _notas[index] = atualizada;
    notifyListeners();
  }

  Future<void> removerNota(String id) => Future<void>.sync(() {
    _notas.removeWhere((n) => n.id == id);
    notifyListeners();
  });

  Future<void> limpar() => Future<void>.sync(() {
    _notas.clear();
    _total = 0;
    _pagina = 1;
    _tamanhoPagina = 20;
    notifyListeners();
  });
}
