// lib/core/models/dashboard_response.dart

class DashboardResponse {
  final double totalBruto;
  final double totalIss;
  final double totalIbs;
  final double totalCbs;
  final double totalLiquidoEstimado;
  final int notasAutorizadas;
  final int notasPendentes;
  final int notasRejeitadas;
  final double? metaMensal;
  final CargaTributaria? carga;

  const DashboardResponse({
    required this.totalBruto,
    required this.totalIss,
    required this.totalIbs,
    required this.totalCbs,
    required this.totalLiquidoEstimado,
    required this.notasAutorizadas,
    required this.notasPendentes,
    required this.notasRejeitadas,
    this.metaMensal,
    this.carga,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) =>
      DashboardResponse(
        totalBruto: (json['totalBruto'] as num).toDouble(),
        totalIss: (json['totalIss'] as num).toDouble(),
        totalIbs: (json['totalIbs'] as num).toDouble(),
        totalCbs: (json['totalCbs'] as num).toDouble(),
        totalLiquidoEstimado:
            (json['totalLiquidoEstimado'] as num).toDouble(),
        notasAutorizadas: json['notasAutorizadas'] as int,
        notasPendentes: json['notasPendentes'] as int,
        notasRejeitadas: json['notasRejeitadas'] as int,
        metaMensal: (json['metaMensal'] as num?)?.toDouble(),
        carga: json['carga'] == null
            ? null
            : CargaTributaria.fromJson(json['carga'] as Map<String, dynamic>),
      );
}

/// Carga tributária mensal estimada (impostos próprios do regime), distinta do
/// líquido pós-retenções na fonte. Fonte única: backend (CargaTributariaCalculator).
class CargaTributaria {
  final double irpj;
  final double adicionalIrpj;
  final double csll;
  final double pis;
  final double cofins;
  final double iss;
  final double ibs;
  final double cbs;
  final double totalImpostos;
  final double aliquotaEfetiva;
  final double liquidoPosImpostos;
  final String regimeDescricao;

  const CargaTributaria({
    required this.irpj,
    required this.adicionalIrpj,
    required this.csll,
    required this.pis,
    required this.cofins,
    required this.iss,
    required this.ibs,
    required this.cbs,
    required this.totalImpostos,
    required this.aliquotaEfetiva,
    required this.liquidoPosImpostos,
    required this.regimeDescricao,
  });

  factory CargaTributaria.fromJson(Map<String, dynamic> json) => CargaTributaria(
        irpj: (json['irpj'] as num?)?.toDouble() ?? 0,
        adicionalIrpj: (json['adicionalIrpj'] as num?)?.toDouble() ?? 0,
        csll: (json['csll'] as num?)?.toDouble() ?? 0,
        pis: (json['pis'] as num?)?.toDouble() ?? 0,
        cofins: (json['cofins'] as num?)?.toDouble() ?? 0,
        iss: (json['iss'] as num?)?.toDouble() ?? 0,
        ibs: (json['ibs'] as num?)?.toDouble() ?? 0,
        cbs: (json['cbs'] as num?)?.toDouble() ?? 0,
        totalImpostos: (json['totalImpostos'] as num?)?.toDouble() ?? 0,
        aliquotaEfetiva: (json['aliquotaEfetiva'] as num?)?.toDouble() ?? 0,
        liquidoPosImpostos: (json['liquidoPosImpostos'] as num?)?.toDouble() ?? 0,
        regimeDescricao: json['regimeDescricao'] as String? ?? '',
      );
}
