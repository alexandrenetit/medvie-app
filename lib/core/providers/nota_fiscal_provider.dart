// lib/core/providers/nota_fiscal_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nota_fiscal.dart';

class NotaFiscalProvider extends ChangeNotifier {
  static const _chavePrefs = 'notas_fiscais';

  final List<NotaFiscal> _notas = [];
  bool _carregando = false;

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────

  List<NotaFiscal> get notas => List.unmodifiable(_notas);
  bool get carregando => _carregando;

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
  // Mutações
  // ─────────────────────────────────────────────

  Future<void> adicionarNota(NotaFiscal nota) async {
    _notas.add(nota);
    await _salvar();
    notifyListeners();
  }

  Future<void> atualizarNota(NotaFiscal atualizada) async {
    final index = _notas.indexWhere((n) => n.id == atualizada.id);
    if (index == -1) return;
    _notas[index] = atualizada;
    await _salvar();
    notifyListeners();
  }

  Future<void> removerNota(String id) async {
    _notas.removeWhere((n) => n.id == id);
    await _salvar();
    notifyListeners();
  }

  Future<void> limpar() async {
    _notas.clear();
    await _salvar();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Persistência
  // ─────────────────────────────────────────────

  Future<void> carregar() async {
    _carregando = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chavePrefs);
      if (raw != null) {
        final lista = jsonDecode(raw) as List<dynamic>;
        _notas
          ..clear()
          ..addAll(lista.map((e) => NotaFiscal.fromJson(e as Map<String, dynamic>)));
      }
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chavePrefs,
      jsonEncode(_notas.map((n) => n.toJson()).toList()),
    );
  }
}