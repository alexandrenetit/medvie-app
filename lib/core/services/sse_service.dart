// lib/core/services/sse_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'medvie_api_service.dart';

typedef NotaAtualizadaCallback = void Function(Map<String, dynamic> json);
typedef SseForbiddenCallback = void Function();

enum SseConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  error,
  forbidden,
  rateLimited,
}

class SseService with WidgetsBindingObserver {
  final MedvieApiService api;
  final http.Client Function() _clientFactory;
  NotaAtualizadaCallback? onNotaAtualizada;
  SseForbiddenCallback? onForbidden;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _ativo = false;
  bool _suspended = false;
  bool _observando = false;
  bool _disposed = false;
  int _falhasRefresh = 0;
  int _backoffSegundos = 1;
  final StreamController<SseConnectionState> _stateController =
      StreamController<SseConnectionState>.broadcast();
  static const int _backoffMax = 60;
  static const int _refreshFalhasMax = 3;

  // A-04: watchdog para reconexÃ£o silenciosa apÃ³s ausÃªncia de dados.
  Timer? _watchdog;
  static const _kWatchdogTimeout = Duration(seconds: 45);
  static const _kHandshakeTimeout = Duration(seconds: 15);

  SseService(this.api, {http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  Stream<SseConnectionState> get state => _stateController.stream;

  void conectar() {
    if (_disposed) return;
    _ativo = true;
    _backoffSegundos = 1;
    unawaited(_iniciarConexao());
  }

  // Reinicia o temporizador de watchdog a cada chunk recebido.
  void _resetWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_kWatchdogTimeout, () {
      if (!_ativo) return;
      _subscription?.cancel();
      _subscription = null;
      _client?.close();
      _iniciarConexao();
    });
  }

  Future<void> _iniciarConexao() async {
    if (!_ativo) return;
    _emitirEstado(SseConnectionState.connecting);
    if (!_observando) {
      WidgetsBinding.instance.addObserver(this);
      _observando = true;
    }

    if (!await _garantirTokenValido()) {
      _agendarReconexao();
      return;
    }
    final token = api.accessToken;
    if (token == null || token.isEmpty) {
      _registrarFalhaRefresh();
      _agendarReconexao();
      return;
    }

    _watchdog?.cancel();
    _watchdog = null;
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = _clientFactory();

    try {
      final request = http.Request(
        'GET',
        Uri.parse('${api.baseUrl}/api/v1/notas/eventos'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';
      request.headers['Connection'] = 'keep-alive';

      final response = await _client!.send(request).timeout(_kHandshakeTimeout);

      if (response.statusCode != 200) {
        _client?.close();
        await _tratarStatusErro(response);
        return;
      }

      // ConexÃ£o estabelecida: resetar backoff e iniciar watchdog.
      _backoffSegundos = 1;
      _falhasRefresh = 0;
      _emitirEstado(SseConnectionState.connected);
      _resetWatchdog();

      final buffer = StringBuffer();

      _subscription = response.stream
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              _resetWatchdog(); // mantÃ©m watchdog vivo com cada chunk
              buffer.write(chunk);
              _processarBuffer(buffer);
            },
            onDone: () => _agendarReconexao(marcarErro: true),
            onError: (_) => _agendarReconexao(marcarErro: true),
            cancelOnError: true,
          );
    } on TimeoutException {
      _client?.close();
      _agendarReconexao(marcarErro: true);
      return;
    } catch (_) {
      _agendarReconexao(marcarErro: true);
    }
  }

  Future<void> _tratarStatusErro(http.StreamedResponse response) async {
    switch (response.statusCode) {
      case 401:
        if (await _refreshAccessToken()) {
          await _iniciarConexao();
        } else {
          _agendarReconexao();
        }
        return;
      case 403:
        _marcarForbidden();
        return;
      case 429:
        _emitirEstado(SseConnectionState.rateLimited);
        _agendarReconexao(
          delayOverride: _retryAfter(response.headers['retry-after']),
        );
        return;
      default:
        _agendarReconexao(marcarErro: true);
    }
  }

  Future<bool> _garantirTokenValido() async {
    final token = api.accessToken;
    if (token != null && token.isNotEmpty && !_jwtExpirando(token)) return true;
    return _refreshAccessToken();
  }

  Future<bool> _refreshAccessToken() async {
    try {
      await api.refreshAccessToken();
      _falhasRefresh = 0;
      return true;
    } catch (_) {
      _registrarFalhaRefresh();
      return false;
    }
  }

  void _registrarFalhaRefresh() {
    _falhasRefresh++;
    if (_falhasRefresh >= _refreshFalhasMax) _marcarForbidden();
  }

  bool _jwtExpirando(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return true;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is! num) return true;
      final expiraEm = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
      return expiraEm.isBefore(
        DateTime.now().toUtc().add(const Duration(seconds: 60)),
      );
    } catch (_) {
      return true;
    }
  }

  Duration _retryAfter(String? header) {
    final seconds = int.tryParse(header ?? '');
    if (seconds != null && seconds > 0) return Duration(seconds: seconds);
    if (header != null) {
      final date = DateTime.tryParse(header);
      if (date != null) {
        final delay = date.toUtc().difference(DateTime.now().toUtc());
        if (!delay.isNegative) return delay;
      }
    }
    return Duration(seconds: _backoffSegundos);
  }

  void _agendarReconexao({Duration? delayOverride, bool marcarErro = false}) {
    if (!_ativo) return;
    if (marcarErro) _emitirEstado(SseConnectionState.error);
    final delay = delayOverride ?? _backoffComJitter();
    if (delayOverride == null) {
      _backoffSegundos = (_backoffSegundos * 2).clamp(1, _backoffMax);
    }
    Future.delayed(delay, () {
      if (!_ativo || _disposed || _stateController.isClosed) return;
      _emitirEstado(SseConnectionState.reconnecting);
      unawaited(_iniciarConexao());
    });
  }

  Duration _backoffComJitter() {
    final base = _backoffSegundos;
    final jitter = Random().nextInt(base + 1);
    final delay = (base + jitter).clamp(1, 120).toInt();
    return Duration(seconds: delay);
  }

  void _processarBuffer(StringBuffer buffer) {
    final texto = buffer.toString();
    // Eventos SSE sÃ£o separados por linha em branco (\n\n)
    final partes = texto.split('\n\n');

    // A Ãºltima parte pode estar incompleta; preservar no buffer
    buffer.clear();
    buffer.write(partes.last);

    for (int i = 0; i < partes.length - 1; i++) {
      _processarEvento(partes[i]);
    }
  }

  void _processarEvento(String bloco) {
    String? dataLine;
    for (final linha in bloco.split('\n')) {
      if (linha.startsWith('data:')) {
        dataLine = linha.substring(5).trim();
        break;
      }
    }
    if (dataLine == null || dataLine.isEmpty) return;

    try {
      final json = jsonDecode(dataLine) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'ping') return;

      if (type == 'nota_atualizada') {
        if (json['notaId'] is! String || json['status'] is! String) return;
        onNotaAtualizada?.call(json);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_suspended) return;
        _backoffSegundos = 1;
        _suspended = false;
        conectar();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_ativo) return;
        _suspended = true;
        _fecharConexao(removerObserver: false);
        return;
    }
  }

  void desconectar() {
    _suspended = false;
    _fecharConexao(removerObserver: true);
    _emitirEstado(SseConnectionState.idle);
  }

  void dispose() {
    _disposed = true;
    _suspended = false;
    _fecharConexao(removerObserver: true);
    if (!_stateController.isClosed) {
      unawaited(_stateController.close());
    }
  }

  void _marcarForbidden() {
    _ativo = false;
    _emitirEstado(SseConnectionState.forbidden);
    onForbidden?.call();
  }

  void _emitirEstado(SseConnectionState state) {
    if (_stateController.isClosed) return;
    _stateController.add(state);
  }

  void _fecharConexao({required bool removerObserver}) {
    _ativo = false;
    _watchdog?.cancel();
    _watchdog = null;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    if (removerObserver && _observando) {
      WidgetsBinding.instance.removeObserver(this);
      _observando = false;
    }
  }
}
