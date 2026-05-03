// test/providers/simulador_provider_test.dart
//
// Testes unitários do SimuladorProvider.
// Cobre: estado inicial, calcular (sucesso, erro, loading flag, listeners,
// ehEstimativa default), reset, e integração de todos os campos do resultado.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/providers/simulador_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockApi extends Mock implements MedvieApiService {}

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _resultadoJson({
  double valorBruto = 5000.0,
  double descontoIss = 250.0,
  double aliquotaIss = 5.0,
  double descontoIrrf = 750.0,
  double aliquotaIrrf = 15.0,
  double valorLiquido = 4000.0,
  bool? ehEstimativa = false,
}) {
  final map = <String, dynamic>{
    'valorBruto': valorBruto,
    'descontoIss': descontoIss,
    'aliquotaIss': aliquotaIss,
    'descontoIrrf': descontoIrrf,
    'aliquotaIrrf': aliquotaIrrf,
    'valorLiquido': valorLiquido,
  };
  if (ehEstimativa != null) map['ehEstimativa'] = ehEstimativa;
  return map;
}

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    // postJson recebe Map<String, dynamic> como segundo argumento
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockApi mockApi;
  late SimuladorProvider provider;

  setUp(() {
    mockApi = _MockApi();
    provider = SimuladorProvider(mockApi);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Estado inicial
  // ══════════════════════════════════════════════════════════════════════════

  test('estado inicial — valorBruto 0, resultado null, isLoading false', () {
    expect(provider.valorBruto, 0.0);
    expect(provider.tomadorSelecionado, isNull);
    expect(provider.isLoading, isFalse);
    expect(provider.resultado, isNull);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // calcular()
  // ══════════════════════════════════════════════════════════════════════════

  group('calcular()', () {
    test('sucesso → resultado preenchido com todos os campos', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson());

      await provider.calcular(
        medicoId: 'med-001',
        valorBruto: 5000.0,
        tomadorId: 'tom-001',
      );

      expect(provider.resultado, isNotNull);
      final r = provider.resultado!;
      expect(r.valorBruto, 5000.0);
      expect(r.descontoIss, 250.0);
      expect(r.aliquotaIss, 5.0);
      expect(r.descontoIrrf, 750.0);
      expect(r.aliquotaIrrf, 15.0);
      expect(r.valorLiquido, 4000.0);
      expect(r.ehEstimativa, isFalse);
      expect(provider.isLoading, isFalse);
    });

    test('URL construída com medicoId correto', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson());

      await provider.calcular(
        medicoId: 'med-xyz',
        valorBruto: 1000.0,
        tomadorId: 'tom-abc',
      );

      final captured =
          verify(() => mockApi.postJson(captureAny(), any())).captured.first
              as String;
      expect(captured, contains('/med-xyz/'));
      expect(captured, contains('calcular'));
    });

    test('body contém valorBruto e tomadorId', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson());

      await provider.calcular(
        medicoId: 'med-001',
        valorBruto: 2500.0,
        tomadorId: 'tom-999',
      );

      final captured = verify(() => mockApi.postJson(any(), captureAny()))
          .captured
          .first as Map<String, dynamic>;
      expect(captured['valorBruto'], 2500.0);
      expect(captured['tomadorId'], 'tom-999');
    });

    test('ehEstimativa ausente no JSON → default true', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson(ehEstimativa: null));

      await provider.calcular(
        medicoId: 'med-001',
        valorBruto: 1000.0,
        tomadorId: 'tom-001',
      );

      expect(provider.resultado!.ehEstimativa, isTrue);
    });

    test('erro de rede → isLoading false, resultado null, sem exceção', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenThrow(Exception('Connection refused'));

      // calcular() não relança — absorve o erro via debugPrint
      await provider.calcular(
        medicoId: 'med-001',
        valorBruto: 1000.0,
        tomadorId: 'tom-001',
      );

      expect(provider.resultado, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('isLoading = true durante a execução, false após', () async {
      final estados = <bool>[];
      when(() => mockApi.postJson(any(), any())).thenAnswer((_) async {
        estados.add(provider.isLoading);
        return _resultadoJson();
      });

      await provider.calcular(
        medicoId: 'med-001',
        valorBruto: 1000.0,
        tomadorId: 'tom-001',
      );

      expect(estados, [true]);
      expect(provider.isLoading, isFalse);
    });

    test('resultado é null durante execução (limpo no início)', () async {
      // Pré-popula resultado
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson());
      await provider.calcular(
          medicoId: 'med-001', valorBruto: 1000.0, tomadorId: 'tom-001');
      expect(provider.resultado, isNotNull);

      // Segunda chamada — resultado deve ser null durante a execução
      SimuladorResultado? resultadoDurante;
      when(() => mockApi.postJson(any(), any())).thenAnswer((_) async {
        resultadoDurante = provider.resultado;
        return _resultadoJson(valorBruto: 2000.0);
      });

      await provider.calcular(
          medicoId: 'med-001', valorBruto: 2000.0, tomadorId: 'tom-001');

      expect(resultadoDurante, isNull); // limpo antes do await
      expect(provider.resultado!.valorBruto, 2000.0); // atualizado após
    });

    test('notifica listeners ao iniciar e ao concluir', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson());

      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      await provider.calcular(
        medicoId: 'med-001',
        valorBruto: 1000.0,
        tomadorId: 'tom-001',
      );

      // Pelo menos 2: início (isLoading=true) + fim (isLoading=false)
      expect(notificacoes, greaterThanOrEqualTo(2));
    });

    test('valor bruto zerado → ainda chama a API', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson(valorBruto: 0.0, valorLiquido: 0.0));

      await provider.calcular(
        medicoId: 'med-001',
        valorBruto: 0.0,
        tomadorId: 'tom-001',
      );

      verify(() => mockApi.postJson(any(), any())).called(1);
      expect(provider.resultado!.valorBruto, 0.0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // reset()
  // ══════════════════════════════════════════════════════════════════════════

  group('reset()', () {
    test('limpa todos os campos de estado', () async {
      // Preenche estado via calcular()
      when(() => mockApi.postJson(any(), any()))
          .thenAnswer((_) async => _resultadoJson());
      provider.valorBruto = 3000.0;
      await provider.calcular(
          medicoId: 'med-001', valorBruto: 3000.0, tomadorId: 'tom-001');
      expect(provider.resultado, isNotNull);

      provider.reset();

      expect(provider.valorBruto, 0.0);
      expect(provider.tomadorSelecionado, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.resultado, isNull);
    });

    test('notifica listeners após reset', () {
      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      provider.reset();

      expect(notificacoes, 1);
    });

    test('reset() com estado já zerado → ainda notifica listeners', () {
      int notificacoes = 0;
      provider.addListener(() => notificacoes++);

      provider.reset();

      expect(notificacoes, 1);
    });

    test('reset() após erro mantém isLoading false', () async {
      when(() => mockApi.postJson(any(), any()))
          .thenThrow(Exception('Erro'));
      await provider.calcular(
          medicoId: 'med-001', valorBruto: 1000.0, tomadorId: 'tom-001');

      provider.reset();

      expect(provider.isLoading, isFalse);
      expect(provider.resultado, isNull);
    });
  });
}
