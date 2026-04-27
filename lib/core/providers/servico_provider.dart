// lib/core/providers/servico_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/servico.dart';
import '../models/nota_fiscal.dart';
import '../services/medvie_api_service.dart';
import 'nota_fiscal_provider.dart';

class ServicoProvider extends ChangeNotifier {
  static const _chavePrefs = 'servicos';

  final MedvieApiService? _api;

  /// [api] é opcional para manter retrocompatibilidade com testes que
  /// instanciam o provider sem injeção (SharedPreferences puro).
  ServicoProvider({MedvieApiService? api}) : _api = api;

  final List<Servico> _servicos = [];
  bool _carregando = false;

  // ─────────────────────────────────────────────
  // Getters — listas
  // ─────────────────────────────────────────────

  List<Servico> get servicos => List.unmodifiable(_servicos);
  bool get carregando => _carregando;

  DateTime? _diaFiltrado;

  List<Servico> get servicosFiltrados {
    if (_diaFiltrado == null) return servicos;
    return _servicos
        .where((s) =>
            s.data.year == _diaFiltrado!.year &&
            s.data.month == _diaFiltrado!.month &&
            s.data.day == _diaFiltrado!.day)
        .toList();
  }

  void filtrarPorDia(DateTime dia) {
    _diaFiltrado = DateTime(dia.year, dia.month, dia.day);
    notifyListeners();
  }

  void limparFiltro() {
    _diaFiltrado = null;
    notifyListeners();
  }

  List<Servico> get confirmados =>
      _servicos.where((s) => s.status == StatusServico.pendente).toList();

  List<Servico> get planejados =>
      _servicos.where((s) => s.status == StatusServico.pago).toList();

  /// Serviços na fila "Prontos para emitir NFS-e".
  List<Servico> get pendentesDEmissao => _servicos
      .where((s) => s.status.pendenteDEmissao)
      .toList()
    ..sort((a, b) => a.data.compareTo(b.data));

  /// Badge numérico do ícone da aba Notas no BottomNav.
  int get countPendentesNf => pendentesDEmissao.length;

  // ─────────────────────────────────────────────
  // Getters — totais
  // ─────────────────────────────────────────────

  double get totalBruto => _servicos
      .where((s) => s.status != StatusServico.cancelado && s.valor > 0)
      .fold(0.0, (soma, s) => soma + s.valor);

  int get totalConfirmados =>
      _servicos.where((s) => s.status == StatusServico.pendente).length;

  int get totalPlanejados =>
      _servicos.where((s) => s.status == StatusServico.pago).length;

  List<Servico> doMes(int ano, int mes) => _servicos
      .where((s) => s.data.year == ano && s.data.month == mes)
      .toList()
    ..sort((a, b) => a.data.compareTo(b.data));

  double totalBrutoDoMes(int ano, int mes) => doMes(ano, mes)
      .where((s) => s.status != StatusServico.cancelado && s.valor > 0)
      .fold(0.0, (soma, s) => soma + s.valor);

  // ─────────────────────────────────────────────
  // CRUD básico
  // ─────────────────────────────────────────────

  /// Cria um serviço.
  /// Se [cnpjProprioId] for fornecido e [_api] estiver injetado, persiste
  /// no backend primeiro — lança [Exception] em erro HTTP sem tocar estado local.
  /// Em sucesso (ou sem API), sincroniza via [carregar].
  Future<void> adicionarServico({
    required TipoServico tipo,
    required DateTime data,
    required String tomadorCnpj,
    required String tomadorNome,
    required double valor,
    required StatusServico status,
    String observacao = '',
    TimeOfDay? horaInicio,
    TimeOfDay? horaFim,
    String? cnpjProprioId,
    String? tomadorId,
  }) async {
    final servico = Servico(
      id: const Uuid().v4(),
      tipo: tipo,
      data: data,
      tomadorCnpj: tomadorCnpj,
      tomadorNome: tomadorNome,
      tomadorId: tomadorId,
      valor: valor,
      status: status,
      observacao: observacao,
      horaInicio: horaInicio,
      horaFim: horaFim,
    );

    if (_api != null && cnpjProprioId != null && cnpjProprioId.isNotEmpty) {
      // Backend é fonte primária — lança exception se falhar (sem persistência local)
      await _api.criarServico(cnpjProprioId, servico.toJson());
      // Recarrega do backend para garantir consistência
      await carregar(cnpjProprioId: cnpjProprioId);
    } else {
      // Fallback offline: persiste apenas em SharedPreferences
      _servicos.add(servico);
      await _salvar();
      notifyListeners();
    }
  }

  Future<void> atualizarServico(Servico atualizado) async {
    final index = _servicos.indexWhere((s) => s.id == atualizado.id);
    if (index == -1) return;
    _servicos[index] = atualizado;
    await _salvar();
    notifyListeners();
  }

  Future<void> removerServico(String id) async {
    _servicos.removeWhere((s) => s.id == id);
    await _salvar();
    notifyListeners();
  }

  Future<void> excluirServico(String servicoId, String cnpjProprioId) async {
    final api = _api;
    if (api != null) await api.excluirServico(servicoId, cnpjProprioId);
    _servicos.removeWhere((s) => s.id == servicoId);
    await _salvar();
    notifyListeners();
  }

  Future<void> limparServicos() async {
    _servicos.clear();
    await _salvar();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // Ciclo de vida fiscal
  // ─────────────────────────────────────────────

  Future<void> confirmarExecucao(String servicoId) async {
    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return;
    final servico = _servicos[index];
    if (servico.status != StatusServico.pendente) return;
    // pendente já é o estado executável; no-op mas mantido para compatibilidade
    await _salvar();
    notifyListeners();
  }

  /// Promove pendentes cuja data/hora já passou (mantém retrocompatibilidade).
  Future<void> sincronizarStatusPorTempo() async {
    final agora = DateTime.now();
    bool houveMudanca = false;

    for (int i = 0; i < _servicos.length; i++) {
      final s = _servicos[i];
      if (s.status != StatusServico.pendente) continue;

      DateTime dataFim;
      if (s.horaFim != null) {
        dataFim = DateTime(
          s.data.year, s.data.month, s.data.day,
          s.horaFim!.hour, s.horaFim!.minute,
        );
        if (s.horaInicio != null) {
          final inicioMin = s.horaInicio!.hour * 60 + s.horaInicio!.minute;
          final fimMin = s.horaFim!.hour * 60 + s.horaFim!.minute;
          if (fimMin <= inicioMin) {
            dataFim = dataFim.add(const Duration(days: 1));
          }
        }
      } else {
        dataFim = DateTime(s.data.year, s.data.month, s.data.day, 23, 59);
      }

      if (agora.isAfter(dataFim)) {
        // pendente já representa serviço a executar; sem transição necessária
        houveMudanca = false; // suprime notify desnecessário
      }
    }

    if (houveMudanca) {
      await _salvar();
      notifyListeners();
    }
  }

  /// Emite NFS-e via backend para um único serviço.
  Future<bool> emitirNf(
    String servicoId,
    NotaFiscalProvider notaFiscalProvider,
    String cnpjProprioId,
  ) async {
    if (_api == null) throw Exception('MedvieApiService não injetado');

    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return false;

    final servico = _servicos[index];
    if (!servico.status.pendenteDEmissao) return false;

    if (servico.tomadorId == null) {
      throw Exception('tomadorId ausente — sincronize os serviços antes de emitir');
    }

    // 1. Feedback visual imediato
    _servicos[index] = servico.copyWith(status: StatusServico.nfEmProcessamento);
    await _salvar();
    notifyListeners();

    try {
      final nota = await _api.emitirNota(
        servicoId: servicoId,
        cnpjProprioId: cnpjProprioId,
        tomadorId: servico.tomadorId!,
        aliquotaIss: servico.aliquotaIss,
        issRetido: servico.issRetido,
      );

      final novoStatus = nota.status == StatusNota.autorizada
          ? StatusServico.nfEmitida
          : StatusServico.cancelado;

      _servicos[index] = _servicos[index].copyWith(status: novoStatus);
      await _salvar();

      notaFiscalProvider.adicionarNotaLocal(nota);
      notifyListeners();
      return nota.status == StatusNota.autorizada;
    } catch (e) {
      // Reverte para pendente em caso de erro de rede/servidor
      _servicos[index] = _servicos[index].copyWith(status: StatusServico.pendente);
      await _salvar();
      notifyListeners();
      rethrow;
    }
  }

  /// Emite NFS-e para todos os pendentes em PARALELO via Future.wait.
  /// Evita loop sequencial que travava a UI thread.
  Future<Map<String, int>> emitirTodasNfsPendentes(
    NotaFiscalProvider notaFiscalProvider,
    String cnpjEmissor,
  ) async {
    final pendentes = List<Servico>.from(pendentesDEmissao);
    if (pendentes.isEmpty) return {'autorizadas': 0, 'rejeitadas': 0};

    final resultados = await Future.wait(
      pendentes.map((s) => emitirNf(s.id, notaFiscalProvider, cnpjEmissor)),
    );

    final autorizadas = resultados.where((r) => r).length;
    final rejeitadas = resultados.where((r) => !r).length;

    return {'autorizadas': autorizadas, 'rejeitadas': rejeitadas};
  }

  /// Recoloca serviço cancelado na fila de emissão.
  Future<void> reenviarNfRejeitada(
    String servicoId,
    NotaFiscalProvider notaFiscalProvider,
  ) async {
    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return;
    if (_servicos[index].status != StatusServico.cancelado) return;

    final notaAnterior = notaFiscalProvider.porServicoId(servicoId);
    if (notaAnterior != null) {
      await notaFiscalProvider.removerNota(notaAnterior.id);
    }

    _servicos[index] =
        _servicos[index].copyWith(status: StatusServico.pendente);
    await _salvar();
    notifyListeners();
  }

  /// Reverte serviços com NF de volta para [StatusServico.pendente].
  /// Usado pelo Dev Tools ao apagar notas.
  Future<void> reverterStatusNf() async {
    bool alterou = false;
    for (int i = 0; i < _servicos.length; i++) {
      final s = _servicos[i];
      if (s.status == StatusServico.nfEmProcessamento ||
          s.status == StatusServico.nfEmitida ||
          s.status == StatusServico.aguardandoPagamento ||
          s.status == StatusServico.pago) {
        _servicos[i] = s.copyWith(status: StatusServico.pendente);
        alterou = true;
      }
    }
    if (alterou) {
      await _salvar();
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Persistência
  // ─────────────────────────────────────────────

  /// Carrega serviços.
  /// Se [cnpjProprioId] for fornecido e [_api] estiver injetado, busca do
  /// backend e atualiza o cache local (SharedPreferences).
  /// Sem API ou sem cnpjProprioId, carrega apenas do cache local.
  Future<void> carregar({String? cnpjProprioId}) async {
    _carregando = true;
    notifyListeners();
    try {
      if (_api != null && cnpjProprioId != null && cnpjProprioId.isNotEmpty) {
        // Fonte primária: backend
        final lista = await _api.listarServicos(cnpjProprioId);
        _servicos
          ..clear()
          ..addAll(lista.map((e) => Servico.fromJson(e)));
        // Atualiza cache local
        await _salvar();
      } else {
        // Fallback: SharedPreferences (offline / boot sem login)
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_chavePrefs);
        if (raw != null) {
          final lista = jsonDecode(raw) as List<dynamic>;
          _servicos
            ..clear()
            ..addAll(
                lista.map((e) => Servico.fromJson(e as Map<String, dynamic>)));
        }
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
      jsonEncode(_servicos.map((s) => s.toJson()).toList()),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers mock
  // ─────────────────────────────────────────────

}