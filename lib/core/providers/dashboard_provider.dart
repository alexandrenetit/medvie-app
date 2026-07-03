// lib/core/providers/dashboard_provider.dart

import 'package:flutter/material.dart';
import '../models/dashboard_response.dart';
import '../services/medvie_api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final MedvieApiService _api;

  DashboardResponse? dashboard;
  bool isLoading = false;
  String? error;

  // A-07: contador inteiro em vez de bool para suportar POSTs concorrentes.
  int _skipCount = 0;

  DashboardProvider(this._api);

  /// Atualiza os totais diretamente com os dados retornados pelo POST /servicos,
  /// evitando um GET /dashboard adicional.
  void atualizarComTotais({
    required double bruto,
    required double liquido,
    required double meta,
  }) {
    final atual = dashboard;
    dashboard = DashboardResponse(
      totalBruto: bruto,
      totalIss: atual?.totalIss ?? 0,
      totalIbs: atual?.totalIbs ?? 0,
      totalCbs: atual?.totalCbs ?? 0,
      totalLiquidoEstimado: liquido,
      notasAutorizadas: atual?.notasAutorizadas ?? 0,
      notasPendentes: atual?.notasPendentes ?? 0,
      notasRejeitadas: atual?.notasRejeitadas ?? 0,
      metaMensal: meta > 0 ? meta : atual?.metaMensal,
      carga: atual?.carga,
      // Preserva o pipeline anterior: o POST /servicos só devolve bruto/líquido,
      // não o breakdown. Evita a barra piscar "—" até o próximo GET /dashboard.
      pipeline: atual?.pipeline,
    );
    _skipCount++;
    notifyListeners();
  }

  Future<void> carregar(String cnpjProprioId, int mes, int ano) async {
    if (cnpjProprioId.isEmpty) return;
    if (_skipCount > 0) {
      _skipCount--;
      return;
    }
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final json = await _api.getJson(
        '/api/v1/dashboard'
        '?cnpjProprioId=$cnpjProprioId&mes=$mes&ano=$ano',
      );
      dashboard = DashboardResponse.fromJson(json);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Busca o dashboard de um mês específico SEM alterar o estado compartilhado
  /// ([dashboard]). Usado por telas com seletor de mês próprio (ex.: Relatórios)
  /// que precisam da carga tributária do mês sem interferir no SyncView.
  Future<DashboardResponse?> buscarDashboardMes(
    String cnpjProprioId,
    int mes,
    int ano,
  ) async {
    if (cnpjProprioId.isEmpty) return null;
    final json = await _api.getJson(
      '/api/v1/dashboard?cnpjProprioId=$cnpjProprioId&mes=$mes&ano=$ano',
    );
    return DashboardResponse.fromJson(json);
  }
}
