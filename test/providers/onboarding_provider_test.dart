// test/providers/onboarding_provider_test.dart
//
// Testes unitários do OnboardingProvider.
// Cobre: validarCpf (estático), setPerfil, buscarCnpj, salvarMedico,
// finalizar, resetarSessao, adicionarCnpj, ativarModoManual, onboardingCompleto.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/models/especialidade.dart';
import 'package:medvie/core/models/perfil_atuacao.dart';
import 'package:medvie/core/providers/onboarding_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockApi extends Mock implements MedvieApiService {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Medico _buildMedico({List<CnpjComTomadores>? cnpjs}) => Medico(
      id: 'med-001',
      nome: 'Dr. Teste',
      cpf: '52998224725',
      crm: '12345',
      ufCrm: 'SP',
      especialidade: null,
      email: 'teste@medvie.com',
      cnpjs: cnpjs ?? [],
    );

BuscarCnpjResponse _buildCnpjResponse({String razaoSocial = 'Empresa LTDA'}) =>
    BuscarCnpjResponse(
      cnpj: '11222333000181',
      razaoSocial: razaoSocial,
      municipio: 'São Paulo',
      uf: 'SP',
      codigoIbge: '3550308',
      nomeFantasia: null,
      situacao: 'Ativa',
      porte: 'MEDIO',
      abertura: '01/01/2010',
    );

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Necessário para que any() funcione com o tipo Medico no cadastrarMedico()
    registerFallbackValue(_buildMedico());
  });

  late _MockApi mockApi;
  late _MockSecureStorage mockSecureStorage;
  late OnboardingProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockApi = _MockApi();
    mockSecureStorage = _MockSecureStorage();
    // Stubs padrão: nenhum dado persistido, operações de escrita/delete no-op
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async {});
    when(() => mockSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
    provider = OnboardingProvider(api: mockApi, secureStorage: mockSecureStorage);
    // Aguarda _restaurarSessao() completar (chamada assíncrona no constructor)
    await Future.delayed(Duration.zero);
  });

  // ── validarCpf ─────────────────────────────────────────────────────────────

  group('validarCpf()', () {
    test('CPF válido com máscara retorna true', () {
      expect(OnboardingProvider.validarCpf('529.982.247-25'), isTrue);
    });

    test('CPF válido sem máscara retorna true', () {
      expect(OnboardingProvider.validarCpf('52998224725'), isTrue);
    });

    test('CPF com todos os dígitos iguais retorna false', () {
      expect(OnboardingProvider.validarCpf('111.111.111-11'), isFalse);
    });

    test('CPF com comprimento errado retorna false', () {
      expect(OnboardingProvider.validarCpf('123.456.789'), isFalse);
    });

    test('CPF com primeiro dígito verificador errado retorna false', () {
      expect(OnboardingProvider.validarCpf('529.982.247-35'), isFalse);
    });

    test('string vazia retorna false', () {
      expect(OnboardingProvider.validarCpf(''), isFalse);
    });

    test('CPF só com zeros retorna false', () {
      expect(OnboardingProvider.validarCpf('000.000.000-00'), isFalse);
    });
  });

  // ── setPerfil ──────────────────────────────────────────────────────────────

  group('setPerfil()', () {
    test('preenche campos corretamente e notifica listeners', () {
      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      final esp = Especialidade(id: 1, nome: 'Cardiologia');
      provider.setPerfil(
        nome: 'Dr. Cardio',
        cpf: '529.982.247-25',
        crm: '12345',
        ufCrm: 'SP',
        especialidade: esp,
        email: 'cardio@medvie.com',
        telefone: '11999990000',
      );

      expect(provider.nome, 'Dr. Cardio');
      expect(provider.cpf, '529.982.247-25');
      expect(provider.crm, '12345');
      expect(provider.ufCrm, 'SP');
      expect(provider.especialidade?.id, 1);
      expect(provider.email, 'cardio@medvie.com');
      expect(provider.telefone, '11999990000');
      expect(notificacoes, 1);
    });
  });

  // ── buscarCnpj ─────────────────────────────────────────────────────────────

  group('buscarCnpj()', () {
    const cnpj = '11222333000181';

    test('sucesso → preenche razaoSocial/municipio, retorna true', () async {
      when(() => mockApi.buscarCnpj(any()))
          .thenAnswer((_) async => _buildCnpjResponse());

      final result = await provider.buscarCnpj(cnpj);

      expect(result, isTrue);
      expect(provider.razaoSocialAtual, 'Empresa LTDA');
      expect(provider.municipioAtual, 'São Paulo');
      expect(provider.ufAtual, 'SP');
      expect(provider.buscandoCnpj, isFalse);
      expect(provider.erroCnpj, isNull);
      expect(provider.erroCnpjApiDown, isFalse);
    });

    test('CNPJ não encontrado → retorna false, erroCnpj preenchido', () async {
      when(() => mockApi.buscarCnpj(any()))
          .thenThrow(Exception('CNPJ não encontrado'));

      final result = await provider.buscarCnpj(cnpj);

      expect(result, isFalse);
      expect(provider.buscandoCnpj, isFalse);
      expect(provider.erroCnpj, isNotNull);
      expect(provider.erroCnpjApiDown, isFalse);
    });

    test('timeout → retorna false, erroCnpjApiDown = true, erroCnpj = null',
        () async {
      when(() => mockApi.buscarCnpj(any()))
          .thenThrow(Exception('Connection timeout'));

      final result = await provider.buscarCnpj(cnpj);

      expect(result, isFalse);
      expect(provider.erroCnpjApiDown, isTrue);
      expect(provider.erroCnpj, isNull);
    });

    test('erro 503 → erroCnpjApiDown = true', () async {
      when(() => mockApi.buscarCnpj(any()))
          .thenThrow(Exception('HTTP 503 Service Unavailable'));

      final result = await provider.buscarCnpj(cnpj);

      expect(result, isFalse);
      expect(provider.erroCnpjApiDown, isTrue);
    });

    test('buscandoCnpj é true durante a busca e false após', () async {
      final buscandoValues = <bool>[];
      when(() => mockApi.buscarCnpj(any())).thenAnswer((_) async {
        buscandoValues.add(provider.buscandoCnpj);
        return _buildCnpjResponse();
      });

      await provider.buscarCnpj(cnpj);

      expect(buscandoValues, [true]);
      expect(provider.buscandoCnpj, isFalse);
    });
  });

  // ── salvarMedico ───────────────────────────────────────────────────────────

  group('salvarMedico()', () {
    setUp(() {
      provider.setPerfil(
        nome: 'Dr. Novo',
        cpf: '529.982.247-25',
        crm: '99999',
        ufCrm: 'MG',
        especialidade: null,
        email: 'novo@medvie.com',
        telefone: '31888880000',
      );
      when(() => mockApi.registrar(any(), any())).thenAnswer((_) async {});
      when(() => mockApi.login(any(), any())).thenAnswer((_) async {});
    });

    test('sucesso → medicoIdSalvo preenchido, salvandoMedico false', () async {
      when(() => mockApi.cadastrarMedico(any(), any()))
          .thenAnswer((_) async => 'medico-id-xyz');

      await provider.salvarMedico('senha@123');

      expect(provider.medicoIdSalvo, 'medico-id-xyz');
      expect(provider.salvandoMedico, isFalse);
    });

    test('não chama API se medicoIdSalvo já definido', () async {
      provider.medicoIdSalvo = 'ja-existe';

      await provider.salvarMedico('senha@123');

      verifyNever(() => mockApi.registrar(any(), any()));
      verifyNever(() => mockApi.cadastrarMedico(any(), any()));
    });

    test('erro na API → relança exceção, salvandoMedico = false', () async {
      when(() => mockApi.cadastrarMedico(any(), any()))
          .thenThrow(Exception('Erro interno'));

      await expectLater(
        () async => provider.salvarMedico('senha@123'),
        throwsA(isA<Exception>()),
      );

      expect(provider.salvandoMedico, isFalse);
    });

    test('salvandoMedico = true durante execução', () async {
      final estadosDurante = <bool>[];
      when(() => mockApi.cadastrarMedico(any(), any())).thenAnswer((_) async {
        estadosDurante.add(provider.salvandoMedico);
        return 'medico-id-async';
      });

      await provider.salvarMedico('senha@123');

      expect(estadosDurante, [true]);
      expect(provider.salvandoMedico, isFalse);
    });
  });

  // ── finalizar ──────────────────────────────────────────────────────────────

  group('finalizar()', () {
    setUp(() {
      provider.medicoIdSalvo = 'med-finalizar';
      provider.nome = 'Dr. Final';
      provider.cpf = '529.982.247-25';
      provider.crm = '88888';
      provider.ufCrm = 'RS';
      provider.email = 'final@medvie.com';
    });

    test('sucesso → onboardingCompletoFlag = true, medico construído', () async {
      when(() => mockApi.finalizarOnboarding(any())).thenAnswer((_) async {});

      await provider.finalizar();

      expect(provider.onboardingCompletoFlag, isTrue);
      expect(provider.medico, isNotNull);
      expect(provider.medico!.id, 'med-finalizar');
      expect(provider.medico!.nome, 'Dr. Final');
      expect(provider.erroFinalizar, isNull);
    });

    test('erro na API → erroFinalizar preenchido, onboardingCompletoFlag = false',
        () async {
      when(() => mockApi.finalizarOnboarding(any()))
          .thenThrow(Exception('Servidor indisponível'));

      await provider.finalizar();

      expect(provider.onboardingCompletoFlag, isFalse);
      expect(provider.erroFinalizar, isNotNull);
      expect(provider.medico, isNull);
    });

    test('notifica listeners em sucesso e erro', () async {
      when(() => mockApi.finalizarOnboarding(any())).thenAnswer((_) async {});
      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      await provider.finalizar();

      // Pelo menos 2 notificações: ao limpar erro + ao finalizar
      expect(notificacoes, greaterThanOrEqualTo(2));
    });
  });

  // ── resetarSessao ──────────────────────────────────────────────────────────

  group('resetarSessao()', () {
    test('limpa todos os campos de estado e notifica listeners', () {
      // Preenche estado antes
      provider.nome = 'Dr. Reset';
      provider.cpf = '529.982.247-25';
      provider.medicoIdSalvo = 'algum-id';
      provider.medico = _buildMedico();
      provider.stepAtual = 3;
      provider.onboardingCompletoFlag = true;

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      provider.resetarSessao();

      expect(provider.nome, '');
      expect(provider.cpf, '');
      expect(provider.medicoIdSalvo, isNull);
      expect(provider.medico, isNull);
      expect(provider.stepAtual, 0);
      expect(provider.onboardingCompletoFlag, isFalse);
      expect(provider.cnpjsFinalizados, isEmpty);
      expect(provider.tomadoresAtual, isEmpty);
      expect(provider.salvandoMedico, isFalse);
      expect(notificacoes, 1);
    });
  });

  // ── adicionarCnpj ──────────────────────────────────────────────────────────

  group('adicionarCnpj()', () {
    test('medico null → retorna mensagem de erro sem chamar API', () async {
      provider.medico = null;

      final erro = await provider.adicionarCnpj('11222333000181');

      expect(erro, isNotNull);
      verifyNever(() => mockApi.buscarCnpj(any()));
    });

    test('CNPJ já cadastrado → retorna mensagem de erro', () async {
      provider.medico = _buildMedico(cnpjs: [
        CnpjComTomadores(
          cnpj: '11222333000181',
          razaoSocial: 'Empresa Já Existe',
          municipio: 'SP',
          tomadores: [],
          inscricaoMunicipal: '',
          regime: RegimeTributario.simplesNacional,
          metodoAssinatura: MetodoAssinatura.certificadoA1,
          statusCertificado: StatusCertificado.pendente,
        ),
      ]);

      final erro = await provider.adicionarCnpj('11222333000181');

      expect(erro, contains('já está cadastrado'));
      verifyNever(() => mockApi.buscarCnpj(any()));
    });

    test('CNPJ não encontrado na Receita → retorna mensagem de erro', () async {
      provider.medico = _buildMedico();
      when(() => mockApi.buscarCnpj(any()))
          .thenThrow(Exception('not found'));

      final erro = await provider.adicionarCnpj('99999999000199');

      expect(erro, contains('Receita Federal'));
    });

    test('sucesso → CNPJ adicionado ao médico, retorna null', () async {
      provider.medico = _buildMedico();
      when(() => mockApi.buscarCnpj(any()))
          .thenAnswer((_) async => _buildCnpjResponse(razaoSocial: 'Nova LTDA'));

      final erro = await provider.adicionarCnpj('11222333000181');

      expect(erro, isNull);
      expect(provider.medico!.cnpjs.length, 1);
      expect(provider.medico!.cnpjs.first.razaoSocial, 'Nova LTDA');
    });

    test('CNPJ com máscara → normaliza para digits antes de buscar', () async {
      provider.medico = _buildMedico();
      when(() => mockApi.buscarCnpj('11222333000181'))
          .thenAnswer((_) async => _buildCnpjResponse());

      final erro = await provider.adicionarCnpj('11.222.333/0001-81');

      expect(erro, isNull);
      verify(() => mockApi.buscarCnpj('11222333000181')).called(1);
    });
  });

  // ── ativarModoManual ───────────────────────────────────────────────────────

  test('ativarModoManual() preenche cnpjAtual e limpa erros', () {
    provider.erroCnpj = 'Algum erro';
    provider.erroCnpjApiDown = true;

    provider.ativarModoManual('11222333000181');

    expect(provider.cnpjAtual, '11222333000181');
    expect(provider.razaoSocialAtual, '');
    expect(provider.erroCnpj, isNull);
    expect(provider.erroCnpjApiDown, isFalse);
  });

  // ── onboardingCompleto ─────────────────────────────────────────────────────

  group('onboardingCompleto()', () {
    test('retorna false quando medico é null', () {
      expect(provider.onboardingCompleto(), isFalse);
    });

    test('retorna true quando medico está definido', () {
      provider.medico = _buildMedico();
      expect(provider.onboardingCompleto(), isTrue);
    });
  });

  // ── mostrarStep3 ───────────────────────────────────────────────────────────

  group('mostrarStep3', () {
    test('false para medicoClinico', () {
      provider.perfilAtuacao = PerfilAtuacao.medicoClinico;
      expect(provider.mostrarStep3, isFalse);
    });

    test('true para plantonistaHospitalar', () {
      provider.perfilAtuacao = PerfilAtuacao.plantonistaHospitalar;
      expect(provider.mostrarStep3, isTrue);
    });
  });
}
