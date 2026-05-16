// test/services/medvie_api_service_test.dart
//
// Testes unitários do MedvieApiService.
// Usa MockHttpClient (mocktail) e MockFlutterSecureStorage injetados via construtor.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockHttpClient extends Mock implements http.Client {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _FakeBaseRequest extends Fake implements http.BaseRequest {}

// ── Helpers de resposta ──────────────────────────────────────────────────────

http.Response _ok(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200);

http.Response _created(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 201);

http.Response _accepted(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 202);

http.Response _noContent() => http.Response('', 204);

http.Response _unauthorized() =>
    http.Response(jsonEncode({'error': 'Unauthorized'}), 401);

http.Response _serverError() =>
    http.Response(jsonEncode({'error': 'Internal Server Error'}), 500);

const _medicoId = '11111111-1111-1111-1111-111111111111';

Map<String, dynamic> _authSession({
  String accessToken = 'access-abc',
  String refreshToken = 'refresh-xyz',
  String medicoId = _medicoId,
}) => {
  'access_token': accessToken,
  'refresh_token': refreshToken,
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': 1760000000,
  'medico_id': medicoId,
  'user': {'id': '22222222-2222-2222-2222-222222222222'},
};

Medico _medicoCadastro() => Medico(
  id: '',
  nome: 'Dr. Cadastro',
  cpf: '123.456.789-00',
  crm: '12345',
  ufCrm: 'SP',
  especialidade: null,
  email: 'cadastro@medvie.test',
  telefone: '11999999999',
  cnpjs: const [],
);

Map<String, dynamic> _notaFiscalPayload({
  String id = 'nf-001',
  String status = 'autorizada',
}) {
  return {
    'id': id,
    'status': status,
    'codigoNbs': '1.0501',
    'numeroNfse': null,
    'chaveAcesso': null,
    'linkPdf': null,
    'motivoRejeicao': null,
    'createdAt': '2026-04-15T14:30:00.000Z',
    'updatedAt': '2026-04-15T14:30:00.000Z',
  };
}

http.StreamedResponse _streamed(int statusCode, {String body = ''}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

// ── Setup ─────────────────────────────────────────────────────────────────────

void main() {
  late MockHttpClient mockClient;
  late MockFlutterSecureStorage mockStorage;
  late MedvieApiService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue(_FakeBaseRequest());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockHttpClient();
    mockStorage = MockFlutterSecureStorage();

    // Defaults do storage — sobrescritos por cada teste quando necessário
    when(
      () => mockStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => mockStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});

    service = MedvieApiService(client: mockClient, secureStorage: mockStorage);
  });

  // ── DTOs: BuscarCepResponse ──────────────────────────────────────────────

  group('BuscarCepResponse.fromJson', () {
    test('parseia todos os campos', () {
      final r = BuscarCepResponse.fromJson({
        'logradouro': 'Av. Paulista',
        'bairro': 'Bela Vista',
        'localidade': 'São Paulo',
        'uf': 'SP',
      });
      expect(r.logradouro, 'Av. Paulista');
      expect(r.bairro, 'Bela Vista');
      expect(r.localidade, 'São Paulo');
      expect(r.uf, 'SP');
    });

    test('campos ausentes usam string vazia', () {
      final r = BuscarCepResponse.fromJson({});
      expect(r.logradouro, '');
      expect(r.uf, '');
    });
  });

  // ── DTOs: BuscarCnpjResponse ─────────────────────────────────────────────

  group('BuscarCnpjResponse.fromJson', () {
    test('parseia todos os campos', () {
      final r = BuscarCnpjResponse.fromJson({
        'cnpj': '12.345.678/0001-99',
        'razaoSocial': 'Empresa Ltda',
        'municipio': 'São Paulo',
        'uf': 'SP',
        'codigoIbge': '3550308',
        'nomeFantasia': 'Empresa',
        'situacao': 'ATIVA',
        'porte': 'ME',
        'abertura': '01/01/2010',
      });
      expect(r.cnpj, '12.345.678/0001-99');
      expect(r.razaoSocial, 'Empresa Ltda');
      expect(r.nomeFantasia, 'Empresa');
      expect(r.situacao, 'ATIVA');
    });

    test('campos opcionais ausentes ficam null', () {
      final r = BuscarCnpjResponse.fromJson({
        'cnpj': '',
        'razaoSocial': '',
        'municipio': '',
        'uf': '',
        'codigoIbge': '',
      });
      expect(r.nomeFantasia, isNull);
      expect(r.situacao, isNull);
    });
  });

  // ── DTOs: SugestaoFiscalResponse ────────────────────────────────────────

  group('SugestaoFiscalResponse.fromJson', () {
    test('parseia todos os campos', () {
      final r = SugestaoFiscalResponse.fromJson({
        'codigoNbs': '40119',
        'tipoServicoDefault': 'PlantaoClinico',
        'issRetidoDefault': true,
        'aliquotaIssEstimada': 3.5,
      });
      expect(r.codigoNbs, '40119');
      expect(r.tipoServicoDefault, 'PlantaoClinico');
      expect(r.issRetidoDefault, true);
      expect(r.aliquotaIssEstimada, 3.5);
    });

    test('campos ausentes usam defaults', () {
      final r = SugestaoFiscalResponse.fromJson({});
      expect(r.codigoNbs, '');
      expect(r.tipoServicoDefault, 'PlantaoClinico');
      expect(r.issRetidoDefault, false);
      expect(r.aliquotaIssEstimada, 2.0);
    });
  });

  // ── DTOs: OnboardingStatusResponse ──────────────────────────────────────

  group('OnboardingStatusResponse.fromJson', () {
    test('parseia step, completo e lista de cnpjs', () {
      final r = OnboardingStatusResponse.fromJson({
        'step': 3,
        'completo': false,
        'medico': null,
        'cnpjs': [],
      });
      expect(r.step, 3);
      expect(r.completo, false);
      expect(r.medico, isNull);
      expect(r.cnpjs, isEmpty);
    });

    test('parseia cnpjs com tomadores', () {
      final r = OnboardingStatusResponse.fromJson({
        'step': 5,
        'completo': true,
        'medico': null,
        'cnpjs': [
          {
            'id': 'cnpj-001',
            'cnpj': '12.345.678/0001-99',
            'razaoSocial': 'Dr. X ME',
            'codigoMunicipio': '3550308',
            'regimeTributario': 'SimplesNacional',
            'inscricaoMunicipal': '123',
            'tomadores': [
              {
                'id': 'tom-001',
                'cnpj': '00.000.000/0001-00',
                'razaoSocial': 'Hospital',
                'codigoMunicipioPrestacao': '3550308',
              },
            ],
          },
        ],
      });
      expect(r.cnpjs.length, 1);
      expect(r.cnpjs.first.tomadores.length, 1);
    });
  });

  // ── DTOs: TomadorResumoResponse ──────────────────────────────────────────

  group('TomadorResumoResponse.fromJson', () {
    test('parseia campos obrigatórios e opcionais', () {
      final r = TomadorResumoResponse.fromJson({
        'id': 'tom-001',
        'cnpj': '00.000.000/0001-00',
        'razaoSocial': 'Hospital',
        'codigoMunicipioPrestacao': '3550308',
        'valorPadrao': 2500.0,
        'emailFinanceiro': 'fin@hospital.com',
        'retemIss': true,
        'retemIrrf': false,
        'aliquotaIss': 2.0,
        'aliquotaIrrf': 1.5,
      });
      expect(r.id, 'tom-001');
      expect(r.valorPadrao, 2500.0);
      expect(r.retemIss, true);
      expect(r.aliquotaIss, 2.0);
    });

    test('campos numéricos ausentes usam 0.0', () {
      final r = TomadorResumoResponse.fromJson({
        'id': 'x',
        'cnpj': '',
        'razaoSocial': '',
        'codigoMunicipioPrestacao': '',
      });
      expect(r.aliquotaIss, 0.0);
      expect(r.aliquotaIrrf, 0.0);
    });
  });

  // ── getJson ──────────────────────────────────────────────────────────────

  group('getJson', () {
    test('sucesso 200 retorna Map decodificado', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => _ok({'key': 'value'}));

      final result = await service.getJson('/api/v1/test');

      expect(result['key'], 'value');
    });

    test('erro não-200 lança Exception com status', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.getJson('/api/v1/test'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── postJson ─────────────────────────────────────────────────────────────

  group('postJson', () {
    test('sucesso 200 retorna Map', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _ok({'result': 'ok'}));

      final result = await service.postJson('/api/v1/test', {'data': 'x'});
      expect(result['result'], 'ok');
    });

    test('sucesso 201 retorna Map', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _created({'id': 'novo-id'}));

      final result = await service.postJson('/api/v1/test', {});
      expect(result['id'], 'novo-id');
    });

    test('erro não-200/201 lança Exception', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.postJson('/api/v1/test', {}),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── login ────────────────────────────────────────────────────────────────

  group('login', () {
    test('sucesso posta CPF no facade e armazena tokens', () async {
      late Uri capturedUrl;
      late String capturedBody;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        capturedBody = invocation.namedArguments[#body] as String;
        return _ok(_authSession());
      });

      final medicoId = await service.login('123.456.789-00', 'senha123');

      expect(capturedUrl.path, '/auth/login');
      expect(jsonDecode(capturedBody), {
        'cpf': '12345678900',
        'password': 'senha123',
      });
      expect(capturedBody, isNot(contains('medvie.local')));
      expect(medicoId, _medicoId);
      expect(service.accessToken, 'access-abc');
      expect(service.authenticatedMedicoId, _medicoId);
      verify(
        () =>
            mockStorage.write(key: 'auth_refresh_token', value: 'refresh-xyz'),
      ).called(1);
    });

    test('onboarding-status após login usa Bearer autenticado', () async {
      late Uri capturedUrl;
      late Map<String, String> capturedHeaders;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _ok(_authSession()));
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        capturedHeaders =
            invocation.namedArguments[#headers] as Map<String, String>;
        return _ok({'step': 1, 'completo': false, 'medico': null, 'cnpjs': []});
      });

      final medicoId = await service.login('123.456.789-00', 'senha123');
      final status = await service.getOnboardingStatus(medicoId);

      expect(capturedUrl.path, '/api/v1/medicos/$_medicoId/onboarding-status');
      expect(capturedHeaders['Authorization'], 'Bearer access-abc');
      expect(status.step, 1);
    });

    test('login não depende de gotrue_email local', () async {
      final capturedBodies = <String>[];
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        capturedBodies.add(invocation.namedArguments[#body] as String);
        return _ok(_authSession(accessToken: 'a', refreshToken: 'r'));
      });

      await service.login('123.456.789-00', 'senha123');

      verifyNever(() => mockStorage.read(key: 'gotrue_email'));
      expect(capturedBodies.first, isNot(contains('@medvie.local')));
      expect(jsonDecode(capturedBodies.first)['cpf'], '12345678900');
    });

    test('credenciais inválidas lança Exception', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _unauthorized());

      await expectLater(
        () => service.login('123.456.789-00', 'senha-errada'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── registrar ────────────────────────────────────────────────────────────

  group('registrar', () {
    test('sucesso posta CPF no facade sem salvar gotrue_email', () async {
      late Uri capturedUrl;
      late String capturedBody;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        capturedBody = invocation.namedArguments[#body] as String;
        return _created(_authSession());
      });

      final medicoId = await service.registrar(
        _medicoCadastro(),
        7,
        'senha123',
      );

      expect(capturedUrl.path, '/auth/register');
      expect(jsonDecode(capturedBody), {
        'cpf': '12345678900',
        'password': 'senha123',
        'fullName': 'Dr. Cadastro',
        'crm': '12345',
        'ufCrm': 'SP',
        'especialidadeId': 7,
        'email': 'cadastro@medvie.test',
        'phone': '11999999999',
      });
      expect(capturedBody, isNot(contains('medvie.local')));
      expect(medicoId, _medicoId);
      expect(service.accessToken, 'access-abc');
      expect(service.authenticatedMedicoId, _medicoId);
      verify(
        () =>
            mockStorage.write(key: 'auth_refresh_token', value: 'refresh-xyz'),
      ).called(1);
      verifyNever(
        () => mockStorage.write(
          key: 'gotrue_email',
          value: any(named: 'value'),
        ),
      );
    });

    test('409 mapeia CPF já cadastrado para login', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 409));

      await expectLater(
        () => service.registrar(_medicoCadastro(), 7, 'senha123'),
        throwsA(
          isA<Exception>()
              .having(
                (e) => e.toString(),
                'mensagem',
                contains('CPF já cadastrado'),
              )
              .having((e) => e.toString(), 'login', contains('login')),
        ),
      );
    });

    test('resposta sem medico_id lança Exception', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => _created({'access_token': 'a', 'refresh_token': 'r'}),
      );

      await expectLater(
        () => service.registrar(_medicoCadastro(), 7, 'senha123'),
        throwsA(isA<Exception>()),
      );
    });

    test('outros erros lançam Exception', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.registrar(_medicoCadastro(), 7, 'senha123'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── cadastrarEmitente ────────────────────────────────────────────────────

  group('cadastrarEmitente', () {
    test('posta para notas/emitentes e sucesso 204 completa', () async {
      late Uri capturedUrl;
      late Map<String, String> capturedHeaders;
      late String capturedBody;

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        capturedHeaders =
            invocation.namedArguments[#headers] as Map<String, String>;
        capturedBody = invocation.namedArguments[#body] as String;
        return _noContent();
      });

      await expectLater(service.cadastrarEmitente('cnpj-001'), completes);

      expect(capturedUrl.path, '/api/v1/notas/emitentes');
      expect(capturedHeaders['Content-Type'], 'application/json');
      expect(jsonDecode(capturedBody), {'cnpjProprioId': 'cnpj-001'});
    });

    test('cnpjProprioId vazio lança ArgumentError', () async {
      await expectLater(
        () => service.cadastrarEmitente('  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('status 400 lança ApiException com campos preservados', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'code': 'EMITENTE_INVALIDO',
            'description': 'CNPJ próprio inválido',
          }),
          400,
        ),
      );

      await expectLater(
        () => service.cadastrarEmitente('cnpj-001'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'EMITENTE_INVALIDO')
              .having(
                (e) => e.description,
                'description',
                'CNPJ próprio inválido',
              ),
        ),
      );
    });

    test('status 500 lança ApiException', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.cadastrarEmitente('cnpj-001'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  // ── emitirNota ───────────────────────────────────────────────────────────

  // listarNotas

  group('listarNotas', () {
    test('200 paginado retorna NotasPagina e usa tamanhoPagina 20', () async {
      late Uri capturedUrl;

      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        return _ok({
          'notas': [_notaFiscalPayload()],
          'total': 1,
          'pagina': 1,
          'tamanhoPagina': 20,
        });
      });

      final pagina = await service.listarNotas('cnpj-001');

      expect(capturedUrl.path, '/api/v1/notas');
      expect(capturedUrl.queryParameters['cnpjProprioId'], 'cnpj-001');
      expect(capturedUrl.queryParameters['pagina'], '1');
      expect(capturedUrl.queryParameters['tamanhoPagina'], '20');
      expect(pagina.total, 1);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
      expect(pagina.notas.single.id, 'nf-001');
    });

    test('200 com notas vazias retorna lista vazia e paginacao', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async =>
            _ok({'notas': [], 'total': 0, 'pagina': 1, 'tamanhoPagina': 20}),
      );

      final pagina = await service.listarNotas('cnpj-001');

      expect(pagina.notas, isEmpty);
      expect(pagina.total, 0);
      expect(pagina.pagina, 1);
      expect(pagina.tamanhoPagina, 20);
    });

    test('200 com array direto falha com ApiException', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode([_notaFiscalPayload()]), 200),
      );

      await expectLater(
        () => service.listarNotas('cnpj-001'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having((e) => e.code, 'code', 'Contrato.Invalido'),
        ),
      );
    });

    test('400 preserva erro em ApiException', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'code': 'FILTRO_INVALIDO',
            'description': 'Filtro invalido',
          }),
          400,
        ),
      );

      await expectLater(
        () => service.listarNotas('cnpj-001'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'FILTRO_INVALIDO')
              .having((e) => e.description, 'description', 'Filtro invalido'),
        ),
      );
    });
  });

  // emitirNota

  group('emitirNota', () {
    test('201 com notaFiscalId retorna id', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _created({'notaFiscalId': 'nf-abc-123'}));

      final id = await service.emitirNota(
        servicoId: 'servico-001',
        cnpjProprioId: 'cnpj-001',
        tomadorId: 'tomador-001',
        aliquotaIss: 2.0,
        issRetido: false,
      );

      expect(id, 'nf-abc-123');
    });

    test('202 com notaFiscalId retorna id', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _accepted({'notaFiscalId': 'nf-202'}));

      final id = await service.emitirNota(
        servicoId: 'servico-001',
        cnpjProprioId: 'cnpj-001',
        tomadorId: 'tomador-001',
        aliquotaIss: 2.0,
        issRetido: false,
      );

      expect(id, 'nf-202');
    });

    test('omite aliquotaIss e issRetido quando null', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _created({'notaFiscalId': 'nf-sem-iss'}));

      await service.emitirNota(
        servicoId: 'servico-001',
        cnpjProprioId: 'cnpj-001',
        tomadorId: 'tomador-001',
      );

      final capturedBody =
          verify(
                () => mockClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as String;
      final payload = jsonDecode(capturedBody) as Map<String, dynamic>;

      expect(payload.containsKey('aliquotaIss'), isFalse);
      expect(payload.containsKey('issRetido'), isFalse);
    });

    test('inclui aliquotaIss e issRetido quando informados', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _created({'notaFiscalId': 'nf-com-iss'}));

      await service.emitirNota(
        servicoId: 'servico-001',
        cnpjProprioId: 'cnpj-001',
        tomadorId: 'tomador-001',
        aliquotaIss: 2.0,
        issRetido: true,
      );

      final capturedBody =
          verify(
                () => mockClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as String;
      final payload = jsonDecode(capturedBody) as Map<String, dynamic>;

      expect(payload['aliquotaIss'], 2.0);
      expect(payload['issRetido'], isTrue);
    });

    test('200 lança ApiException', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _ok({'notaFiscalId': 'nf-200'}));

      await expectLater(
        () => service.emitirNota(
          servicoId: 'servico-001',
          cnpjProprioId: 'cnpj-001',
          tomadorId: 'tomador-001',
          aliquotaIss: 2.0,
          issRetido: false,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200),
        ),
      );
    });

    test('202 com body vazio retorna null', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 202));

      final id = await service.emitirNota(
        servicoId: 'servico-001',
        cnpjProprioId: 'cnpj-001',
        tomadorId: 'tomador-001',
        aliquotaIss: 2.0,
        issRetido: false,
      );

      expect(id, isNull);
    });

    test('201 sem notaFiscalId lança ApiException; 202 retorna null', () async {
      for (final statusCode in [201, 202]) {
        reset(mockClient);
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'outrocampo': 'x'}), statusCode),
        );

        final call = service.emitirNota(
          servicoId: 'servico-001',
          cnpjProprioId: 'cnpj-001',
          tomadorId: 'tomador-001',
          aliquotaIss: 2.0,
          issRetido: false,
        );
        if (statusCode == 202) {
          expect(await call, isNull);
        } else {
          await expectLater(
            () => call,
            throwsA(
              isA<ApiException>()
                  .having((e) => e.statusCode, 'statusCode', statusCode)
                  .having((e) => e.code, 'code', 'Contrato.Invalido'),
            ),
          );
        }
      }
    });

    test('400 preserva code e description em ApiException', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'code': 'NOTA_INVALIDA',
            'description': 'Dados inválidos',
          }),
          400,
        ),
      );

      await expectLater(
        () => service.emitirNota(
          servicoId: 'servico-001',
          cnpjProprioId: 'cnpj-001',
          tomadorId: 'tomador-001',
          aliquotaIss: 2.0,
          issRetido: false,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'NOTA_INVALIDA')
              .having((e) => e.description, 'description', 'Dados inválidos'),
        ),
      );
    });
  });

  // ── cancelarNota ─────────────────────────────────────────────────────────

  group('cancelarNota', () {
    test('envia DELETE para notas/id com cnpjProprioId e motivo', () async {
      late http.BaseRequest capturedRequest;

      when(() => mockClient.send(any())).thenAnswer((invocation) async {
        capturedRequest =
            invocation.positionalArguments.single as http.BaseRequest;
        return _streamed(204);
      });

      await expectLater(
        service.cancelarNota('nf-id', 'cnpj-001', 'Duplicidade', '3550308'),
        completes,
      );

      expect(capturedRequest.method, 'DELETE');
      expect(capturedRequest.url.path, '/api/v1/notas/nf-id');
      expect(jsonDecode((capturedRequest as http.Request).body), {
        'cnpjProprioId': 'cnpj-001',
        'motivo': 'Duplicidade',
        'codigo': '3550308',
      });
    });

    test('status 200 e 204 completam sem erro', () async {
      for (final statusCode in [200, 204]) {
        reset(mockClient);
        when(
          () => mockClient.send(any()),
        ).thenAnswer((_) async => _streamed(statusCode));

        await expectLater(
          service.cancelarNota('nf-id', 'cnpj-001', 'Duplicidade', '3550308'),
          completes,
        );
      }
    });

    test('codigo vazio lança ArgumentError', () async {
      await expectLater(
        () => service.cancelarNota('nf-id', 'cnpj-001', 'Duplicidade', ' '),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(() => mockClient.send(any()));
    });

    test('400 preserva code e description em ApiException', () async {
      when(() => mockClient.send(any())).thenAnswer(
        (_) async => _streamed(
          400,
          body: jsonEncode({
            'code': 'CANCELAMENTO_INVALIDO',
            'description': 'Motivo inválido',
          }),
        ),
      );

      await expectLater(
        () => service.cancelarNota('nf-id', 'cnpj-001', 'Duplicidade', '3550308'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', 'CANCELAMENTO_INVALIDO')
              .having((e) => e.description, 'description', 'Motivo inválido'),
        ),
      );
    });

    test('403, 404 e 422 lançam ApiException', () async {
      for (final statusCode in [403, 404, 422]) {
        reset(mockClient);
        when(
          () => mockClient.send(any()),
        ).thenAnswer((_) async => _streamed(statusCode));

        await expectLater(
          () => service.cancelarNota('nf-id', 'cnpj-001', 'Duplicidade', '3550308'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              statusCode,
            ),
          ),
        );
      }
    });
  });

  // ── sincronizarNotas ─────────────────────────────────────────────────────

  group('sincronizarNotas', () {
    test('erro HTTP lança ApiException', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'code': 'SYNC_ERROR',
            'description': 'Falha ao sincronizar notas',
          }),
          500,
        ),
      );

      await expectLater(
        () => service.sincronizarNotas(DateTime.utc(2026, 5, 11)),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.code, 'code', 'SYNC_ERROR')
              .having(
                (e) => e.description,
                'description',
                'Falha ao sincronizar notas',
              ),
        ),
      );
    });
  });

  // ── Token refresh automático via _send ───────────────────────────────────

  group('token refresh automático', () {
    test('401 dispara refresh e retenta — retorna resposta final', () async {
      // Primeira chamada retorna 401
      // Refresh bem-sucedido
      // Segunda chamada retorna 200
      var callCount = 0;
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? _unauthorized() : _ok({'data': 'ok'});
      });

      when(
        () => mockStorage.read(key: 'auth_refresh_token'),
      ).thenAnswer((_) async => 'refresh-token-valido');

      late Uri refreshUrl;
      late String refreshBody;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        refreshUrl = invocation.positionalArguments.first as Uri;
        refreshBody = invocation.namedArguments[#body] as String;
        return _ok({
          'accessToken': 'novo-access',
          'refreshToken': 'novo-refresh',
          'medico_id': _medicoId,
        });
      });

      // Carrega o refresh token no serviço
      await service.carregarTokensPersistidos();

      final result = await service.getJson('/api/v1/test');
      expect(result['data'], 'ok');
      expect(callCount, 2);
      expect(refreshUrl.path, '/auth/refresh');
      expect(jsonDecode(refreshBody), {'refreshToken': 'refresh-token-valido'});
      expect(service.authenticatedMedicoId, _medicoId);
      verify(
        () =>
            mockStorage.write(key: 'auth_refresh_token', value: 'novo-refresh'),
      ).called(1);
    });

    test('refresh envia Bearer atual quando access token existe', () async {
      var getCount = 0;
      late Map<String, String> refreshHeaders;
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        getCount++;
        return getCount == 1 ? _unauthorized() : _ok({'data': 'ok'});
      });
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as Uri;
        if (url.path == '/auth/login') {
          return _ok(
            _authSession(
              accessToken: 'access-antigo',
              refreshToken: 'refresh-atual',
            ),
          );
        }
        refreshHeaders =
            invocation.namedArguments[#headers] as Map<String, String>;
        return _ok(
          _authSession(
            accessToken: 'access-novo',
            refreshToken: 'refresh-novo',
          ),
        );
      });

      await service.login('123.456.789-00', 'senha123');
      final result = await service.getJson('/api/v1/test');

      expect(result['data'], 'ok');
      expect(refreshHeaders['Authorization'], 'Bearer access-antigo');
      expect(service.accessToken, 'access-novo');
    });

    test('403 não tenta refresh nem retry', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 403));

      await expectLater(
        () => service.getJson('/api/v1/test'),
        throwsA(isA<Exception>()),
      );

      verify(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).called(1);
      verifyNever(
        () => mockClient.post(
          Uri.parse('${service.baseUrl}/auth/refresh'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });

    test('sem refresh token salvo — lança Exception imediatamente', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => _unauthorized());

      // Nenhum refresh token no storage
      when(
        () => mockStorage.read(key: 'auth_refresh_token'),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: 'gotrue_refresh_token'),
      ).thenAnswer((_) async => null);

      await service.carregarTokensPersistidos();

      await expectLater(
        () => service.getJson('/api/v1/test'),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh retorna erro — lança Exception e limpa tokens', () async {
      var sessionExpired = false;
      service.onSessionExpired = () => sessionExpired = true;
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => _unauthorized());

      when(
        () => mockStorage.read(key: 'auth_refresh_token'),
      ).thenAnswer((_) async => 'refresh-expirado');

      // Refresh falha
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _unauthorized());

      await service.carregarTokensPersistidos();

      await expectLater(
        () => service.getJson('/api/v1/test'),
        throwsA(isA<Exception>()),
      );

      verify(() => mockStorage.delete(key: 'auth_refresh_token')).called(1);
      verify(() => mockStorage.delete(key: 'gotrue_refresh_token')).called(1);
      expect(sessionExpired, isTrue);
    });
  });

  // ── carregarTokensPersistidos ────────────────────────────────────────────

  group('carregarTokensPersistidos', () {
    test('lê refresh token do storage', () async {
      when(
        () => mockStorage.read(key: 'auth_refresh_token'),
      ).thenAnswer((_) async => 'meu-refresh-token');

      await service.carregarTokensPersistidos();

      verify(() => mockStorage.read(key: 'auth_refresh_token')).called(1);
    });

    test('lê refresh token legado quando novo não existe', () async {
      when(
        () => mockStorage.read(key: 'auth_refresh_token'),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: 'gotrue_refresh_token'),
      ).thenAnswer((_) async => 'refresh-legado');

      await service.carregarTokensPersistidos();

      verify(() => mockStorage.read(key: 'auth_refresh_token')).called(1);
      verify(() => mockStorage.read(key: 'gotrue_refresh_token')).called(1);
    });
  });

  // ── buscarCep ────────────────────────────────────────────────────────────

  group('listarEspecialidades', () {
    test('pós-login envia Bearer para /api/v1/especialidades', () async {
      late Uri capturedUrl;
      late Map<String, String> capturedHeaders;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _ok(_authSession()));
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        capturedHeaders =
            invocation.namedArguments[#headers] as Map<String, String>;
        return http.Response(
          jsonEncode([
            {'id': 1, 'nome': 'Cardiologia'},
          ]),
          200,
        );
      });

      await service.login('123.456.789-00', 'senha123');
      final especialidades = await service.listarEspecialidades();

      expect(capturedUrl.path, '/api/v1/especialidades');
      expect(capturedHeaders['Authorization'], 'Bearer access-abc');
      expect(especialidades.single.nome, 'Cardiologia');
    });
  });

  group('buscarCep', () {
    test('sucesso retorna BuscarCepResponse', () async {
      late Uri capturedUrl;
      late Map<String, String> capturedHeaders;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _ok(_authSession()));
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        capturedHeaders =
            invocation.namedArguments[#headers] as Map<String, String>;
        return _ok({
          'logradouro': 'Av. Paulista',
          'bairro': 'Bela Vista',
          'localidade': 'São Paulo',
          'uf': 'SP',
        });
      });

      await service.login('123.456.789-00', 'senha123');
      final r = await service.buscarCep('01310-000');

      expect(capturedUrl.path, '/api/v1/cep/01310000');
      expect(capturedHeaders['Authorization'], 'Bearer access-abc');
      expect(r.logradouro, 'Av. Paulista');
      expect(r.uf, 'SP');
    });

    test('CEP não encontrado lança Exception', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 404));

      await expectLater(
        () => service.buscarCep('00000-000'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── buscarCnpj ───────────────────────────────────────────────────────────

  group('buscarCnpj', () {
    test('sucesso retorna BuscarCnpjResponse', () async {
      late Uri capturedUrl;
      late Map<String, String> capturedHeaders;
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => _ok(_authSession()));
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((invocation) async {
        capturedUrl = invocation.positionalArguments.first as Uri;
        capturedHeaders =
            invocation.namedArguments[#headers] as Map<String, String>;
        return _ok({
          'cnpj': '12.345.678/0001-99',
          'razaoSocial': 'Empresa',
          'municipio': 'SP',
          'uf': 'SP',
          'codigoIbge': '3550308',
        });
      });

      await service.login('123.456.789-00', 'senha123');
      final r = await service.buscarCnpj('12.345.678/0001-99');

      expect(capturedUrl.path, '/api/v1/cnpj/12345678000199');
      expect(capturedHeaders['Authorization'], 'Bearer access-abc');
      expect(r.cnpj, '12.345.678/0001-99');
    });

    test('CNPJ não encontrado lança Exception', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('', 404));

      await expectLater(
        () => service.buscarCnpj('00.000.000/0001-00'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── listarServicos ───────────────────────────────────────────────────────

  group('listarServicos', () {
    test('resposta como array direto retorna lista', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode([
            {'id': 's1', 'valor': 1000},
            {'id': 's2', 'valor': 2000},
          ]),
          200,
        ),
      );

      final list = await service.listarServicos('cnpj-001');
      expect(list.length, 2);
    });

    test('resposta paginada {data:[...]} retorna lista', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {'id': 's1'},
              {'id': 's2'},
              {'id': 's3'},
            ],
            'totalItems': 3,
          }),
          200,
        ),
      );

      final list = await service.listarServicos('cnpj-001');
      expect(list.length, 3);
    });

    test('erro lança Exception', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.listarServicos('cnpj-001'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── TipoPdf enum ─────────────────────────────────────────────────────────

  group('TipoPdf', () {
    test('todos os valores existem no enum', () {
      expect(
        TipoPdf.values,
        containsAll([
          TipoPdf.reciboServico,
          TipoPdf.fechamentoMensal,
          TipoPdf.informeIr,
        ]),
      );
    });
  });
}
