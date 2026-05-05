import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/core/services/sse_service.dart';
import 'package:medvie/features/notas/notas_screen.dart';
import 'package:medvie/main.dart' show routeObserver;

class _MockApi extends Mock implements MedvieApiService {}

class _FakeSseService extends SseService {
  _FakeSseService(super.api);

  final _controller = StreamController<SseConnectionState>.broadcast();
  int conectarCalls = 0;
  int desconectarCalls = 0;

  @override
  Stream<SseConnectionState> get state => _controller.stream;

  void emit(SseConnectionState state) => _controller.add(state);

  @override
  void conectar() {
    conectarCalls++;
  }

  @override
  void desconectar() {
    desconectarCalls++;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _FakeOnboarding extends ChangeNotifier implements OnboardingProvider {
  @override
  Medico? medico;

  @override
  void resetarSessao() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _buildWidget(NotaFiscalProvider provider) {
  return MaterialApp(
    navigatorObservers: [routeObserver],
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<NotaFiscalProvider>.value(value: provider),
        ChangeNotifierProvider<ServicoProvider>.value(value: ServicoProvider()),
        ChangeNotifierProvider<OnboardingProvider>.value(
          value: _FakeOnboarding(),
        ),
      ],
      child: const NotasScreen(),
    ),
  );
}

class _SseHarness {
  final _FakeSseService sse;

  _SseHarness(this.sse);

  Future<void> emit(WidgetTester tester, SseConnectionState state) async {
    sse.emit(state);
    await tester.pump();
    await tester.pump();
  }
}

Future<_SseHarness> _pumpSseScreen(WidgetTester tester) async {
  final api = _MockApi();
  late _FakeSseService sse;
  final provider = NotaFiscalProvider(
    api,
    sseFactory: (_) {
      sse = _FakeSseService(api);
      return sse;
    },
  );

  await tester.pumpWidget(_buildWidget(provider));
  await tester.pump();
  return _SseHarness(sse);
}

Future<void> _pumpWithState(
  WidgetTester tester,
  SseConnectionState state,
) async {
  final harness = await _pumpSseScreen(tester);
  await harness.emit(tester, state);
}

void main() {
  testWidgets('connected exibe icone verde discreto', (tester) async {
    await _pumpWithState(tester, SseConnectionState.connected);

    expect(find.byKey(const Key('sse-status-connected')), findsOneWidget);
    expect(find.text('Reconectando…'), findsNothing);
    expect(find.text('Conexão instável'), findsNothing);
  });

  testWidgets('connecting e reconnecting exibem banner de reconexao', (
    tester,
  ) async {
    final harness = await _pumpSseScreen(tester);
    await harness.emit(tester, SseConnectionState.connecting);

    expect(find.byKey(const Key('sse-status-reconnecting')), findsOneWidget);
    expect(find.text('Reconectando…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await harness.emit(tester, SseConnectionState.reconnecting);

    expect(find.byKey(const Key('sse-status-reconnecting')), findsOneWidget);
    expect(find.text('Reconectando…'), findsOneWidget);
  });

  testWidgets('error exibe banner instavel com tentar agora', (tester) async {
    final api = _MockApi();
    final sse = _FakeSseService(api);
    final provider = NotaFiscalProvider(api, sseFactory: (_) => sse);

    await tester.pumpWidget(_buildWidget(provider));
    await tester.pump();
    sse.emit(SseConnectionState.error);
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('sse-status-error')), findsOneWidget);
    expect(find.text('Conexão instável'), findsOneWidget);
    expect(find.text('Tentar agora'), findsOneWidget);

    await tester.tap(find.text('Tentar agora'));
    await tester.pump();

    expect(sse.desconectarCalls, 1);
    expect(sse.conectarCalls, 2);
  });

  testWidgets('forbidden exibe sessao expirada com sair', (tester) async {
    await _pumpWithState(tester, SseConnectionState.forbidden);

    expect(find.byKey(const Key('sse-status-forbidden')), findsOneWidget);
    expect(find.text('Sessão expirada'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('rateLimited exibe aguardando servidor', (tester) async {
    await _pumpWithState(tester, SseConnectionState.rateLimited);

    expect(find.byKey(const Key('sse-status-rate-limited')), findsOneWidget);
    expect(find.text('Aguardando servidor…'), findsOneWidget);
  });
}
