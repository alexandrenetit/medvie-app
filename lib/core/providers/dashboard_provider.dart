// lib/core/providers/dashboard_provider.dart

import 'package:flutter/material.dart';
import '../models/dashboard_response.dart';
import '../services/medvie_api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final MedvieApiService _api;

  DashboardResponse? dashboard;
  bool isLoading = false;
  String? error;

  DashboardProvider(this._api);

  Future<void> carregar(String cnpjProprioId, int mes, int ano) async {
    if (cnpjProprioId.isEmpty) return;
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
}
