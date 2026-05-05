// test/services/sse_service_test.dart
//
// Testes unitários do SseService.
// Cobre: parsing de eventos (nota_atualizada, ping, JSON inválido,
// campos ausentes), parsing de buffer (evento incompleto, múltiplos eventos),
// lifecycle (desconectar, HTTP não-200).

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/core/services/sse_service.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockClient extends Mock implements http.Client {}

class _MockApi extends Mock implements MedvieApiService {}

// ── Helpers ───────────────────────────────────────────────────────────────────

List<int> _sseChunk(Map<String, dynamic> json) =>
    utf8.encode('data: ${jsonEncode(json)}\n\n');

List<int> _rawChunk(String text) => utf8.encode(text);

String _jwtExp(int secondsFromNow) {
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({
      'exp': DateTime.now()
              .toUtc()
              .add(Duration(seconds: secondsFromNow))
              .millisecondsSinceEpoch ~/
          1000,
    })),
  ).replaceAll('=', '');
  return 'header.$payload.signature';
}

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      http.Request('GET', Uri.parse('http://localhost')),
    );
  });

  late _MockClient mockClient;
  late _MockApi mockApi;
  late SseService svc;
  late StreamController<List<int>> controller;

  setUp(() {
    mockClient = _MockClient();
    mockApi = _MockApi();
    when(() => mockClient.close()).thenReturn(null);
    when(() => mockApi.baseUrl).thenReturn('http://api.test');
    when(() => mockApi.accessToken).thenReturn(_jwtExp(3600));
    when(() => mockApi.refreshAccessToken()).thenAnswer((_) async {});
    svc = SseService(mockApi, clientFactory: () => mockClient);
    controller = StreamController<List<int>>();
  });

  tearDown(() {
    svc.desconectar();
    if (!controller.isClosed) controller.close();
  });

  // Conecta o serviço com o stream do controller.
  Future<void> connect() async {
    when(() => mockClient.send(any())).thenAnswer((_) async =>
        http.StreamedResponse(controller.stream, 200));
    svc.conectar();
    await Future.delayed(Duration.zero);
  }

  // Envia chunks e aguarda o event loop processar.
  Future<void> send(List<int> chunk) async {
    controller.add(chunk);
    await Future.delayed(Duration.zero);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Parsing de eventos
  // ════════════════════════════════════════════════════════════════════════════

  group('parsing de eventos', () {
    test('nota_atualizada → callback com notaId e status corretos', () async {
      await connect();

      String? capturedId, capturedStatus;
      svc.onNotaAtualizada = (json) {
        capturedId = json['notaId'] as String?;
        capturedStatus = json['status'] as String?;
      };

      await send(_sseChunk({
        'type': 'nota_atualizada',
        'notaId': 'nf-001',
        'status': 'autorizada',
      }));

      expect(capturedId, 'nf-001');
      expect(capturedStatus, 'autorizada');
    });

    test('ping → callback não é disparado', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      await send(_sseChunk({'type': 'ping'}));

      expect(calls, 0);
    });

    test('JSON inválido → sem crash, callback não disparado', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      await send(_rawChunk('data: {isso nao e json}\n\n'));

      expect(calls, 0);
    });

    test('type ausente → callback não disparado', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      await send(_sseChunk({'notaId': 'nf-001', 'status': 'autorizada'}));

      expect(calls, 0);
    });

    test('notaId null → callback não disparado', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      await send(_sseChunk({
        'type': 'nota_atualizada',
        'notaId': null,
        'status': 'autorizada',
      }));

      expect(calls, 0);
    });

    test('status null → callback não disparado', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      await send(_sseChunk({
        'type': 'nota_atualizada',
        'notaId': 'nf-001',
        'status': null,
      }));

      expect(calls, 0);
    });

    test('bloco sem linha data: → callback não disparado', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      await send(_rawChunk('event: nota_atualizada\nid: 123\n\n'));

      expect(calls, 0);
    });

    test('linha data: vazia → callback não disparado', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      await send(_rawChunk('data: \n\n'));

      expect(calls, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Parsing de buffer
  // ════════════════════════════════════════════════════════════════════════════

  group('parsing de buffer', () {
    test('chunk sem \\n\\n → evento incompleto, callback não disparado',
        () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      // Chunk sem \n\n final — evento incompleto
      await send(_rawChunk(
          'data: {"type":"nota_atualizada","notaId":"nf-01","status":"autorizada"}'));

      expect(calls, 0);
    });

    test('dois eventos em um chunk → ambos processados', () async {
      await connect();

      final received = <String>[];
      svc.onNotaAtualizada = (json) => received.add(json['notaId'] as String);

      // Dois eventos completos em um único chunk
      final chunk = utf8.encode(
        'data: {"type":"nota_atualizada","notaId":"nf-A","status":"autorizada"}\n\n'
        'data: {"type":"nota_atualizada","notaId":"nf-B","status":"rejeitada"}\n\n',
      );
      await send(chunk);

      expect(received, ['nf-A', 'nf-B']);
    });

    test('evento fragmentado em dois chunks → processado após completar',
        () async {
      await connect();

      String? capturedId;
      svc.onNotaAtualizada = (json) => capturedId = json['notaId'] as String?;

      // Primeiro chunk: metade do evento
      await send(_rawChunk(
          'data: {"type":"nota_atualizada","notaId":"nf-99"'));

      expect(capturedId, isNull); // ainda incompleto

      // Segundo chunk: completa o evento
      await send(_rawChunk(',"status":"cancelada"}\n\n'));

      expect(capturedId, 'nf-99');
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ════════════════════════════════════════════════════════════════════════════

  group('lifecycle', () {
    test('desconectar() cancela recebimento de eventos', () async {
      await connect();

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      svc.desconectar();

      // Evento enviado após desconectar não deve chegar
      controller.add(_sseChunk({
        'type': 'nota_atualizada',
        'notaId': 'nf-X',
        'status': 'autorizada',
      }));
      await Future.delayed(Duration.zero);

      expect(calls, 0);
    });

    test('HTTP não-200 → sem crash, sem callback', () async {
      when(() => mockClient.send(any())).thenAnswer((_) async =>
          http.StreamedResponse(const Stream.empty(), 403));

      int calls = 0;
      svc.onNotaAtualizada = (_) => calls++;

      // Não deve lançar exceção
      svc.conectar();
      await Future.delayed(Duration.zero);
      expect(calls, 0);
    });

    test('cabeçalhos Authorization e Accept enviados corretamente', () async {
      when(() => mockClient.send(any())).thenAnswer((_) async =>
          http.StreamedResponse(controller.stream, 200));

      const token = 'meu-token-jwt';
      when(() => mockApi.accessToken).thenReturn(token);

      svc.conectar();
      await Future.delayed(Duration.zero);

      final captured =
          verify(() => mockClient.send(captureAny())).captured.first
              as http.BaseRequest;
      expect(captured.headers['Authorization'], 'Bearer $token');
      expect(captured.headers['Accept'], 'text/event-stream');
    });

    test('handshake timeout reagenda reconexao', () {
      fakeAsync((async) {
        final pending = Completer<http.StreamedResponse>();
        when(() => mockClient.send(any())).thenAnswer((_) => pending.future);

        svc.conectar();
        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        verify(() => mockClient.send(any())).called(2);
      });
    });
  });

  group('state', () {
    test('200 com handshake ok emite connecting e connected', () async {
      final states = <SseConnectionState>[];
      final sub = svc.state.listen(states.add);

      await connect();

      expect(states, [
        SseConnectionState.connecting,
        SseConnectionState.connected,
      ]);

      await sub.cancel();
    });

    test('timeout emite error e reconnecting apos delay', () {
      fakeAsync((async) {
        final states = <SseConnectionState>[];
        final pending = Completer<http.StreamedResponse>();
        final sub = svc.state.listen(states.add);
        when(() => mockClient.send(any())).thenAnswer((_) => pending.future);

        svc.conectar();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(
          states,
          containsAllInOrder([
            SseConnectionState.connecting,
            SseConnectionState.error,
            SseConnectionState.reconnecting,
          ]),
        );

        sub.cancel();
      });
    });

    test(
      '429 emite rateLimited e respeita Retry-After antes de reconnecting',
      () {
        fakeAsync((async) {
          final states = <SseConnectionState>[];
          final sub = svc.state.listen(states.add);
          when(() => mockClient.send(any())).thenAnswer(
            (_) async => http.StreamedResponse(
              const Stream.empty(),
              429,
              headers: {'retry-after': '2'},
            ),
          );

          svc.conectar();
          async.flushMicrotasks();
          expect(states, contains(SseConnectionState.rateLimited));
          expect(states, isNot(contains(SseConnectionState.reconnecting)));

          async.elapse(const Duration(seconds: 2));
          async.flushMicrotasks();

          expect(states, contains(SseConnectionState.reconnecting));

          sub.cancel();
        });
      },
    );

    test('403 emite forbidden', () async {
      final states = <SseConnectionState>[];
      final sub = svc.state.listen(states.add);
      when(() => mockClient.send(any())).thenAnswer(
        (_) async => http.StreamedResponse(const Stream.empty(), 403),
      );

      svc.conectar();
      await Future.delayed(Duration.zero);

      expect(
        states,
        containsAllInOrder([
          SseConnectionState.connecting,
          SseConnectionState.forbidden,
        ]),
      );

      await sub.cancel();
    });

    test('refresh falhando repetidamente emite forbidden', () {
      fakeAsync((async) {
        final states = <SseConnectionState>[];
        final sub = svc.state.listen(states.add);
        when(() => mockApi.accessToken).thenReturn('');
        when(() => mockApi.refreshAccessToken()).thenThrow(Exception('fail'));

        svc.conectar();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(states, contains(SseConnectionState.forbidden));

        sub.cancel();
      });
    });

    test('desconectar emite idle e fecha stream de state', () async {
      final expectation = expectLater(
        svc.state,
        emitsInOrder([SseConnectionState.idle, emitsDone]),
      );

      svc.desconectar();

      await expectation;
    });
  });
}
