// test/widget/mfa_screen_test.dart
//
// Tela do segundo fator por e-mail. Mocka o BOUNDARY (http.Client) e usa o
// OnboardingProvider real: o que interessa é o comportamento visível — envio no mount, copy
// distinta por classe de erro, e quando o campo pode ou não ser limpo.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/features/auth/mfa_screen.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _base = 'http://api.test';
final _uriVerificar = Uri.parse('$_base/auth/mfa/verificar');

/// A flag viaja na URL: `false` (abrir a tela) é idempotente no backend, `true` é o reenvio
/// explícito que o médico pediu.
Uri _uriEnviar({bool reenviar = false}) => Uri.parse(
  '$_base/auth/mfa/codigo/enviar',
).replace(queryParameters: {'reenviar': reenviar.toString()});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockHttpClient client;
  late _MockSecureStorage storage;
  late OnboardingProvider provider;

  /// Responde a QUALQUER envio (com e sem a flag) — os testes distinguem os dois pela URL
  /// capturada, não pelo stub.
  void stubEnviar(http.Response resposta) {
    when(
      () => client.post(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => resposta);
  }

  List<Uri> urlsDeEnvio() =>
      verify(
            () => client.post(captureAny(), headers: any(named: 'headers')),
          ).captured
          .cast<Uri>()
          .where((u) => u.path.endsWith('/auth/mfa/codigo/enviar'))
          .toList();

  void stubVerificar(http.Response resposta) {
    when(
      () => client.post(
        _uriVerificar,
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => resposta);
  }

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = _MockHttpClient();
    storage = _MockSecureStorage();
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(
      () => storage.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    final api = MedvieApiService(client: client, secureStorage: storage);
    api.baseUrl = _base;
    provider = OnboardingProvider(api: api, secureStorage: storage);
    addTearDown(provider.dispose);

    // Padrão: o envio funciona. Cada teste sobrescreve o que precisa.
    stubEnviar(http.Response('', 204));
  });

  /// Monta a tela e deixa o envio disparado no mount concluir.
  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<OnboardingProvider>.value(
          value: provider,
          child: const MfaScreen(),
        ),
      ),
    );
    // O construtor do OnboardingProvider dispara uma restauração de sessão que passa por
    // SharedPreferences — plataforma, não relógio falso. Sem `runAsync` ela só completa
    // DEPOIS do teardown, e o `notifyListeners` dela estoura no teste seguinte como
    // "used after being disposed".
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pumpAndSettle();
  }

  Future<void> digitar(WidgetTester tester, String codigo) async {
    await tester.enterText(find.byType(TextField), codigo);
    await tester.pump();
  }

  Finder botaoConfirmar() =>
      find.widgetWithText(ElevatedButton, 'Confirmar e continuar');

  String textoDoCampo(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  Future<void> confirmar(WidgetTester tester) async {
    await tester.tap(botaoConfirmar());
    await tester.pumpAndSettle();
  }

  testWidgets('dispara o envio do código UMA vez ao montar, sem pedir código novo', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Verifique seu e-mail'), findsOneWidget);
    // Abrir a tela (inclusive ao voltar ao app) NÃO pode queimar o código já entregue: é o
    // caminho em que o médico digita o que está no e-mail.
    expect(urlsDeEnvio(), [_uriEnviar()]);
  });

  testWidgets('falha no envio do mount avisa e mantém o reenvio disponível', (tester) async {
    stubEnviar(http.Response('', 500));

    await montar(tester);

    expect(find.text('Não foi possível enviar o código. Toque em reenviar.'), findsOneWidget);
    final reenviar = tester.widget<TextButton>(
      find.ancestor(of: find.text('Reenviar código'), matching: find.byType(TextButton)),
    );
    expect(reenviar.onPressed, isNotNull);
  });

  testWidgets('código correto libera a sessão no provider', (tester) async {
    stubVerificar(http.Response(jsonEncode({'verificacao_pendente': false}), 200));
    await montar(tester);

    await digitar(tester, '123456');
    await confirmar(tester);

    expect(provider.verificacaoPendente, isFalse);
  });

  testWidgets('409 mostra "incorreto ou expirado", limpa o campo e NÃO avança', (tester) async {
    stubVerificar(
      http.Response(
        jsonEncode({
          'code': 'Conflict.CodigoVerificacaoEmailMedico.CodigoExpirado',
          'description': 'detalhe interno 0xDEADBEEF',
        }),
        409,
      ),
    );
    await montar(tester);

    await digitar(tester, '999999');
    await confirmar(tester);

    expect(
      find.text('Código incorreto ou expirado. Verifique e tente novamente.'),
      findsOneWidget,
    );
    // Código recusado não serve mais: deixá-lo no campo convidaria ao reenvio do mesmo valor.
    expect(textoDoCampo(tester), isEmpty);
    // A mensagem do backend nunca chega à tela.
    expect(find.textContaining('0xDEADBEEF'), findsNothing);
  });

  testWidgets('500 usa copy própria e PRESERVA o código digitado', (tester) async {
    stubVerificar(http.Response('', 500));
    await montar(tester);

    await digitar(tester, '123456');
    await confirmar(tester);

    expect(
      find.text('Não foi possível confirmar agora. Tente novamente em instantes.'),
      findsOneWidget,
    );
    // Distinção que importa: apagar o campo numa falha de servidor faria o médico descartar
    // um código VÁLIDO e pedir outro.
    expect(textoDoCampo(tester), '123456');
  });

  testWidgets('confirmar fica bloqueado com menos de 6 dígitos', (tester) async {
    await montar(tester);

    await digitar(tester, '12345');
    expect(tester.widget<ElevatedButton>(botaoConfirmar()).onPressed, isNull);

    // Contraprova: o 6º dígito libera o botão.
    await digitar(tester, '123456');
    expect(tester.widget<ElevatedButton>(botaoConfirmar()).onPressed, isNotNull);
  });

  testWidgets('campo aceita só dígitos', (tester) async {
    await montar(tester);

    await digitar(tester, '12a3b4');

    expect(textoDoCampo(tester), '1234');
  });

  testWidgets('reenviar pede outro código, confirma na tela e limpa o campo', (tester) async {
    await montar(tester);
    await digitar(tester, '999');

    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle();

    expect(find.text('Um novo código foi enviado.'), findsOneWidget);
    expect(textoDoCampo(tester), isEmpty);
    // O do mount (idempotente) + o do reenvio (explícito). Contraprova do teste do mount:
    // quem não recebeu o e-mail precisa de outro código de verdade.
    expect(urlsDeEnvio(), [_uriEnviar(), _uriEnviar(reenviar: true)]);
  });

  testWidgets('falha no reenvio tem copy de reenvio, não de envio inicial', (tester) async {
    await montar(tester);
    stubEnviar(http.Response('', 500));

    await tester.tap(find.text('Reenviar código'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível reenviar o código. Tente novamente.'), findsOneWidget);
    expect(find.text('Um novo código foi enviado.'), findsNothing);
  });
}
