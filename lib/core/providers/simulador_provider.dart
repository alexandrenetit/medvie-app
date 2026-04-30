// lib/core/providers/simulador_provider.dart

import 'package:flutter/foundation.dart';

import '../models/medico.dart';
import '../services/medvie_api_service.dart';

typedef SimuladorResultado = ({
  double valorBruto,
  double descontoIss,
  double aliquotaIss,
  double descontoIrrf,
  double aliquotaIrrf,
  double valorLiquido,
  bool ehEstimativa,
});

class SimuladorProvider extends ChangeNotifier {
  final MedvieApiService _api;

  SimuladorProvider(this._api);

  double valorBruto = 0;
  Tomador? tomadorSelecionado;
  bool isLoading = false;
  SimuladorResultado? resultado;

  Future<void> calcular({
    required String medicoId,
    required double valorBruto,
    required String tomadorId,
  }) async {
    isLoading = true;
    resultado = null;
    notifyListeners();
    try {
      final data = await _api.postJson(
        '/api/v1/medicos/$medicoId/simulador/calcular',
        {'valorBruto': valorBruto, 'tomadorId': tomadorId},
      );
      resultado = (
        valorBruto: (data['valorBruto'] as num).toDouble(),
        descontoIss: (data['descontoIss'] as num).toDouble(),
        aliquotaIss: (data['aliquotaIss'] as num).toDouble(),
        descontoIrrf: (data['descontoIrrf'] as num).toDouble(),
        aliquotaIrrf: (data['aliquotaIrrf'] as num).toDouble(),
        valorLiquido: (data['valorLiquido'] as num).toDouble(),
        ehEstimativa: data['ehEstimativa'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('[SimuladorProvider] erro: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    valorBruto = 0;
    tomadorSelecionado = null;
    isLoading = false;
    resultado = null;
    notifyListeners();
  }
}
