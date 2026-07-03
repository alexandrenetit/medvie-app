// test/core/models/dashboard_pipeline_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/dashboard_response.dart';

Map<String, dynamic> _baseJson() => {
      'totalBruto': 15000.0,
      'totalIss': 450.0,
      'totalIbs': 0.0,
      'totalCbs': 0.0,
      'totalLiquidoEstimado': 13500.0,
      'notasAutorizadas': 3,
      'notasPendentes': 1,
      'notasRejeitadas': 0,
      'metaMensal': 20000.0,
    };

void main() {
  group('DashboardResponse.pipeline', () {
    test('backend legado sem campo pipeline → null (parse tolerante)', () {
      final dash = DashboardResponse.fromJson(_baseJson());
      expect(dash.pipeline, isNull);
    });

    test('parseia os 3 estágios + dataPrevista (data-only estável em UTC)', () {
      final json = _baseJson()
        ..['pipeline'] = {
          'recebido': {'valor': 14201.0, 'quantidade': 7},
          'aReceber': {
            'valor': 12400.0,
            'quantidade': 2,
            'dataPrevista': '2026-07-15',
          },
          'aguardandoEmissao': {'valor': 3399.0, 'quantidade': 2},
        };

      final p = DashboardResponse.fromJson(json).pipeline;
      expect(p, isNotNull);
      expect(p!.recebido.valor, 14201.0);
      expect(p.recebido.quantidade, 7);
      expect(p.aReceber.valor, 12400.0);
      expect(p.aReceber.quantidade, 2);
      expect(p.aguardandoEmissao.valor, 3399.0);
      expect(p.aguardandoEmissao.quantidade, 2);
      // Data-only não pode deslocar o dia por fuso horário.
      expect(p.dataPrevista, DateTime.utc(2026, 7, 15));
      expect(p.total, 14201.0 + 12400.0 + 3399.0);
      expect(p.vazio, isFalse);
    });

    test('segmento ausente vira zero; sem dataPrevista → null; vazio=true', () {
      final json = _baseJson()
        ..['pipeline'] = {
          'recebido': {'valor': 0.0, 'quantidade': 0},
          // aReceber e aguardandoEmissao ausentes de propósito
        };

      final p = DashboardResponse.fromJson(json).pipeline;
      expect(p, isNotNull);
      expect(p!.aReceber.valor, 0.0);
      expect(p.aReceber.quantidade, 0);
      expect(p.aguardandoEmissao.valor, 0.0);
      expect(p.aguardandoEmissao.quantidade, 0);
      expect(p.dataPrevista, isNull);
      expect(p.vazio, isTrue);
    });
  });

  group('DashboardResponse.comparativo', () {
    test('sem campo comparativo → null (parse tolerante)', () {
      final dash = DashboardResponse.fromJson(_baseJson());
      expect(dash.comparativo, isNull);
    });

    test('comparativo não-mapa (ex.: null explícito) → null', () {
      final json = _baseJson()..['comparativo'] = null;
      final dash = DashboardResponse.fromJson(json);
      expect(dash.comparativo, isNull);
    });

    test('parseia liquidoMesAnterior + variacaoPercentual (fração positiva)', () {
      final json = _baseJson()
        ..['comparativo'] = {
          'liquidoMesAnterior': 428.35,
          'variacaoPercentual': 0.0833,
        };

      final c = DashboardResponse.fromJson(json).comparativo;
      expect(c, isNotNull);
      expect(c!.liquidoMesAnterior, 428.35);
      expect(c.variacaoPercentual, 0.0833);
    });

    test('variação negativa (queda) preserva o sinal', () {
      final json = _baseJson()
        ..['comparativo'] = {
          'liquidoMesAnterior': 30000.0,
          'variacaoPercentual': -0.12,
        };

      final c = DashboardResponse.fromJson(json).comparativo;
      expect(c, isNotNull);
      expect(c!.variacaoPercentual, -0.12);
    });
  });
}
