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

  /// Ressalva de escopo redigida pelo backend (`SimularNotaRessalvas`, bloco
  /// G-E/A4): diz se o número é estimativa manual ou projeção cadastral e,
  /// pela competência, quais tributos do RTC já são retidos via Split.
  ///
  /// Vazia quando o backend não manda o campo (contrato anterior ao A4). A UI
  /// exibe o texto COMO VEIO — remontar a frase no cliente é o gap que o G-E
  /// fechou, porque só o backend conhece a janela do Split e a origem do
  /// cálculo.
  String ressalvaEscopo,
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
        ressalvaEscopo: (data['ressalvaEscopo'] as String? ?? '').trim(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SimuladorProvider] erro: $e');
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
