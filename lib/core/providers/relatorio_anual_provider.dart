// lib/core/providers/relatorio_anual_provider.dart

import 'package:flutter/material.dart';
import '../services/medvie_api_service.dart';

// ---------------------------------------------------------------------------
// MODELOS
// ---------------------------------------------------------------------------

class RelatorioAnualTomador {
  final String nome;
  final String cnpj;
  final double totalBruto;

  const RelatorioAnualTomador({
    required this.nome,
    required this.cnpj,
    required this.totalBruto,
  });

  factory RelatorioAnualTomador.fromJson(Map<String, dynamic> j) =>
      RelatorioAnualTomador(
        nome: j['nome'] as String? ?? '',
        cnpj: j['cnpj'] as String? ?? '',
        totalBruto: (j['totalBruto'] as num?)?.toDouble() ?? 0.0,
      );
}

class RelatorioAnualMes {
  final int mes;
  final double totalBruto;
  final double totalLiquido;
  final double totalImpostos;
  final List<RelatorioAnualTomador> tomadores;

  const RelatorioAnualMes({
    required this.mes,
    required this.totalBruto,
    required this.totalLiquido,
    required this.totalImpostos,
    required this.tomadores,
  });

  factory RelatorioAnualMes.fromJson(Map<String, dynamic> j) =>
      RelatorioAnualMes(
        mes: (j['mes'] as num?)?.toInt() ?? 0,
        totalBruto: (j['totalBruto'] as num?)?.toDouble() ?? 0.0,
        totalLiquido: (j['totalLiquido'] as num?)?.toDouble() ?? 0.0,
        totalImpostos: (j['totalImpostos'] as num?)?.toDouble() ?? 0.0,
        tomadores: (j['tomadores'] as List<dynamic>? ?? [])
            .map((t) => RelatorioAnualTomador.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

class RelatorioAnualResponse {
  final int ano;
  final double totalBruto;
  final double totalLiquido;
  final double totalImpostos;
  final List<RelatorioAnualMes> meses;

  const RelatorioAnualResponse({
    required this.ano,
    required this.totalBruto,
    required this.totalLiquido,
    required this.totalImpostos,
    required this.meses,
  });

  factory RelatorioAnualResponse.fromJson(Map<String, dynamic> j) =>
      RelatorioAnualResponse(
        ano: (j['ano'] as num?)?.toInt() ?? 0,
        totalBruto: (j['totalBruto'] as num?)?.toDouble() ?? 0.0,
        totalLiquido: (j['totalLiquido'] as num?)?.toDouble() ?? 0.0,
        totalImpostos: (j['totalImpostos'] as num?)?.toDouble() ?? 0.0,
        meses: (j['meses'] as List<dynamic>? ?? [])
            .map((m) => RelatorioAnualMes.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  /// Brutos por mês em ordem (índice 0 = jan, 11 = dez), tamanho fixo 12.
  List<double> get brutosPorMes {
    final result = List<double>.filled(12, 0.0);
    for (final m in meses) {
      if (m.mes >= 1 && m.mes <= 12) result[m.mes - 1] = m.totalBruto;
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// PROVIDER
// ---------------------------------------------------------------------------

class RelatorioAnualProvider extends ChangeNotifier {
  final MedvieApiService _api;

  RelatorioAnualProvider({required MedvieApiService api}) : _api = api;

  MedvieApiService get api => _api;

  RelatorioAnualResponse? data;
  bool isLoading = false;
  String? erro;

  String? _cnpjIdCarregado;
  int? _anoCarregado;

  /// Carrega o relatório anual do backend.
  /// Ignora chamadas duplicadas para o mesmo par (cnpjProprioId, ano).
  Future<void> carregar(String cnpjProprioId, int ano) async {
    if (isLoading) return;
    if (_cnpjIdCarregado == cnpjProprioId && _anoCarregado == ano && data != null) return;

    isLoading = true;
    erro = null;
    notifyListeners();

    try {
      final json = await _api.getJson(
        '/api/v1/relatorios/anual?cnpjProprioId=$cnpjProprioId&ano=$ano',
      );
      data = RelatorioAnualResponse.fromJson(json);
      _cnpjIdCarregado = cnpjProprioId;
      _anoCarregado = ano;
    } catch (e) {
      erro = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Força recarregamento (descarta cache).
  Future<void> recarregar(String cnpjProprioId, int ano) async {
    _cnpjIdCarregado = null;
    _anoCarregado = null;
    data = null;
    await carregar(cnpjProprioId, ano);
  }
}
