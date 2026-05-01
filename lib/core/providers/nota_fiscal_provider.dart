// lib/core/providers/nota_fiscal_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nota_fiscal.dart';
import '../services/medvie_api_service.dart';
import '../services/sse_service.dart';

class NotaFiscalProvider extends ChangeNotifier {
  static const _chaveCache = 'notas_fiscais_cache';

  final MedvieApiService _api;

  NotaFiscalProvider(this._api);

  final List<NotaFiscal> _notas = [];
  bool _carregando = false;
  String? _erro;
  SseService? _sse;

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  List<NotaFiscal> get notas => List.unmodifiable(_notas);
  bool get carregando => _carregando;
  String? get erro => _erro;
  MedvieApiService get api => _api;

  /// Notas filtradas por mês/ano de competência.
  List<NotaFiscal> notasDoMes(int ano, int mes) => _notas
      .where((n) => n.competencia.year == ano && n.competencia.month == mes)
      .toList()
    ..sort((a, b) => b.competencia.compareTo(a.competencia));

  /// Total faturado (notas autorizadas) no mês.
  double totalAutorizadoDoMes(int ano, int mes) => notasDoMes(ano, mes)
      .where((n) => n.status == StatusNota.autorizada)
      .fold(0.0, (soma, n) => soma + n.valor);

  /// Quantidade de notas autorizadas no mês.
  int countAutorizadasDoMes(int ano, int mes) => notasDoMes(ano, mes)
      .where((n) => n.status == StatusNota.autorizada)
      .length;

  /// Notas filtradas por status.
  List<NotaFiscal> porStatus(StatusNota status) =>
      _notas.where((n) => n.status == status).toList()
        ..sort((a, b) => b.competencia.compareTo(a.competencia));

  /// Busca nota pelo servicoId — útil para verificar se um serviço já tem NF.
  NotaFiscal? porServicoId(String servicoId) {
    try {
      return _notas.lastWhere((n) => n.servicoId == servicoId);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // SSE — atualizações em tempo real
  // ─────────────────────────────────────────────

  void conectarSse(String token) {
    _sse?.desconectar();
    _sse = SseService(_api.baseUrl)
      ..onNotaAtualizada = _onNotaAtualizada
      ..conectar(token);
  }

  void desconectarSse() {
    _sse?.desconectar();
    _sse = null;
  }

  void _onNotaAtualizada(String notaId, String status) {
    final index = _notas.indexWhere((n) => n.id == notaId);
    if (index == -1) return;
    _notas[index] = _notas[index].copyWith(
      status: StatusNotaExtension.fromJson(status),
    );
    _salvarCache();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Carregamento (backend → cache offline)
  // ─────────────────────────────────────────────

  /// Carrega notas do backend filtrando por [cnpjProprioId] e, opcionalmente,
  /// por [mes]/[ano] de competência. Em caso de falha de rede, usa o cache
  /// local (SharedPreferences) como fallback.
  Future<void> carregar(
    String cnpjProprioId, {
    int? mes,
    int? ano,
  }) async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      DateTime? de;
      DateTime? ate;
      if (mes != null && ano != null) {
        de = DateTime(ano, mes);
        ate = DateTime(ano, mes + 1).subtract(const Duration(days: 1));
      }

      final lista = await _api.listarNotas(
        cnpjProprioId,
        competenciaDe: de,
        competenciaAte: ate,
      );

      _notas
        ..clear()
        ..addAll(lista);

      await _salvarCache();
    } catch (e) {
      _erro = e.toString();
      await _carregarCache();
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Mutações
  // ─────────────────────────────────────────────

  /// Cancela uma NFS-e autorizada no backend e recarrega a lista.
  Future<void> cancelar(
    String id,
    String motivo,
    String cnpjProprioId,
  ) async {
    await _api.cancelarNota(id, motivo);
    await carregar(cnpjProprioId);
  }

  /// Adiciona uma nota já criada pelo backend à lista local (usada pelo
  /// ServicoProvider após emitirNota bem-sucedido).
  void adicionarNotaLocal(NotaFiscal nota) {
    _notas.add(nota);
    _salvarCache();
    notifyListeners();
  }

  Future<void> atualizarNota(NotaFiscal atualizada) async {
    final index = _notas.indexWhere((n) => n.id == atualizada.id);
    if (index == -1) return;
    _notas[index] = atualizada;
    await _salvarCache();
    notifyListeners();
  }

  Future<void> removerNota(String id) async {
    _notas.removeWhere((n) => n.id == id);
    await _salvarCache();
    notifyListeners();
  }

  Future<void> limpar() async {
    _notas.clear();
    await _salvarCache();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Cache offline (SharedPreferences)
  // ─────────────────────────────────────────────

  Future<void> _salvarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _chaveCache,
        jsonEncode(_notas.map((n) => n.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _carregarCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chaveCache);
      if (raw != null) {
        final lista = jsonDecode(raw) as List<dynamic>;
        _notas
          ..clear()
          ..addAll(
              lista.map((e) => NotaFiscal.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
  }
}
