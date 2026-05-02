// lib/core/services/sse_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

typedef NotaAtualizadaCallback = void Function(String notaId, String status);

class SseService {
  final String baseUrl;
  NotaAtualizadaCallback? onNotaAtualizada;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  bool _ativo = false;
  int _backoffSegundos = 1;
  static const int _backoffMax = 60;

  // A-04: watchdog para reconexão silenciosa após ausência de dados.
  Timer? _watchdog;
  static const _kWatchdogTimeout = Duration(seconds: 45);

  SseService(this.baseUrl);

  Future<void> conectar(String token) async {
    _ativo = true;
    _backoffSegundos = 1;
    await _iniciarConexao(token);
  }

  // Reinicia o temporizador de watchdog a cada chunk recebido.
  void _resetWatchdog(String token) {
    _watchdog?.cancel();
    _watchdog = Timer(_kWatchdogTimeout, () {
      if (!_ativo) return;
      _subscription?.cancel();
      _subscription = null;
      _client?.close();
      _iniciarConexao(token);
    });
  }

  Future<void> _iniciarConexao(String token) async {
    if (!_ativo) return;

    _client?.close();
    _client = http.Client();

    try {
      final request = http.Request(
        'GET',
        Uri.parse('$baseUrl/api/v1/notas/eventos'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        _client?.close();
        _agendarReconexao(token);
        return;
      }

      // Conexão estabelecida: resetar backoff e iniciar watchdog.
      _backoffSegundos = 1;
      _resetWatchdog(token);

      final buffer = StringBuffer();

      _subscription = response.stream
          .transform(utf8.decoder)
          .listen(
        (chunk) {
          _resetWatchdog(token); // mantém watchdog vivo com cada chunk
          buffer.write(chunk);
          _processarBuffer(buffer);
        },
        onDone: () => _agendarReconexao(token),
        onError: (_) => _agendarReconexao(token),
        cancelOnError: true,
      );
    } catch (_) {
      _agendarReconexao(token);
    }
  }

  void _processarBuffer(StringBuffer buffer) {
    final texto = buffer.toString();
    // Eventos SSE são separados por linha em branco (\n\n)
    final partes = texto.split('\n\n');

    // A última parte pode estar incompleta; preservar no buffer
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
        final notaId = json['notaId'] as String?;
        final status = json['status'] as String?;
        if (notaId != null && status != null) {
          onNotaAtualizada?.call(notaId, status);
        }
      }
    } catch (_) {}
  }

  void _agendarReconexao(String token) {
    if (!_ativo) return;
    final delay = _backoffSegundos;
    _backoffSegundos = (_backoffSegundos * 2).clamp(1, _backoffMax);
    Future.delayed(Duration(seconds: delay), () => _iniciarConexao(token));
  }

  void desconectar() {
    _ativo = false;
    _watchdog?.cancel();
    _watchdog = null;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }
}
