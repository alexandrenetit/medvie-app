// test/providers/relatorio_anual_provider_test.dart
//
// Testes unitários do RelatorioAnualProvider e seus modelos de dados.
// Cobre: carregar (sucesso, erro, no-op duplicado, no-op isLoading),
// recarregar, listeners e modelos (fromJson, brutosPorMes).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/providers/relatorio_anual_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockApi extends Mock implements MedvieApiService {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _relatorioJson({
  int ano = 2026,
  double totalBruto = 120000.0,
  double totalLiquido = 108000.0,
  double totalImpostos = 12000.0,
  List<Map<String, dynamic>>? meses,
}) =>
    {
      'ano': ano,
      'totalBruto': totalBruto,
      'totalLiquido': totalLiquido,
      'totalImpostos': totalImpostos,
      'meses': meses ??
          [
            {
              'mes': 1,
              'totalBruto': 10000.0,
              'totalLiquido': 9000.0,
              'totalImpostos': 1000.0,
              'tomadores': [
                {
                  'nome': 'Hospital A',
                  'cnpj': '11.222.333/0001-81',
                  'totalBruto': 10000.0,
                },
              ],
            },
            {
              'mes': 4,
              'totalBruto': 15000.0,
              'totalLiquido': 13500.0,
              'totalImpostos': 1500.0,
              'tomadores': [],
            },
          ],
    };

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  late _MockApi mockApi;
  late RelatorioAnualProvider provider;

  setUp(() {
    mockApi = _MockApi();
    provider = RelatorioAnualProvider(api: mockApi);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Estado inicial
  // ══════════════════════════════════════════════════════════════════════════

  test('estado inicial — data null, isLoading false, erro null', () {
    expect(provider.data, isNull);
    expect(provider.isLoading, isFalse);
    expect(provider.erro, isNull);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // carregar()
  // ══════════════════════════════════════════════════════════════════════════

  group('carregar()', () {
    test('sucesso → data preenchido, isLoading false, erro null', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());

      await provider.carregar('cnpj-id', 2026);

      expect(provider.data, isNotNull);
      expect(provider.data!.ano, 2026);
      expect(provider.data!.totalBruto, 120000.0);
      expect(provider.data!.meses.length, 2);
      expect(provider.isLoading, isFalse);
      expect(provider.erro, isNull);
    });

    test('erro de rede → erro preenchido, data permanece null', () async {
      when(() => mockApi.getJson(any()))
          .thenThrow(Exception('timeout'));

      await provider.carregar('cnpj-id', 2026);

      expect(provider.erro, isNotNull);
      expect(provider.erro, contains('timeout'));
      expect(provider.data, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('URL construída com cnpjProprioId e ano corretos', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());

      await provider.carregar('cnpj-abc-123', 2025);

      final captured =
          verify(() => mockApi.getJson(captureAny())).captured.first as String;
      expect(captured, contains('cnpjProprioId=cnpj-abc-123'));
      expect(captured, contains('ano=2025'));
    });

    test('notifica listeners ao iniciar (isLoading=true) e ao concluir', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());

      final estados = <bool>[];
      provider.addListener(() => estados.add(provider.isLoading));

      await provider.carregar('cnpj-id', 2026);

      expect(estados.length, 2);
      expect(estados.first, isTrue);
      expect(estados.last, isFalse);
    });

    test('no-op enquanto isLoading=true (chamada concorrente ignorada)', () async {
      // Simula chamada lenta: segura a Future até liberarmos
      final completer = Completer<Map<String, dynamic>>();
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) => completer.future);

      // Inicia primeira chamada (não aguarda)
      final f1 = provider.carregar('cnpj-id', 2026);
      expect(provider.isLoading, isTrue);

      // Segunda chamada — deve ser ignorada (no-op)
      await provider.carregar('cnpj-id', 2026);

      // getJson deve ter sido chamado apenas uma vez
      verify(() => mockApi.getJson(any())).called(1);

      // Libera a primeira
      completer.complete(_relatorioJson());
      await f1;
    });

    test('no-op para mesmo par (cnpjId, ano) já carregado', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());

      await provider.carregar('cnpj-id', 2026);
      await provider.carregar('cnpj-id', 2026); // segunda chamada idêntica

      // getJson chamado uma única vez
      verify(() => mockApi.getJson(any())).called(1);
    });

    test('permite recarregar para ano diferente', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson(ano: 2025));
      await provider.carregar('cnpj-id', 2025);

      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson(ano: 2026));
      await provider.carregar('cnpj-id', 2026);

      expect(provider.data!.ano, 2026);
      verify(() => mockApi.getJson(any())).called(2);
    });

    test('permite recarregar para cnpjId diferente', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());
      await provider.carregar('cnpj-a', 2026);

      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson(totalBruto: 50000.0));
      await provider.carregar('cnpj-b', 2026);

      expect(provider.data!.totalBruto, 50000.0);
      verify(() => mockApi.getJson(any())).called(2);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // recarregar()
  // ══════════════════════════════════════════════════════════════════════════

  group('recarregar()', () {
    test('força chamada mesmo com cache válido', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());

      await provider.carregar('cnpj-id', 2026);
      // Segundo carregar normal seria no-op
      await provider.carregar('cnpj-id', 2026);
      verify(() => mockApi.getJson(any())).called(1);

      // Recarregar deve forçar nova chamada
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson(totalBruto: 99000.0));
      await provider.recarregar('cnpj-id', 2026);

      expect(provider.data!.totalBruto, 99000.0);
      verify(() => mockApi.getJson(any())).called(1);
    });

    test('notifica listeners após recarregar', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());
      await provider.carregar('cnpj-id', 2026);

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _relatorioJson());
      await provider.recarregar('cnpj-id', 2026);

      expect(notificacoes, greaterThanOrEqualTo(2));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Modelos: RelatorioAnualResponse, RelatorioAnualMes, RelatorioAnualTomador
  // ══════════════════════════════════════════════════════════════════════════

  group('RelatorioAnualResponse.fromJson', () {
    test('parseia todos os campos corretamente', () {
      final r = RelatorioAnualResponse.fromJson(_relatorioJson());

      expect(r.ano, 2026);
      expect(r.totalBruto, 120000.0);
      expect(r.totalLiquido, 108000.0);
      expect(r.totalImpostos, 12000.0);
      expect(r.meses.length, 2);
    });

    test('meses vazios → lista vazia', () {
      final r = RelatorioAnualResponse.fromJson(
          _relatorioJson(meses: []));
      expect(r.meses, isEmpty);
    });

    test('campos nulos → defaults para 0', () {
      final r = RelatorioAnualResponse.fromJson({
        'ano': null,
        'totalBruto': null,
        'totalLiquido': null,
        'totalImpostos': null,
        'meses': null,
      });
      expect(r.ano, 0);
      expect(r.totalBruto, 0.0);
      expect(r.meses, isEmpty);
    });
  });

  group('RelatorioAnualResponse.brutosPorMes', () {
    test('retorna lista de tamanho 12', () {
      final r = RelatorioAnualResponse.fromJson(_relatorioJson());
      expect(r.brutosPorMes.length, 12);
    });

    test('posiciona corretamente por índice (mes-1)', () {
      final r = RelatorioAnualResponse.fromJson(_relatorioJson());
      expect(r.brutosPorMes[0], 10000.0); // jan (mes=1)
      expect(r.brutosPorMes[3], 15000.0); // abr (mes=4)
      // demais meses = 0
      expect(r.brutosPorMes[1], 0.0);
      expect(r.brutosPorMes[11], 0.0);
    });

    test('mes fora do intervalo [1,12] é ignorado', () {
      final r = RelatorioAnualResponse.fromJson(_relatorioJson(meses: [
        {
          'mes': 0,
          'totalBruto': 999.0,
          'totalLiquido': 0.0,
          'totalImpostos': 0.0,
          'tomadores': [],
        },
        {
          'mes': 13,
          'totalBruto': 888.0,
          'totalLiquido': 0.0,
          'totalImpostos': 0.0,
          'tomadores': [],
        },
      ]));
      expect(r.brutosPorMes.every((v) => v == 0.0), isTrue);
    });

    test('sem meses → todos os valores são 0', () {
      final r = RelatorioAnualResponse.fromJson(_relatorioJson(meses: []));
      expect(r.brutosPorMes, List.filled(12, 0.0));
    });
  });

  group('RelatorioAnualMes.fromJson', () {
    test('parseia mes e totais', () {
      final m = RelatorioAnualMes.fromJson({
        'mes': 6,
        'totalBruto': 5000.0,
        'totalLiquido': 4500.0,
        'totalImpostos': 500.0,
        'tomadores': [],
      });
      expect(m.mes, 6);
      expect(m.totalBruto, 5000.0);
      expect(m.tomadores, isEmpty);
    });

    test('parseia tomadores corretamente', () {
      final m = RelatorioAnualMes.fromJson({
        'mes': 3,
        'totalBruto': 3000.0,
        'totalLiquido': 2700.0,
        'totalImpostos': 300.0,
        'tomadores': [
          {'nome': 'Hospital B', 'cnpj': '00.000.000/0001-00', 'totalBruto': 3000.0},
        ],
      });
      expect(m.tomadores.length, 1);
      expect(m.tomadores.first.nome, 'Hospital B');
    });
  });

  group('RelatorioAnualTomador.fromJson', () {
    test('parseia todos os campos', () {
      final t = RelatorioAnualTomador.fromJson({
        'nome': 'Clínica X',
        'cnpj': '11.111.111/0001-11',
        'totalBruto': 7500.0,
      });
      expect(t.nome, 'Clínica X');
      expect(t.cnpj, '11.111.111/0001-11');
      expect(t.totalBruto, 7500.0);
    });

    test('campos nulos → defaults', () {
      final t = RelatorioAnualTomador.fromJson(
          {'nome': null, 'cnpj': null, 'totalBruto': null});
      expect(t.nome, '');
      expect(t.cnpj, '');
      expect(t.totalBruto, 0.0);
    });
  });
}

