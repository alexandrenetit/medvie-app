import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/core/services/sse_service.dart';

class _MockApi extends Mock implements MedvieApiService {}

class _MockClient extends Mock implements http.Client {}

String _jwtExp(int secondsFromNow) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'exp':
                DateTime.now()
                    .toUtc()
                    .add(Duration(seconds: secondsFromNow))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(http.Request('GET', Uri.parse('http://localhost')));
  });

  late _MockApi api;
  late _MockClient client;

  setUp(() {
    api = _MockApi();
    client = _MockClient();
    when(() => api.baseUrl).thenReturn('http://api.test');
    when(() => client.close()).thenReturn(null);
  });

  test('token expirado refresh antes de abrir conexao', () async {
    var token = _jwtExp(-60);
    final order = <String>[];
    final controller = StreamController<List<int>>();
    final service = SseService(api, clientFactory: () => client);

    when(() => api.accessToken).thenAnswer((_) => token);
    when(() => api.refreshAccessToken()).thenAnswer((_) async {
      order.add('refresh');
      token = _jwtExp(3600);
    });
    when(() => client.send(any())).thenAnswer((_) async {
      order.add('send');
      return http.StreamedResponse(controller.stream, 200);
    });

    service.conectar();
    await Future<void>.delayed(Duration.zero);

    expect(order, ['refresh', 'send']);
    verify(() => api.refreshAccessToken()).called(1);

    service.desconectar();
    await controller.close();
  });

  test('servidor 401 faz refresh e reconnect imediato', () async {
    var token = _jwtExp(3600);
    final controller = StreamController<List<int>>();
    var sendIndex = 0;
    final service = SseService(api, clientFactory: () => client);

    when(() => api.accessToken).thenAnswer((_) => token);
    when(() => api.refreshAccessToken()).thenAnswer((_) async {
      token = _jwtExp(7200);
    });
    when(() => client.send(any())).thenAnswer((_) async {
      final index = sendIndex++;
      if (index == 0) {
        return http.StreamedResponse(const Stream.empty(), 401);
      }
      return http.StreamedResponse(controller.stream, 200);
    });

    service.conectar();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(sendIndex, 2);
    verify(() => api.refreshAccessToken()).called(1);

    service.desconectar();
    await controller.close();
  });

  test('3 falhas refresh desativa SSE e chama onForbidden', () async {
    final service = SseService(api, clientFactory: () => client);
    var forbiddenCalls = 0;

    when(() => api.accessToken).thenReturn(_jwtExp(-60));
    when(() => api.refreshAccessToken()).thenThrow(Exception('refresh failed'));
    service.onForbidden = () => forbiddenCalls++;

    service.conectar();
    await Future<void>.delayed(Duration.zero);
    service.conectar();
    await Future<void>.delayed(Duration.zero);
    service.conectar();
    await Future<void>.delayed(Duration.zero);

    expect(forbiddenCalls, 1);
    verifyNever(() => client.send(any()));

    service.desconectar();
  });
}
