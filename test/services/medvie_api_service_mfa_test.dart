// test/services/medvie_api_service_mfa_test.dart
//
// Segundo fator por e-mail no cliente NATIVO. O app não tem cookie, então o handle da sessão
// (`session_handle`) é o que amarra a confirmação a ESTE login — guardado no armazenamento
// seguro e reapresentado no header `X-Session-Handle`.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

const _medicoId = '11111111-1111-1111-1111-111111111111';
const _handle = 'aaaabbbbccccdddd.segredo-do-handle';
const _kHandleKey = 'auth_session_handle';

/// A flag viaja na URL: `false` (abrir a tela) é idempotente no backend, `true` é o reenvio
/// explícito. Sem ela o servidor não sabe distinguir os dois chamadores.
Uri _uriEnviar({bool reenviar = false}) => Uri.parse(
  'http://api.test/auth/mfa/codigo/enviar',
).replace(queryParameters: {'reenviar': reenviar.toString()});

Map<String, dynamic> _authSession({
  bool? verificacaoPendente = true,
  String? sessionHandle = _handle,
}) => {
  'access_token': 'access-abc',
  'refresh_token': 'refresh-xyz',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': 1760000000,
  'medico_id': _medicoId,
  'verificacao_pendente': ?verificacaoPendente,
  'session_handle': ?sessionHandle,
  'user': {'id': '22222222-2222-2222-2222-222222222222'},
};

void main() {
  late MockHttpClient mockClient;
  late MockFlutterSecureStorage mockStorage;
  late MedvieApiService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockHttpClient();
    mockStorage = MockFlutterSecureStorage();

    when(
      () => mockStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((_) async {});
    when(
      () => mockStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});

    service = MedvieApiService(client: mockClient, secureStorage: mockStorage);
    service.baseUrl = 'http://api.test';
  });

  /// Stub do POST /auth/login com o corpo pedido.
  void stubLogin(Map<String, dynamic> corpo) {
    when(
      () => mockClient.post(
        Uri.parse('http://api.test/auth/login'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => http.Response(jsonEncode(corpo), 200));
  }

  group('login — segundo fator e handle de sessão', () {
    test('nasce pendente e guarda o handle no armazenamento seguro', () async {
      stubLogin(_authSession(verificacaoPendente: true));

      await service.login('52998224725', 'Senha#123');

      expect(service.verificacaoPendente, isTrue);
      verify(
        () => mockStorage.write(key: _kHandleKey, value: _handle),
      ).called(1);
    });

    test('sessão já verificada abaixa o pendente', () async {
      stubLogin(_authSession(verificacaoPendente: false));

      await service.login('52998224725', 'Senha#123');

      expect(service.verificacaoPendente, isFalse);
    });

    test('corpo SEM verificacao_pendente é tratado como pendente', () async {
      stubLogin(_authSession(verificacaoPendente: null));

      await service.login('52998224725', 'Senha#123');

      // Fail-closed: assumir "verificado" quando o backend não disse nada liberaria o app
      // inteiro justamente quando a resposta foi omissa.
      expect(service.verificacaoPendente, isTrue);
    });

    test('corpo sem session_handle não apaga o handle que já existe', () async {
      when(
        () => mockStorage.read(key: _kHandleKey),
      ).thenAnswer((_) async => _handle);
      await service.carregarTokensPersistidos();
      stubLogin(_authSession(sessionHandle: null));
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await service.login('52998224725', 'Senha#123');
      // Sem handle não haveria header, e o médico cairia na tela do código a cada renovação.
      await service.enviarCodigoMfa();

      final headers =
          verify(
                () => mockClient.post(
                  _uriEnviar(),
                  headers: captureAny(named: 'headers'),
                ),
              ).captured.single
              as Map<String, String>;
      expect(headers['X-Session-Handle'], _handle);
    });
  });

  group('carregarTokensPersistidos', () {
    test('recupera o handle guardado no boot do app', () async {
      when(
        () => mockStorage.read(key: _kHandleKey),
      ).thenAnswer((_) async => _handle);
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await service.carregarTokensPersistidos();
      await service.enviarCodigoMfa();

      final headers =
          verify(
                () => mockClient.post(
                  _uriEnviar(),
                  headers: captureAny(named: 'headers'),
                ),
              ).captured.single
              as Map<String, String>;
      expect(headers['X-Session-Handle'], _handle);
    });

    test('sem handle guardado, o header simplesmente não vai', () async {
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await service.carregarTokensPersistidos();
      await service.enviarCodigoMfa();

      final headers =
          verify(
                () => mockClient.post(
                  _uriEnviar(),
                  headers: captureAny(named: 'headers'),
                ),
              ).captured.single
              as Map<String, String>;
      expect(headers.containsKey('X-Session-Handle'), isFalse);
    });
  });

  group('enviarCodigoMfa', () {
    test('204 completa sem exceção', () async {
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await expectLater(service.enviarCodigoMfa(), completes);
    });

    test('401 lança ApiException em vez de fingir sucesso', () async {
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 401));

      // Sem o throw a tela mostraria "código enviado" e o médico esperaria um e-mail que
      // nunca chega.
      await expectLater(
        service.enviarCodigoMfa(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });

    test('não envia corpo — o destinatário vem do JWT, nunca do cliente', () async {
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await service.enviarCodigoMfa();

      // Aceitar e-mail do cliente deixaria qualquer sessão redirecionar o código para a
      // caixa do atacante.
      verify(
        () => mockClient.post(_uriEnviar(), headers: any(named: 'headers')),
      ).called(1);
    });

    test('abrir a tela vai com reenviar=false (não queima o código já enviado)', () async {
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await service.enviarCodigoMfa();

      // Este é o caminho de quem voltou ao app. Pedir código novo aqui mataria o que já está
      // na caixa de entrada, e digitar o do e-mail daria 409.
      final url =
          verify(
                () => mockClient.post(captureAny(), headers: any(named: 'headers')),
              ).captured.single
              as Uri;
      expect(url.queryParameters['reenviar'], 'false');
    });

    test('reenviar: true pede explicitamente um código novo', () async {
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      await service.enviarCodigoMfa(reenviar: true);

      // Contraprova: quem não recebeu o e-mail precisa de outro código de verdade — o
      // anterior está em hash e é irrecuperável.
      final url =
          verify(
                () => mockClient.post(captureAny(), headers: any(named: 'headers')),
              ).captured.single
              as Uri;
      expect(url.queryParameters['reenviar'], 'true');
    });
  });

  group('verificarCodigoMfa', () {
    void stubVerificar(http.Response resposta) {
      when(
        () => mockClient.post(
          Uri.parse('http://api.test/auth/mfa/verificar'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => resposta);
    }

    test('200 abaixa o pendente e envia o código no corpo', () async {
      stubVerificar(
        http.Response(jsonEncode({'verificacao_pendente': false}), 200),
      );

      await service.verificarCodigoMfa('123456');

      expect(service.verificacaoPendente, isFalse);
      final body =
          verify(
                () => mockClient.post(
                  Uri.parse('http://api.test/auth/mfa/verificar'),
                  headers: any(named: 'headers'),
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as String;
      expect(jsonDecode(body), {'codigo': '123456'});
    });

    test('409 lança ApiException e MANTÉM o pendente', () async {
      stubVerificar(
        http.Response(
          jsonEncode({
            'code': 'Conflict.CodigoVerificacaoEmailMedico.CodigoExpirado',
            'description': 'Código expirado.',
          }),
          409,
        ),
      );

      await expectLater(
        service.verificarCodigoMfa('999999'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      // Código recusado não pode promover a sessão — é o controle inteiro.
      expect(service.verificacaoPendente, isTrue);
    });

    test('200 com corpo vazio conclui como verificado', () async {
      stubVerificar(http.Response('', 200));

      await service.verificarCodigoMfa('123456');

      // 200 é a confirmação do servidor; o corpo é só o espelho do estado.
      expect(service.verificacaoPendente, isFalse);
    });
  });

  group('limparSessaoEmMemoria', () {
    test('devolve o pendente a true e derruba o handle', () async {
      stubLogin(_authSession(verificacaoPendente: false));
      await service.login('52998224725', 'Senha#123');
      when(
        () => mockClient.post(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 204));

      service.limparSessaoEmMemoria();
      await service.enviarCodigoMfa();

      // Deixar `false` aqui faria o segundo fator ser herdado por quem logasse depois no
      // mesmo aparelho.
      expect(service.verificacaoPendente, isTrue);
      final headers =
          verify(
                () => mockClient.post(
                  _uriEnviar(),
                  headers: captureAny(named: 'headers'),
                ),
              ).captured.last
              as Map<String, String>;
      expect(headers.containsKey('X-Session-Handle'), isFalse);
    });
  });
}
