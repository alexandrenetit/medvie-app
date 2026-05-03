// test/providers/dashboard_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/providers/dashboard_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock
// ─────────────────────────────────────────────────────────────────────────────

class _MockMedvieApiService extends Mock implements MedvieApiService {}

// ─────────────────────────────────────────────────────────────────────────────
// Fixture JSON — espelha DashboardResponse.fromJson
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _dashboardJson({
  double totalBruto = 15000.0,
  int notasAutorizadas = 3,
}) =>
    {
      'totalBruto': totalBruto,
      'totalIss': 450.0,
      'totalIbs': 0.0,
      'totalCbs': 0.0,
      'totalLiquidoEstimado': 13500.0,
      'notasAutorizadas': notasAutorizadas,
      'notasPendentes': 1,
      'notasRejeitadas': 0,
      'metaMensal': 20000.0,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Testes
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late _MockMedvieApiService mockApi;
  late DashboardProvider provider;

  setUp(() {
    mockApi = _MockMedvieApiService();
    provider = DashboardProvider(mockApi);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Testes originais — carregar()
  // ══════════════════════════════════════════════════════════════════════════

  // 1 ─ estado inicial
  test('estado inicial — dashboard null, isLoading false, error null', () {
    expect(provider.dashboard, isNull);
    expect(provider.isLoading, false);
    expect(provider.error, isNull);
  });

  // 2 ─ cnpjProprioId vazio → early return, sem chamada HTTP
  test('carregar() com cnpjProprioId vazio → no-op, getJson não chamado',
      () async {
    await provider.carregar('', 4, 2026);

    expect(provider.dashboard, isNull);
    expect(provider.isLoading, false);
    verifyNever(() => mockApi.getJson(any()));
  });

  // 3 ─ sucesso
  test('carregar() sucesso → dashboard preenchido, isLoading false', () async {
    when(() => mockApi.getJson(any()))
        .thenAnswer((_) async => _dashboardJson());

    await provider.carregar('cnpj-id-123', 4, 2026);

    expect(provider.dashboard, isNotNull);
    expect(provider.dashboard!.totalBruto, 15000.0);
    expect(provider.dashboard!.notasAutorizadas, 3);
    expect(provider.isLoading, false);
    expect(provider.error, isNull);
  });

  // 4 ─ erro de rede
  test('carregar() erro de rede → error não-null, dashboard permanece null',
      () async {
    when(() => mockApi.getJson(any())).thenThrow(Exception('timeout'));

    await provider.carregar('cnpj-id-123', 4, 2026);

    expect(provider.error, isNotNull);
    expect(provider.dashboard, isNull);
    expect(provider.isLoading, false);
  });

  // 5 ─ listeners notificados
  test('carregar() sucesso notifica listeners ao iniciar e ao concluir',
      () async {
    when(() => mockApi.getJson(any()))
        .thenAnswer((_) async => _dashboardJson());

    int notificacoes = 0;
    provider.addListener(() => notificacoes++);

    await provider.carregar('cnpj-id-123', 4, 2026);

    expect(notificacoes, 2);
  });

  // 6 ─ segunda chamada substitui dados anteriores
  test('segunda carregar() sobrescreve dashboard anterior', () async {
    when(() => mockApi.getJson(any()))
        .thenAnswer((_) async => _dashboardJson(totalBruto: 5000.0));
    await provider.carregar('cnpj-id-123', 3, 2026);
    expect(provider.dashboard!.totalBruto, 5000.0);

    when(() => mockApi.getJson(any()))
        .thenAnswer((_) async => _dashboardJson(totalBruto: 9000.0));
    await provider.carregar('cnpj-id-123', 4, 2026);
    expect(provider.dashboard!.totalBruto, 9000.0);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // atualizarComTotais()
  // ══════════════════════════════════════════════════════════════════════════

  group('atualizarComTotais()', () {
    test('quando dashboard é null — cria DashboardResponse com os novos valores',
        () {
      expect(provider.dashboard, isNull);

      provider.atualizarComTotais(bruto: 8000.0, liquido: 7200.0, meta: 10000.0);

      expect(provider.dashboard, isNotNull);
      expect(provider.dashboard!.totalBruto, 8000.0);
      expect(provider.dashboard!.totalLiquidoEstimado, 7200.0);
      expect(provider.dashboard!.metaMensal, 10000.0);
    });

    test('quando dashboard já existe — atualiza bruto/liquido e preserva demais campos',
        () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _dashboardJson(
                totalBruto: 5000.0,
                notasAutorizadas: 2,
              ));
      await provider.carregar('cnpj-id', 4, 2026);
      expect(provider.dashboard!.notasAutorizadas, 2);

      provider.atualizarComTotais(
          bruto: 6500.0, liquido: 5800.0, meta: 20000.0);

      expect(provider.dashboard!.totalBruto, 6500.0);
      expect(provider.dashboard!.totalLiquidoEstimado, 5800.0);
      // Campos anteriores preservados
      expect(provider.dashboard!.notasAutorizadas, 2);
      expect(provider.dashboard!.totalIss, 450.0);
    });

    test('notifica listeners', () {
      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      provider.atualizarComTotais(bruto: 1000.0, liquido: 900.0, meta: 5000.0);

      expect(notificacoes, 1);
    });

    test('meta = 0 → preserva a meta anterior do dashboard', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _dashboardJson());
      await provider.carregar('cnpj-id', 4, 2026);
      expect(provider.dashboard!.metaMensal, 20000.0);

      // Envia meta 0 (backend não retornou meta no POST)
      provider.atualizarComTotais(bruto: 7000.0, liquido: 6300.0, meta: 0);

      expect(provider.dashboard!.metaMensal, 20000.0); // preservada
    });

    test('incrementa _skipCount → próximo carregar() é no-op', () async {
      provider.atualizarComTotais(bruto: 8000.0, liquido: 7200.0, meta: 10000.0);

      // O próximo carregar() deve ser ignorado (skipCount = 1)
      await provider.carregar('cnpj-id', 4, 2026);

      // getJson nunca foi chamado pois carregar() saiu por skipCount
      verifyNever(() => mockApi.getJson(any()));
      // dashboard permanece com os valores do atualizarComTotais
      expect(provider.dashboard!.totalBruto, 8000.0);
    });

    test('múltiplos atualizarComTotais → skipCount acumula, múltiplos carregar() são no-op',
        () async {
      provider.atualizarComTotais(bruto: 1000.0, liquido: 900.0, meta: 5000.0);
      provider.atualizarComTotais(bruto: 2000.0, liquido: 1800.0, meta: 5000.0);

      // Primeiro carregar → skip (decrementa de 2 para 1)
      await provider.carregar('cnpj-id', 4, 2026);
      // Segundo carregar → skip (decrementa de 1 para 0)
      await provider.carregar('cnpj-id', 4, 2026);

      verifyNever(() => mockApi.getJson(any()));

      // Terceiro carregar → chamada real
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _dashboardJson(totalBruto: 9999.0));
      await provider.carregar('cnpj-id', 4, 2026);

      expect(provider.dashboard!.totalBruto, 9999.0);
      verify(() => mockApi.getJson(any())).called(1);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // carregar() com skipCount
  // ══════════════════════════════════════════════════════════════════════════

  group('carregar() — skipCount', () {
    test('skipCount = 0 → executa normalmente', () async {
      when(() => mockApi.getJson(any()))
          .thenAnswer((_) async => _dashboardJson(totalBruto: 3000.0));

      await provider.carregar('cnpj-id', 4, 2026);

      expect(provider.dashboard!.totalBruto, 3000.0);
      verify(() => mockApi.getJson(any())).called(1);
    });

    test('skipCount = 1 → no-op sem notificar isLoading', () async {
      provider.atualizarComTotais(bruto: 5000.0, liquido: 4500.0, meta: 0);

      final estados = <bool>[];
      provider.addListener(() => estados.add(provider.isLoading));

      await provider.carregar('cnpj-id', 4, 2026);

      // isLoading nunca virou true (carregar() retornou antes de mudar estado)
      expect(estados.where((v) => v).isEmpty, isTrue);
      verifyNever(() => mockApi.getJson(any()));
    });
  });
}
