import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/services/sse_service.dart';

class _MockClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(http.Request('GET', Uri.parse('http://localhost')));
  });

  test('paused fecha conexao em menos de 500ms', () async {
    final client = _MockClient();
    final controller = StreamController<List<int>>();
    final service = SseService('http://api.test', clientFactory: () => client);

    when(() => client.close()).thenReturn(null);
    when(
      () => client.send(any()),
    ).thenAnswer((_) async => http.StreamedResponse(controller.stream, 200));

    await service.conectar('token');

    final elapsed = Stopwatch()..start();
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    elapsed.stop();

    expect(elapsed.elapsedMilliseconds, lessThan(500));
    verify(() => client.close()).called(greaterThanOrEqualTo(1));

    service.desconectar();
    await controller.close();
  });

  test('resumed inicia reconexao quando estava suspenso', () async {
    final clients = [_MockClient(), _MockClient()];
    final controllers = [
      StreamController<List<int>>(),
      StreamController<List<int>>(),
    ];
    var index = 0;
    final service = SseService(
      'http://api.test',
      clientFactory: () => clients[index++],
    );

    for (var i = 0; i < clients.length; i++) {
      when(() => clients[i].close()).thenReturn(null);
      when(() => clients[i].send(any())).thenAnswer(
        (_) async => http.StreamedResponse(controllers[i].stream, 200),
      );
    }

    await service.conectar('token');
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    verify(() => clients[0].send(any())).called(1);
    verify(() => clients[1].send(any())).called(1);

    service.desconectar();
    for (final controller in controllers) {
      await controller.close();
    }
  });
}
