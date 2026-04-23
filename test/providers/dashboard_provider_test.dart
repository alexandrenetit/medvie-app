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

Map<String, dynamic> _dashboardJson({double totalBruto = 15000.0}) => {
      'totalBruto': totalBruto,
      'totalIss': 450.0,
      'totalIbs': 0.0,
      'totalCbs': 0.0,
      'totalLiquidoEstimado': 13500.0,
      'notasAutorizadas': 3,
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

  // 1 ─ estado inicial
  test('estado inicial — dashboard null, isLoading false, error null', () {
    expect(provider.dashboard, isNull);
    expect(provider.isLoading, false);
    expect(provider.error, isNull);
  });

  // 2 ─ cnpjProprioId vazio → early return, sem chamada HTTP
  test('carregar() com cnpjProprioId vazio → no-op, getJson não chamado', () async {
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
  test('carregar() erro de rede → error não-null, dashboard permanece null', () async {
    when(() => mockApi.getJson(any())).thenThrow(Exception('timeout'));

    await provider.carregar('cnpj-id-123', 4, 2026);

    expect(provider.error, isNotNull);
    expect(provider.dashboard, isNull);
    expect(provider.isLoading, false);
  });

  // 5 ─ listeners notificados
  test('carregar() sucesso notifica listeners ao iniciar e ao concluir', () async {
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
}
