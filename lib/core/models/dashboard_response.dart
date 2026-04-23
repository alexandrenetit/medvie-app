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
      );
}
