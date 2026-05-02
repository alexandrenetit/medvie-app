// test/services/medvie_api_service_test.dart
//
// Testes unitários do MedvieApiService.
// Usa MockHttpClient (mocktail) e MockFlutterSecureStorage injetados via construtor.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/services/medvie_api_service.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockHttpClient extends Mock implements http.Client {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// ── Helpers de resposta ──────────────────────────────────────────────────────

http.Response _ok(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200);

http.Response _created(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 201);

http.Response _unauthorized() =>
    http.Response(jsonEncode({'error': 'Unauthorized'}), 401);

http.Response _serverError() =>
    http.Response(jsonEncode({'error': 'Internal Server Error'}), 500);

http.Response _unprocessable() =>
    http.Response(jsonEncode({'error': 'Unprocessable'}), 422);

// ── Setup ─────────────────────────────────────────────────────────────────────

void main() {
  late MockHttpClient mockClient;
  late MockFlutterSecureStorage mockStorage;
  late MedvieApiService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockClient = MockHttpClient();
    mockStorage = MockFlutterSecureStorage();

    // Defaults do storage — sobrescritos por cada teste quando necessário
    when(() => mockStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    when(() => mockStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    service = MedvieApiService(
      client: mockClient,
      secureStorage: mockStorage,
    );
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
              }
            ],
          }
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
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _ok({'key': 'value'}));

      final result = await service.getJson('/api/v1/test');

      expect(result['key'], 'value');
    });

    test('erro não-200 lança Exception com status', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.getJson('/api/v1/test'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── postJson ─────────────────────────────────────────────────────────────

  group('postJson', () {
    test('sucesso 200 retorna Map', () async {
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _ok({'result': 'ok'}));

      final result = await service.postJson('/api/v1/test', {'data': 'x'});
      expect(result['result'], 'ok');
    });

    test('sucesso 201 retorna Map', () async {
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _created({'id': 'novo-id'}));

      final result = await service.postJson('/api/v1/test', {});
      expect(result['id'], 'novo-id');
    });

    test('erro não-200/201 lança Exception', () async {
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.postJson('/api/v1/test', {}),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── login ────────────────────────────────────────────────────────────────

  group('login', () {
    test('sucesso armazena accessToken e refreshToken', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null); // sem email salvo

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _ok({
                'access_token': 'access-abc',
                'refresh_token': 'refresh-xyz',
              }));

      await service.login('123.456.789-00', 'senha123');

      expect(service.accessToken, 'access-abc');
    });

    test('usa email salvo no storage se disponível', () async {
      when(() => mockStorage.read(key: 'gotrue_email'))
          .thenAnswer((_) async => 'uuid@medvie.local');

      final capturedBodies = <String>[];
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((invocation) async {
        capturedBodies.add(invocation.namedArguments[#body] as String);
        return _ok({'access_token': 'a', 'refresh_token': 'r'});
      });

      await service.login('123.456.789-00', 'senha123');

      expect(capturedBodies.first, contains('uuid@medvie.local'));
    });

    test('usa cpf@medvie.local quando storage não tem email', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      final capturedBodies = <String>[];
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((invocation) async {
        capturedBodies.add(invocation.namedArguments[#body] as String);
        return _ok({'access_token': 'a', 'refresh_token': 'r'});
      });

      await service.login('123.456.789-00', 'senha123');

      expect(capturedBodies.first, contains('12345678900@medvie.local'));
    });

    test('credenciais inválidas lança Exception', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _unauthorized());

      await expectLater(
        () => service.login('123.456.789-00', 'senha-errada'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── registrar ────────────────────────────────────────────────────────────

  group('registrar', () {
    test('sucesso 200 completa sem lançar exception', () async {
      when(() => mockStorage.read(key: 'gotrue_email'))
          .thenAnswer((_) async => 'uuid@medvie.local');

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _ok({}));

      await expectLater(
        service.registrar('123.456.789-00', 'senha123'),
        completes,
      );
    });

    test('status 422 é ignorado silenciosamente (email já existe)', () async {
      when(() => mockStorage.read(key: 'gotrue_email'))
          .thenAnswer((_) async => 'uuid@medvie.local');

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _unprocessable());

      await expectLater(
        service.registrar('123.456.789-00', 'senha123'),
        completes,
      );
    });

    test('outros erros lançam Exception', () async {
      when(() => mockStorage.read(key: 'gotrue_email'))
          .thenAnswer((_) async => 'uuid@medvie.local');

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.registrar('123.456.789-00', 'senha123'),
        throwsA(isA<Exception>()),
      );
    });

    test('gera e salva email quando não existe no storage', () async {
      when(() => mockStorage.read(key: 'gotrue_email'))
          .thenAnswer((_) async => null);

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _ok({}));

      await service.registrar('000.000.000-00', 'senha');

      verify(() => mockStorage.write(
            key: 'gotrue_email',
            value: any(named: 'value'),
          )).called(1);
    });
  });

  // ── emitirNota ───────────────────────────────────────────────────────────

  group('emitirNota', () {
    test('sucesso retorna notaFiscalId', () async {
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _created({'notaFiscalId': 'nf-abc-123'}));

      final id = await service.emitirNota(
        servicoId: 'servico-001',
        cnpjProprioId: 'cnpj-001',
        tomadorId: 'tomador-001',
        aliquotaIss: 2.0,
        issRetido: false,
      );

      expect(id, 'nf-abc-123');
    });

    test('backend sem notaFiscalId lança Exception', () async {
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _created({'outrocampo': 'x'}));

      await expectLater(
        () => service.emitirNota(
          servicoId: 'servico-001',
          cnpjProprioId: 'cnpj-001',
          tomadorId: 'tomador-001',
          aliquotaIss: 2.0,
          issRetido: false,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('erro de API lança Exception', () async {
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.emitirNota(
          servicoId: 's',
          cnpjProprioId: 'c',
          tomadorId: 't',
          aliquotaIss: 0,
          issRetido: false,
        ),
        throwsA(isA<Exception>()),
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
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? _unauthorized() : _ok({'data': 'ok'});
      });

      when(() => mockStorage.read(key: 'gotrue_refresh_token'))
          .thenAnswer((_) async => 'refresh-token-valido');

      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _ok({
                'access_token': 'novo-access',
                'refresh_token': 'novo-refresh',
              }));

      // Carrega o refresh token no serviço
      await service.carregarTokensPersistidos();

      final result = await service.getJson('/api/v1/test');
      expect(result['data'], 'ok');
      expect(callCount, 2);
    });

    test('sem refresh token salvo — lança Exception imediatamente', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _unauthorized());

      // Nenhum refresh token no storage
      when(() => mockStorage.read(key: 'gotrue_refresh_token'))
          .thenAnswer((_) async => null);

      await service.carregarTokensPersistidos();

      await expectLater(
        () => service.getJson('/api/v1/test'),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh retorna erro — lança Exception e limpa tokens', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _unauthorized());

      when(() => mockStorage.read(key: 'gotrue_refresh_token'))
          .thenAnswer((_) async => 'refresh-expirado');

      // Refresh falha
      when(() => mockClient.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => _unauthorized());

      await service.carregarTokensPersistidos();

      await expectLater(
        () => service.getJson('/api/v1/test'),
        throwsA(isA<Exception>()),
      );

      verify(() => mockStorage.delete(key: 'gotrue_refresh_token')).called(1);
    });
  });

  // ── carregarTokensPersistidos ────────────────────────────────────────────

  group('carregarTokensPersistidos', () {
    test('lê refresh token do storage', () async {
      when(() => mockStorage.read(key: 'gotrue_refresh_token'))
          .thenAnswer((_) async => 'meu-refresh-token');

      await service.carregarTokensPersistidos();

      verify(() => mockStorage.read(key: 'gotrue_refresh_token')).called(1);
    });
  });

  // ── buscarCep ────────────────────────────────────────────────────────────

  group('buscarCep', () {
    test('sucesso retorna BuscarCepResponse', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _ok({
                'logradouro': 'Av. Paulista',
                'bairro': 'Bela Vista',
                'localidade': 'São Paulo',
                'uf': 'SP',
              }));

      final r = await service.buscarCep('01310-000');
      expect(r.logradouro, 'Av. Paulista');
      expect(r.uf, 'SP');
    });

    test('CEP não encontrado lança Exception', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('', 404));

      await expectLater(() => service.buscarCep('00000-000'), throwsA(isA<Exception>()));
    });
  });

  // ── buscarCnpj ───────────────────────────────────────────────────────────

  group('buscarCnpj', () {
    test('sucesso retorna BuscarCnpjResponse', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _ok({
                'cnpj': '12.345.678/0001-99',
                'razaoSocial': 'Empresa',
                'municipio': 'SP',
                'uf': 'SP',
                'codigoIbge': '3550308',
              }));

      final r = await service.buscarCnpj('12.345.678/0001-99');
      expect(r.cnpj, '12.345.678/0001-99');
    });

    test('CNPJ não encontrado lança Exception', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('', 404));

      await expectLater(
        () => service.buscarCnpj('00.000.000/0001-00'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── listarServicos ───────────────────────────────────────────────────────

  group('listarServicos', () {
    test('resposta como array direto retorna lista', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode([
                  {'id': 's1', 'valor': 1000},
                  {'id': 's2', 'valor': 2000},
                ]),
                200,
              ));

      final list = await service.listarServicos('cnpj-001');
      expect(list.length, 2);
    });

    test('resposta paginada {data:[...]} retorna lista', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response(
                jsonEncode({
                  'data': [
                    {'id': 's1'},
                    {'id': 's2'},
                    {'id': 's3'},
                  ],
                  'totalItems': 3,
                }),
                200,
              ));

      final list = await service.listarServicos('cnpj-001');
      expect(list.length, 3);
    });

    test('erro lança Exception', () async {
      when(() => mockClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => _serverError());

      await expectLater(
        () => service.listarServicos('cnpj-001'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── TipoPdf enum ─────────────────────────────────────────────────────────

  group('TipoPdf', () {
    test('todos os valores existem no enum', () {
      expect(TipoPdf.values, containsAll([
        TipoPdf.reciboServico,
        TipoPdf.fechamentoMensal,
        TipoPdf.informeIr,
      ]));
    });
  });
}
