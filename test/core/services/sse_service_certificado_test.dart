// test/core/services/sse_service_certificado_test.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medvie/core/models/certificado_alerta.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/core/services/sse_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements MedvieApiService {}

class _MockHttpClient extends Mock implements http.Client {}

class _FakeBaseRequest extends Fake implements http.BaseRequest {}

/// JWT com `exp` no ano ~2286 — sempre válido para `_jwtExpirando`.
const _kJwtValido =
    'h.eyJleHAiOjk5OTk5OTk5OTl9.s';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBaseRequest());
  });

  group('CertificadoAlerta.fromJson', () {
    test('payload válido com sufixo Z → DateTime.isUtc == true', () {
      final a = CertificadoAlerta.fromJson({
        'cnpjProprioId': 'abc-123',
        'diasRestantes': 7,
        'recebidoEm': '2026-05-24T13:45:21Z',
      });
      expect(a.cnpjProprioId, 'abc-123');
      expect(a.diasRestantes, 7);
      expect(a.recebidoEm.isUtc, isTrue);
      expect(a.recebidoEm.year, 2026);
    });

    test('payload válido com offset +00:00 → isUtc == true', () {
      // DateTime.parse trata "+00:00" como UTC.
      final a = CertificadoAlerta.fromJson({
        'cnpjProprioId': 'abc',
        'diasRestantes': 30,
        'recebidoEm': '2026-05-24T13:45:21+00:00',
      });
      expect(a.recebidoEm.isUtc, isTrue);
    });

    test('payload sem timezone → ArgumentError (não-UTC rejeitado)', () {
      expect(
        () => CertificadoAlerta.fromJson({
          'cnpjProprioId': 'abc',
          'diasRestantes': 7,
          'recebidoEm': '2026-05-24T13:45:21',
        }),
        throwsArgumentError,
      );
    });

    test('cnpjProprioId ausente → ArgumentError', () {
      expect(
        () => CertificadoAlerta.fromJson({
          'diasRestantes': 7,
          'recebidoEm': '2026-05-24T13:45:21Z',
        }),
        throwsArgumentError,
      );
    });

    test('cnpjProprioId vazio → ArgumentError', () {
      expect(
        () => CertificadoAlerta.fromJson({
          'cnpjProprioId': '',
          'diasRestantes': 7,
          'recebidoEm': '2026-05-24T13:45:21Z',
        }),
        throwsArgumentError,
      );
    });

    test('diasRestantes ausente → ArgumentError', () {
      expect(
        () => CertificadoAlerta.fromJson({
          'cnpjProprioId': 'abc',
          'recebidoEm': '2026-05-24T13:45:21Z',
        }),
        throwsArgumentError,
      );
    });

    test('diasRestantes tipo errado (String) → ArgumentError', () {
      expect(
        () => CertificadoAlerta.fromJson({
          'cnpjProprioId': 'abc',
          'diasRestantes': '7',
          'recebidoEm': '2026-05-24T13:45:21Z',
        }),
        throwsArgumentError,
      );
    });

    test('diasRestantes negativo aceito (semântica fica com backend)', () {
      final a = CertificadoAlerta.fromJson({
        'cnpjProprioId': 'abc',
        'diasRestantes': -5,
        'recebidoEm': '2026-05-24T13:45:21Z',
      });
      expect(a.diasRestantes, -5);
    });

    test('toJson round-trip preserva campos', () {
      final original = CertificadoAlerta(
        cnpjProprioId: 'xyz',
        diasRestantes: 0,
        recebidoEm: DateTime.utc(2026, 5, 24, 13, 45, 21),
      );
      final round = CertificadoAlerta.fromJson(original.toJson());
      expect(round.cnpjProprioId, original.cnpjProprioId);
      expect(round.diasRestantes, original.diasRestantes);
      expect(round.recebidoEm, original.recebidoEm);
    });
  });

  group('SseService parse certificado_alerta', () {
    late _MockApi api;
    late _MockHttpClient client;
    late StreamController<List<int>> wire;
    late SseService sse;

    setUpAll(() {
      // SseService usa WidgetsBinding.instance.addObserver — exige binding.
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      api = _MockApi();
      client = _MockHttpClient();
      wire = StreamController<List<int>>();

      when(() => api.accessToken).thenReturn(_kJwtValido);
      when(() => api.baseUrl).thenReturn('http://test.local');
      when(() => api.refreshAccessToken()).thenAnswer((_) async => null);
      when(() => client.send(any())).thenAnswer(
        (_) async => http.StreamedResponse(wire.stream, 200),
      );
      when(() => client.close()).thenAnswer((_) {});

      sse = SseService(api, clientFactory: () => client);
    });

    tearDown(() async {
      sse.dispose();
      if (!wire.isClosed) await wire.close();
    });

    Future<void> pump() async {
      // Permite que o handshake e o decoder de utf8 propaguem.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('payload válido → emite CertificadoAlerta na stream', () async {
      final eventos = <CertificadoAlerta>[];
      sse.certificadoAlertas.listen(eventos.add);

      sse.conectar();
      await pump();

      wire.add(utf8.encode(
        'data: {"type":"certificado_alerta",'
        '"cnpjProprioId":"abc-123",'
        '"diasRestantes":7,'
        '"recebidoEm":"2026-05-24T13:45:21Z"}\n\n',
      ));
      await pump();

      expect(eventos, hasLength(1));
      expect(eventos.first.cnpjProprioId, 'abc-123');
      expect(eventos.first.diasRestantes, 7);
      expect(eventos.first.recebidoEm.isUtc, isTrue);
    });

    test('payload com JSON inválido → não emite, não lança', () async {
      final eventos = <CertificadoAlerta>[];
      sse.certificadoAlertas.listen(eventos.add);

      sse.conectar();
      await pump();

      wire.add(utf8.encode('data: {"type":"certificado_alerta","faltam":"campos"}\n\n'));
      wire.add(utf8.encode('data: {not even json\n\n'));
      await pump();

      expect(eventos, isEmpty);
    });

    test('tipo desconhecido → não emite em certificadoAlertas', () async {
      final eventos = <CertificadoAlerta>[];
      sse.certificadoAlertas.listen(eventos.add);

      sse.conectar();
      await pump();

      wire.add(utf8.encode('data: {"type":"foo_desconhecido"}\n\n'));
      await pump();

      expect(eventos, isEmpty);
    });

    test('eventos consecutivos → emite na ordem', () async {
      final eventos = <CertificadoAlerta>[];
      sse.certificadoAlertas.listen(eventos.add);

      sse.conectar();
      await pump();

      wire.add(utf8.encode(
        'data: {"type":"certificado_alerta",'
        '"cnpjProprioId":"A","diasRestantes":30,'
        '"recebidoEm":"2026-05-01T00:00:00Z"}\n\n'
        'data: {"type":"certificado_alerta",'
        '"cnpjProprioId":"B","diasRestantes":7,'
        '"recebidoEm":"2026-05-24T00:00:00Z"}\n\n',
      ));
      await pump();

      expect(eventos.map((e) => e.cnpjProprioId).toList(), ['A', 'B']);
      expect(eventos.map((e) => e.diasRestantes).toList(), [30, 7]);
    });

    test('múltiplos listeners (broadcast) → todos recebem', () async {
      final a = <CertificadoAlerta>[];
      final b = <CertificadoAlerta>[];
      sse.certificadoAlertas.listen(a.add);
      sse.certificadoAlertas.listen(b.add);

      sse.conectar();
      await pump();

      wire.add(utf8.encode(
        'data: {"type":"certificado_alerta",'
        '"cnpjProprioId":"abc","diasRestantes":7,'
        '"recebidoEm":"2026-05-24T13:45:21Z"}\n\n',
      ));
      await pump();

      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });

    test('certificado_alerta não interfere em nota_atualizada', () async {
      final notas = <Map<String, dynamic>>[];
      sse.onNotaAtualizada = notas.add;

      sse.conectar();
      await pump();

      wire.add(utf8.encode(
        'data: {"type":"nota_atualizada","notaId":"n1","status":"AUTORIZADO"}\n\n'
        'data: {"type":"certificado_alerta",'
        '"cnpjProprioId":"abc","diasRestantes":7,'
        '"recebidoEm":"2026-05-24T13:45:21Z"}\n\n',
      ));
      await pump();

      expect(notas, hasLength(1));
      expect(notas.first['notaId'], 'n1');
    });
  });

  group('SseService lifecycle', () {
    test('certificadoAlertas após dispose → done sem throw', () async {
      final api = _MockApi();
      final sse = SseService(api);
      final stream = sse.certificadoAlertas;
      sse.dispose();

      // Aguarda o close interno propagar (close é awaited em unawaited()).
      await Future<void>.delayed(Duration.zero);

      // Listener depois do dispose não deve travar nem lançar.
      var done = false;
      stream.listen((_) {}, onDone: () => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });
  });
}
