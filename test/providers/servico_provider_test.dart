// test/providers/servico_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/models/servico.dart';
import 'package:medvie/core/models/nota_fiscal.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────────────────────────────────────

class _MockApi extends Mock implements MedvieApiService {}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Adiciona um serviço simples ao provider (modo offline/sem cnpjProprioId)
/// e retorna o id gerado.
Future<String> _addServico(
  ServicoProvider provider, {
  DateTime? data,
  double valor = 1000.0,
  StatusServico status = StatusServico.pendente,
  String? tomadorId,
  String tomadorNome = 'Hospital Teste',
}) async {
  await provider.adicionarServico(
    tipo: TipoServico.plantao,
    data: data ?? DateTime(2026, 4, 15),
    tomadorCnpj: '00.000.000/0001-00',
    tomadorNome: tomadorNome,
    tomadorId: tomadorId,
    valor: valor,
    status: status,
  );
  return provider.servicos.last.id;
}

// ─────────────────────────────────────────────────────────────────────────────
// Testes
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(<String, String>{});
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Estado inicial e carregamento
  // ══════════════════════════════════════════════════════════════════════════

  test('estado inicial — servicos vazio, carregando false', () {
    final provider = ServicoProvider();
    expect(provider.servicos, isEmpty);
    expect(provider.carregando, false);
  });

  test('carregar() sem API → lista fica vazia', () async {
    final provider = ServicoProvider();
    await provider.carregar();
    expect(provider.servicos, isEmpty);
    expect(provider.carregando, false);
  });

  test('carregar() notifica listeners ao iniciar e ao concluir', () async {
    final provider = ServicoProvider();
    int notificacoes = 0;
    provider.addListener(() => notificacoes++);

    await provider.carregar();

    // Notifica 2x: ao setar _carregando=true e ao finalizar _carregando=false
    expect(notificacoes, 2);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // filtrarPorDia / limparFiltro
  // ══════════════════════════════════════════════════════════════════════════

  test('filtrarPorDia → servicosFiltrados contém só serviços do dia', () async {
    final dia = DateTime(2026, 4, 10);
    final outroDia = DateTime(2026, 4, 20);
    final provider = ServicoProvider();

    await _addServico(provider, data: dia);
    await _addServico(provider, data: dia);
    await _addServico(provider, data: outroDia);

    provider.filtrarPorDia(dia);

    expect(provider.servicosFiltrados.length, 2);
    expect(
      provider.servicosFiltrados.every(
        (s) =>
            s.data.year == dia.year &&
            s.data.month == dia.month &&
            s.data.day == dia.day,
      ),
      isTrue,
    );
  });

  test('limparFiltro → servicosFiltrados volta a == servicos', () async {
    final dia = DateTime(2026, 4, 10);
    final provider = ServicoProvider();

    await _addServico(provider, data: dia);
    await _addServico(provider, data: DateTime(2026, 4, 11));
    await _addServico(provider, data: DateTime(2026, 4, 12));

    provider.filtrarPorDia(dia);
    expect(provider.servicosFiltrados.length, 1);

    provider.limparFiltro();
    expect(provider.servicosFiltrados.length, provider.servicos.length);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // atualizarServico()
  // ══════════════════════════════════════════════════════════════════════════

  group('atualizarServico()', () {
    test('substitui servico existente por id e notifica listeners', () async {
      final provider = ServicoProvider();
      final id = await _addServico(provider, valor: 1000.0);

      final atualizado = (provider.servicos.first).copyWith(
        tomadorNome: 'Nome Atualizado',
        valor: 2500.0,
        status: StatusServico.pago,
      );

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);
      await provider.atualizarServico(atualizado);

      expect(provider.servicos.length, 1);
      expect(provider.servicos.first.tomadorNome, 'Nome Atualizado');
      expect(provider.servicos.first.valor, 2500.0);
      expect(provider.servicos.first.status, StatusServico.pago);
      expect(notificacoes, 1);
    });

    test('id não encontrado → lista permanece inalterada', () async {
      final provider = ServicoProvider();
      final id = await _addServico(provider);

      await provider.atualizarServico(Servico(
        id: 'id-inexistente',
        tipo: TipoServico.plantao,
        data: DateTime.now(),
        tomadorCnpj: '',
        tomadorNome: '',
        valor: 0,
        status: StatusServico.pendente,
      ));

      expect(provider.servicos.length, 1);
      expect(provider.servicos.first.id, id);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // removerServico()
  // ══════════════════════════════════════════════════════════════════════════

  group('removerServico()', () {
    test('remove serviço por id e notifica listeners', () async {
      final provider = ServicoProvider();
      final id1 = await _addServico(provider, tomadorNome: 'Hospital A');
      final id2 = await _addServico(provider, tomadorNome: 'Hospital B');

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);
      await provider.removerServico(id1);

      expect(provider.servicos.length, 1);
      expect(provider.servicos.first.id, id2);
      expect(notificacoes, 1);
    });

    test('id inexistente → lista inalterada', () async {
      final provider = ServicoProvider();
      await _addServico(provider);

      await provider.removerServico('nao-existe');

      expect(provider.servicos.length, 1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // adicionarServico() — modo offline
  // ══════════════════════════════════════════════════════════════════════════

  group('adicionarServico() — offline', () {
    test('adiciona à lista local e notifica listeners', () async {
      final provider = ServicoProvider();

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      await provider.adicionarServico(
        tipo: TipoServico.plantao,
        data: DateTime(2026, 5, 1),
        tomadorCnpj: '11.111.111/0001-11',
        tomadorNome: 'Hospital Offline',
        valor: 500.0,
        status: StatusServico.pendente,
      );

      expect(provider.servicos.length, 1);
      expect(provider.servicos.first.tomadorNome, 'Hospital Offline');
      expect(provider.servicos.first.valor, 500.0);
      expect(notificacoes, 1);
    });

    test('múltiplos adicionarServico acumulam na lista', () async {
      final provider = ServicoProvider();

      await _addServico(provider, tomadorNome: 'A');
      await _addServico(provider, tomadorNome: 'B');

      expect(provider.servicos.length, 2);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // adicionarServico() — modo online (com API)
  // ══════════════════════════════════════════════════════════════════════════

  group('adicionarServico() — online', () {
    late _MockApi mockApi;

    setUp(() {
      mockApi = _MockApi();
    });

    test('sucesso → chama criarServico, insere na lista e recarrega', () async {
      when(() => mockApi.criarServico(any(), any())).thenAnswer((_) async => {
            'servicoId': 'srv-backend-001',
            'brutoAcumuladoMes': 1000.0,
            'liquidoEstimadoMes': 900.0,
            'metaMensal': 5000.0,
          });

      when(() => mockApi.listarServicos(
            any(),
            pagina: any(named: 'pagina'),
            tamanhoPagina: any(named: 'tamanhoPagina'),
          )).thenAnswer((_) async => [
            {
              'id': 'srv-backend-001',
              'tipoServico': 'PlantaoClinico',
              'competencia': '2026-05-01',
              'tomadorCnpj': '11.111.111/0001-11',
              'tomadorNome': 'Hospital Online',
              'valor': 1000.0,
              'status': 'pendente',
            }
          ]);

      final provider = ServicoProvider(api: mockApi);

      await provider.adicionarServico(
        tipo: TipoServico.plantao,
        data: DateTime(2026, 5, 1),
        tomadorCnpj: '11.111.111/0001-11',
        tomadorNome: 'Hospital Online',
        valor: 1000.0,
        status: StatusServico.pendente,
        cnpjProprioId: 'cnpj-id-001',
      );

      verify(() => mockApi.criarServico('cnpj-id-001', any())).called(1);
      expect(provider.servicos.length, 1);
    });

    test('erro na API → lança Exception sem modificar estado', () async {
      when(() => mockApi.criarServico(any(), any()))
          .thenThrow(Exception('Backend indisponível'));

      final provider = ServicoProvider(api: mockApi);

      await expectLater(
        () async => provider.adicionarServico(
          tipo: TipoServico.plantao,
          data: DateTime(2026, 5, 1),
          tomadorCnpj: '11.111.111/0001-11',
          tomadorNome: 'Hospital',
          valor: 500.0,
          status: StatusServico.pendente,
          cnpjProprioId: 'cnpj-id-001',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // emitirNf()
  // ══════════════════════════════════════════════════════════════════════════

  group('emitirNf()', () {
    late _MockApi mockApiServico;
    late _MockApi mockApiNota;

    setUp(() {
      mockApiServico = _MockApi();
      mockApiNota = _MockApi();

      // Stub para listarServicos (chamado no reload pós-emissão após 3s)
      when(() => mockApiServico.listarServicos(
            any(),
            pagina: any(named: 'pagina'),
            tamanhoPagina: any(named: 'tamanhoPagina'),
          )).thenAnswer((_) async => []);

      // Stub para listarNotas (chamado pelo NotaFiscalProvider.carregar após 3s)
      when(() => mockApiNota.listarNotas(
            any(),
            status: any(named: 'status'),
            competenciaDe: any(named: 'competenciaDe'),
            competenciaAte: any(named: 'competenciaAte'),
            pagina: any(named: 'pagina'),
            tamanhoPagina: any(named: 'tamanhoPagina'),
          )).thenAnswer((_) async => []);
    });

    test('api não injetada → lança Exception imediatamente', () async {
      final provider = ServicoProvider(); // sem API
      final nfProvider = NotaFiscalProvider(mockApiNota);

      await expectLater(
        () => provider.emitirNf('qualquer', nfProvider, 'cnpj-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('servicoId não encontrado → retorna false', () async {
      final provider = ServicoProvider(api: mockApiServico);
      final nfProvider = NotaFiscalProvider(mockApiNota);

      final result = await provider.emitirNf('id-nao-existe', nfProvider, 'cnpj-id');

      expect(result, isFalse);
    });

    test('servico com status que não é pendenteDEmissao → retorna false', () async {
      final provider = ServicoProvider(api: mockApiServico);
      final id = await _addServico(provider,
          tomadorId: 'tomador-id', status: StatusServico.nfEmitida);
      final nfProvider = NotaFiscalProvider(mockApiNota);

      final result = await provider.emitirNf(id, nfProvider, 'cnpj-id');

      expect(result, isFalse);
    });

    test('servico sem tomadorId → lança Exception', () async {
      final provider = ServicoProvider(api: mockApiServico);
      final id = await _addServico(provider, valor: 500.0);
      // tomadorId não definido
      final nfProvider = NotaFiscalProvider(mockApiNota);

      await expectLater(
        () => provider.emitirNf(id, nfProvider, 'cnpj-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('sucesso → retorna true, status muda para nfEmProcessamento', () async {
      final provider = ServicoProvider(api: mockApiServico);
      final id = await _addServico(provider, tomadorId: 'tomador-uuid-123');
      final nfProvider = NotaFiscalProvider(mockApiNota);

      when(() => mockApiServico.emitirNota(
            servicoId: any(named: 'servicoId'),
            cnpjProprioId: any(named: 'cnpjProprioId'),
            tomadorId: any(named: 'tomadorId'),
            aliquotaIss: any(named: 'aliquotaIss'),
            issRetido: any(named: 'issRetido'),
          )).thenAnswer((_) async => 'nota-id-sucesso');

      final result = await provider.emitirNf(id, nfProvider, 'cnpj-proprio-id');

      expect(result, isTrue);
      expect(
        provider.servicos.firstWhere((sv) => sv.id == id).status,
        StatusServico.nfEmProcessamento,
      );
    });

    test('sucesso → nota adicionada ao NotaFiscalProvider', () async {
      final provider = ServicoProvider(api: mockApiServico);
      final id = await _addServico(provider, tomadorId: 'tomador-uuid-123');
      final nfProvider = NotaFiscalProvider(mockApiNota);

      when(() => mockApiServico.emitirNota(
            servicoId: any(named: 'servicoId'),
            cnpjProprioId: any(named: 'cnpjProprioId'),
            tomadorId: any(named: 'tomadorId'),
            aliquotaIss: any(named: 'aliquotaIss'),
            issRetido: any(named: 'issRetido'),
          )).thenAnswer((_) async => 'nota-adicionada-id');

      await provider.emitirNf(id, nfProvider, 'cnpj-proprio-id');

      expect(nfProvider.notas.length, 1);
      expect(nfProvider.notas.first.id, 'nota-adicionada-id');
      expect(nfProvider.notas.first.status, StatusNota.emProcessamento);
    });

    test('erro na API → status reverte para pendente e relança exceção', () async {
      final provider = ServicoProvider(api: mockApiServico);
      final id = await _addServico(provider, tomadorId: 'tomador-uuid-123');
      final nfProvider = NotaFiscalProvider(mockApiNota);

      when(() => mockApiServico.emitirNota(
            servicoId: any(named: 'servicoId'),
            cnpjProprioId: any(named: 'cnpjProprioId'),
            tomadorId: any(named: 'tomadorId'),
            aliquotaIss: any(named: 'aliquotaIss'),
            issRetido: any(named: 'issRetido'),
          )).thenThrow(Exception('Falha de rede'));

      await expectLater(
        () => provider.emitirNf(id, nfProvider, 'cnpj-proprio-id'),
        throwsA(isA<Exception>()),
      );

      expect(
        provider.servicos.firstWhere((sv) => sv.id == id).status,
        StatusServico.pendente,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // carregarMais()
  // ══════════════════════════════════════════════════════════════════════════

  group('carregarMais()', () {
    late _MockApi mockApi;

    setUp(() {
      mockApi = _MockApi();
    });

    test('no-op se ServicoProvider sem API', () async {
      final provider = ServicoProvider(); // sem API

      await provider.carregarMais('cnpj-id');

      expect(provider.carregandoMais, isFalse);
      verifyNever(() => mockApi.listarServicos(
            any(),
            pagina: any(named: 'pagina'),
            tamanhoPagina: any(named: 'tamanhoPagina'),
          ));
    });

    test('no-op se temMais = false (lista menor que página)', () async {
      when(() => mockApi.listarServicos(
            any(),
            pagina: any(named: 'pagina'),
            tamanhoPagina: any(named: 'tamanhoPagina'),
          )).thenAnswer((_) async => []); // lista vazia → temMais = false

      final provider = ServicoProvider(api: mockApi);
      await provider.carregar(cnpjProprioId: 'cnpj-id');

      expect(provider.temMais, isFalse);

      await provider.carregarMais('cnpj-id');

      // listarServicos foi chamado apenas uma vez (pelo carregar inicial)
      verify(() => mockApi.listarServicos(
            any(),
            pagina: any(named: 'pagina'),
            tamanhoPagina: any(named: 'tamanhoPagina'),
          )).called(1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Getters computados
  // ══════════════════════════════════════════════════════════════════════════

  group('getters computados', () {
    test('totalBruto soma apenas serviços não cancelados', () async {
      final provider = ServicoProvider();
      await _addServico(provider, valor: 1000.0, status: StatusServico.pendente);
      await _addServico(provider, valor: 500.0, status: StatusServico.cancelado);

      expect(provider.totalBruto, 1000.0);
    });

    test('pendentesDEmissao inclui só pendente e é ordenado por data', () async {
      final provider = ServicoProvider();
      final id1 = await _addServico(provider,
          data: DateTime(2026, 4, 20), status: StatusServico.pendente);
      final id2 = await _addServico(provider,
          data: DateTime(2026, 4, 10), status: StatusServico.pendente);
      await _addServico(provider,
          data: DateTime(2026, 4, 5), status: StatusServico.nfEmitida);

      expect(provider.pendentesDEmissao.length, 2);
      expect(provider.pendentesDEmissao.first.id, id2); // data mais antiga
      expect(provider.pendentesDEmissao.last.id, id1);  // data mais recente
      expect(provider.countPendentesNf, 2);
    });
  });
}
