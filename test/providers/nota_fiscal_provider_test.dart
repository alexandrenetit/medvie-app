// test/providers/nota_fiscal_provider_test.dart
//
// Testes unitários do NotaFiscalProvider.
// Cobre: carregar (sucesso, erro, filtros), mutações
// (adicionarNotaLocal, atualizarNota, removerNota, limpar, cancelar)
// e getters computados (notasDoMes, countAutorizadasDoMes, porStatus).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/models/nota_fiscal.dart';
import 'package:medvie/core/models/notas_pagina.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';
import 'package:medvie/core/services/sse_service.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockApi extends Mock implements MedvieApiService {}

class _FakeSseService extends SseService {
  _FakeSseService(super.api);

  int conectarCalls = 0;
  int desconectarCalls = 0;

  @override
  void conectar() {
    conectarCalls++;
  }

  @override
  void desconectar() {
    desconectarCalls++;
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

NotaFiscal _buildNota({
  String id = 'nf-001',
  String status = 'emProcessamento',
  DateTime? createdAt,
  DateTime? updatedAt,
}) => NotaFiscal(
  id: id,
  status: status,
  codigoNbs: '1.0501',
  createdAt: createdAt ?? DateTime.utc(2026, 4, 15),
  updatedAt: updatedAt ?? createdAt ?? DateTime.utc(2026, 4, 15),
);

NotasPagina _buildNotasPagina(
  List<NotaFiscal> notas, {
  int? total,
  int pagina = 1,
  int tamanhoPagina = 20,
}) => NotasPagina(
  notas: notas,
  total: total ?? notas.length,
  pagina: pagina,
  tamanhoPagina: tamanhoPagina,
);

// Stub padrão para listarNotas (todos os named params opcionais)
void _stubListarNotas(
  _MockApi api,
  List<NotaFiscal> result, {
  int? total,
  int pagina = 1,
  int tamanhoPagina = 20,
}) {
  when(
    () => api.listarNotas(
      any(),
      status: any(named: 'status'),
      competenciaDe: any(named: 'competenciaDe'),
      competenciaAte: any(named: 'competenciaAte'),
      pagina: any(named: 'pagina'),
      tamanhoPagina: any(named: 'tamanhoPagina'),
    ),
  ).thenAnswer(
    (_) async => _buildNotasPagina(
      result,
      total: total,
      pagina: pagina,
      tamanhoPagina: tamanhoPagina,
    ),
  );
}

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  late _MockApi mockApi;
  late NotaFiscalProvider provider;

  setUp(() {
    mockApi = _MockApi();
    provider = NotaFiscalProvider(mockApi);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Estado inicial
  // ══════════════════════════════════════════════════════════════════════════

  test('estado inicial — notas vazio, carregando false, erro null', () {
    expect(provider.notas, isEmpty);
    expect(provider.total, 0);
    expect(provider.pagina, 1);
    expect(provider.tamanhoPagina, 20);
    expect(provider.temProximaPagina, isFalse);
    expect(provider.carregando, isFalse);
    expect(provider.erro, isNull);
  });

  group('SSE', () {
    test('conectarSse e idempotente para mesmo token', () {
      final sse = _FakeSseService(mockApi);
      provider = NotaFiscalProvider(mockApi, sseFactory: (_) => sse);

      provider.conectarSse();
      provider.conectarSse();

      expect(sse.conectarCalls, 1);
      expect(sse.desconectarCalls, 0);
    });

    test('dispose desconecta SSE antes de finalizar provider', () {
      final sse = _FakeSseService(mockApi);
      provider = NotaFiscalProvider(mockApi, sseFactory: (_) => sse);

      provider.conectarSse();
      provider.dispose();

      expect(sse.desconectarCalls, 1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // carregar()
  // ══════════════════════════════════════════════════════════════════════════

  group('carregar()', () {
    test('sucesso → notas preenchidas, carregando false, erro null', () async {
      final notas = [_buildNota(id: 'nf-1'), _buildNota(id: 'nf-2')];
      _stubListarNotas(mockApi, notas);

      await provider.carregar('cnpj-id');

      expect(provider.notas.length, 2);
      expect(provider.notas.first.id, 'nf-1');
      expect(provider.total, 2);
      expect(provider.pagina, 1);
      expect(provider.tamanhoPagina, 20);
      expect(provider.temProximaPagina, isFalse);
      expect(provider.carregando, isFalse);
      expect(provider.erro, isNull);
    });

    test('sucesso — substitui lista anterior', () async {
      _stubListarNotas(mockApi, [_buildNota(id: 'nf-a')]);
      await provider.carregar('cnpj-id');
      expect(provider.notas.length, 1);

      _stubListarNotas(mockApi, [
        _buildNota(id: 'nf-b'),
        _buildNota(id: 'nf-c'),
      ]);
      await provider.carregar('cnpj-id');

      expect(provider.notas.length, 2);
      expect(provider.notas.map((n) => n.id).toList(), ['nf-b', 'nf-c']);
    });

    test('sucesso -> expõe paginação retornada pela API', () async {
      final notas = [_buildNota(id: 'nf-1')];
      _stubListarNotas(mockApi, notas, total: 3, pagina: 1, tamanhoPagina: 20);

      await provider.carregar('cnpj-id');

      expect(provider.notas.length, 1);
      expect(provider.total, 3);
      expect(provider.pagina, 1);
      expect(provider.tamanhoPagina, 20);
      expect(provider.temProximaPagina, isTrue);
      verify(
        () => mockApi.listarNotas(
          'cnpj-id',
          status: any(named: 'status'),
          competenciaDe: any(named: 'competenciaDe'),
          competenciaAte: any(named: 'competenciaAte'),
          pagina: 1,
          tamanhoPagina: 20,
        ),
      ).called(1);
    });

    test('lista vazia -> paginação preservada', () async {
      _stubListarNotas(mockApi, [], total: 0, pagina: 1, tamanhoPagina: 20);

      await provider.carregar('cnpj-id');

      expect(provider.notas, isEmpty);
      expect(provider.total, 0);
      expect(provider.pagina, 1);
      expect(provider.tamanhoPagina, 20);
      expect(provider.temProximaPagina, isFalse);
    });

    test('erro de rede → erro preenchido, lista vazia', () async {
      when(
        () => mockApi.listarNotas(
          any(),
          status: any(named: 'status'),
          competenciaDe: any(named: 'competenciaDe'),
          competenciaAte: any(named: 'competenciaAte'),
          pagina: any(named: 'pagina'),
          tamanhoPagina: any(named: 'tamanhoPagina'),
        ),
      ).thenThrow(Exception('Connection refused'));

      await provider.carregar('cnpj-id');

      expect(provider.erro, isNotNull);
      expect(provider.erro, contains('Connection refused'));
      expect(provider.carregando, isFalse);
      expect(provider.notas, isEmpty);
    });

    test(
      'notifica listeners ao iniciar (carregando = true) e ao concluir',
      () async {
        _stubListarNotas(mockApi, []);
        final estados = <bool>[];
        provider.addListener(() => estados.add(provider.carregando));

        await provider.carregar('cnpj-id');

        // [true, false] — início + fim
        expect(estados.length, 2);
        expect(estados.first, isTrue);
        expect(estados.last, isFalse);
      },
    );

    test(
      'com mes/ano → passa competenciaDe e competenciaAte para a API',
      () async {
        _stubListarNotas(mockApi, []);

        await provider.carregar('cnpj-id', mes: 4, ano: 2026);

        final captured = verify(
          () => mockApi.listarNotas(
            any(),
            status: any(named: 'status'),
            competenciaDe: captureAny(named: 'competenciaDe'),
            competenciaAte: captureAny(named: 'competenciaAte'),
            pagina: any(named: 'pagina'),
            tamanhoPagina: any(named: 'tamanhoPagina'),
          ),
        ).captured;

        final de = captured[0] as DateTime;
        final ate = captured[1] as DateTime;
        expect(de.year, 2026);
        expect(de.month, 4);
        expect(ate.month, 4); // até o último dia de abril
        expect(ate.day, 30);
      },
    );

    test('sem mes/ano → competenciaDe e competenciaAte são null', () async {
      _stubListarNotas(mockApi, []);

      await provider.carregar('cnpj-id');

      final captured = verify(
        () => mockApi.listarNotas(
          any(),
          status: any(named: 'status'),
          competenciaDe: captureAny(named: 'competenciaDe'),
          competenciaAte: captureAny(named: 'competenciaAte'),
          pagina: any(named: 'pagina'),
          tamanhoPagina: any(named: 'tamanhoPagina'),
        ),
      ).captured;

      expect(captured[0], isNull);
      expect(captured[1], isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // adicionarNotaLocal()
  // ══════════════════════════════════════════════════════════════════════════

  group('adicionarNotaLocal()', () {
    test('adiciona nota à lista e notifica listeners', () {
      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      provider.adicionarNotaLocal(_buildNota(id: 'nf-local'));

      expect(provider.notas.length, 1);
      expect(provider.notas.first.id, 'nf-local');
      expect(notificacoes, 1);
    });

    test('múltiplas chamadas acumulam na lista', () {
      provider.adicionarNotaLocal(_buildNota(id: 'nf-a'));
      provider.adicionarNotaLocal(_buildNota(id: 'nf-b'));
      provider.adicionarNotaLocal(_buildNota(id: 'nf-c'));

      expect(provider.notas.length, 3);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // atualizarNota()
  // ══════════════════════════════════════════════════════════════════════════

  group('atualizarNota()', () {
    test('substitui nota existente por id e notifica listeners', () async {
      provider.adicionarNotaLocal(_buildNota(id: 'nf-001'));

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      await provider.atualizarNota(
        _buildNota(id: 'nf-001', status: StatusNota.autorizada.name),
      );

      expect(provider.notas.length, 1);
      expect(provider.notas.first.status, StatusNota.autorizada.name);
      expect(notificacoes, 1);
    });

    test('id não encontrado → no-op, lista inalterada', () async {
      provider.adicionarNotaLocal(_buildNota(id: 'nf-001'));

      await provider.atualizarNota(_buildNota(id: 'nf-nao-existe'));

      expect(provider.notas.length, 1);
      expect(provider.notas.first.id, 'nf-001');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // removerNota()
  // ══════════════════════════════════════════════════════════════════════════

  group('removerNota()', () {
    test('remove nota por id e notifica listeners', () async {
      provider.adicionarNotaLocal(_buildNota(id: 'nf-a'));
      provider.adicionarNotaLocal(_buildNota(id: 'nf-b'));

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      await provider.removerNota('nf-a');

      expect(provider.notas.length, 1);
      expect(provider.notas.first.id, 'nf-b');
      expect(notificacoes, 1);
    });

    test('id inexistente → lista inalterada', () async {
      provider.adicionarNotaLocal(_buildNota(id: 'nf-a'));

      await provider.removerNota('nf-fantasma');

      expect(provider.notas.length, 1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // limpar()
  // ══════════════════════════════════════════════════════════════════════════

  group('limpar()', () {
    test('remove todas as notas e notifica listeners', () async {
      provider.adicionarNotaLocal(_buildNota(id: 'nf-1'));
      provider.adicionarNotaLocal(_buildNota(id: 'nf-2'));

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      await provider.limpar();

      expect(provider.notas, isEmpty);
      expect(notificacoes, 1);
    });

    test('limpar() com lista vazia → no-op sem falha', () async {
      await provider.limpar();
      expect(provider.notas, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // cancelar()
  // ══════════════════════════════════════════════════════════════════════════

  group('cancelar()', () {
    test('chama cancelarNota na API e recarrega lista', () async {
      when(
        () => mockApi.cancelarNota(any(), any(), any()),
      ).thenAnswer((_) async {});
      _stubListarNotas(mockApi, []);

      await provider.cancelar('nf-id', 'cnpj-proprio-id', 'Duplicidade');

      verify(
        () => mockApi.cancelarNota('nf-id', 'cnpj-proprio-id', 'Duplicidade'),
      ).called(1);
      verify(
        () => mockApi.listarNotas(
          'cnpj-proprio-id',
          status: any(named: 'status'),
          competenciaDe: any(named: 'competenciaDe'),
          competenciaAte: any(named: 'competenciaAte'),
          pagina: any(named: 'pagina'),
          tamanhoPagina: any(named: 'tamanhoPagina'),
        ),
      ).called(1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // notasDoMes(), countAutorizadasDoMes()
  // ══════════════════════════════════════════════════════════════════════════

  group('notasDoMes()', () {
    setUp(() {
      provider.adicionarNotaLocal(
        _buildNota(id: 'abr-1', createdAt: DateTime.utc(2026, 4, 1)),
      );
      provider.adicionarNotaLocal(
        _buildNota(id: 'abr-2', createdAt: DateTime.utc(2026, 4, 20)),
      );
      provider.adicionarNotaLocal(
        _buildNota(id: 'mai-1', createdAt: DateTime.utc(2026, 5, 1)),
      );
    });

    test('filtra corretamente por mês/ano de createdAt', () {
      expect(provider.notasDoMes(2026, 4).length, 2);
      expect(provider.notasDoMes(2026, 5).length, 1);
      expect(provider.notasDoMes(2026, 6).length, 0);
    });

    test('resultado é ordenado por createdAt decrescente', () {
      final notas = provider.notasDoMes(2026, 4);
      expect(notas.first.id, 'abr-2'); // dia 20 é mais recente
      expect(notas.last.id, 'abr-1');
    });
  });

  group('countAutorizadasDoMes()', () {
    test('conta apenas notas autorizadas no mês', () {
      provider.adicionarNotaLocal(
        _buildNota(
          id: 'a1',
          status: StatusNota.autorizada.name,
          createdAt: DateTime.utc(2026, 4, 1),
        ),
      );
      provider.adicionarNotaLocal(
        _buildNota(
          id: 'a2',
          status: StatusNota.autorizada.name,
          createdAt: DateTime.utc(2026, 4, 5),
        ),
      );
      provider.adicionarNotaLocal(
        _buildNota(
          id: 'p1',
          status: StatusNota.emProcessamento.name,
          createdAt: DateTime.utc(2026, 4, 10),
        ),
      );

      expect(provider.countAutorizadasDoMes(2026, 4), 2);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // porStatus()
  // ══════════════════════════════════════════════════════════════════════════

  group('porStatus()', () {
    test('filtra corretamente por status', () {
      provider.adicionarNotaLocal(
        _buildNota(id: 'a1', status: StatusNota.autorizada.name),
      );
      provider.adicionarNotaLocal(
        _buildNota(id: 'a2', status: StatusNota.autorizada.name),
      );
      provider.adicionarNotaLocal(
        _buildNota(id: 'r1', status: StatusNota.rejeitada.name),
      );
      provider.adicionarNotaLocal(
        _buildNota(id: 'p1', status: StatusNota.emProcessamento.name),
      );

      expect(provider.porStatus(StatusNota.autorizada.name).length, 2);
      expect(provider.porStatus(StatusNota.rejeitada.name).length, 1);
      expect(provider.porStatus(StatusNota.cancelada.name).length, 0);
    });

    test('resultado é ordenado por createdAt decrescente', () {
      provider.adicionarNotaLocal(
        _buildNota(
          id: 'a-antiga',
          status: StatusNota.autorizada.name,
          createdAt: DateTime.utc(2026, 3, 1),
        ),
      );
      provider.adicionarNotaLocal(
        _buildNota(
          id: 'a-nova',
          status: StatusNota.autorizada.name,
          createdAt: DateTime.utc(2026, 4, 1),
        ),
      );

      final result = provider.porStatus(StatusNota.autorizada.name);
      expect(result.first.id, 'a-nova');
      expect(result.last.id, 'a-antiga');
    });
  });
}
