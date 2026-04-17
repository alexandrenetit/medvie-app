// lib/core/providers/servico_provider.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/servico.dart';
import '../models/nota_fiscal.dart';
import 'nota_fiscal_provider.dart';

class ServicoProvider extends ChangeNotifier {
  static const _chavePrefs = 'servicos';

  final List<Servico> _servicos = [];
  bool _carregando = false;

  // ─────────────────────────────────────────────
  // Getters — listas
  // ─────────────────────────────────────────────

  List<Servico> get servicos => List.unmodifiable(_servicos);
  bool get carregando => _carregando;

  List<Servico> get confirmados =>
      _servicos.where((s) => s.status == StatusServico.confirmado).toList();

  List<Servico> get planejados =>
      _servicos.where((s) => s.status == StatusServico.planejado).toList();

  /// Plantões executados que ainda NÃO têm NFS-e emitida.
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
      _servicos.where((s) => s.status == StatusServico.confirmado).length;

  int get totalPlanejados =>
      _servicos.where((s) => s.status == StatusServico.planejado).length;

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
  }) async {
    final servico = Servico(
      id: const Uuid().v4(),
      tipo: tipo,
      data: data,
      tomadorCnpj: tomadorCnpj,
      tomadorNome: tomadorNome,
      valor: valor,
      status: status,
      observacao: observacao,
      horaInicio: horaInicio,
      horaFim: horaFim,
    );
    _servicos.add(servico);
    await _salvar();
    notifyListeners();
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
    if (servico.status != StatusServico.planejado) return;
    _servicos[index] = servico.copyWith(status: StatusServico.confirmado);
    await _salvar();
    notifyListeners();
  }

  /// Promove planejados cuja data/hora já passou para confirmado.
  Future<void> sincronizarStatusPorTempo() async {
    final agora = DateTime.now();
    bool houveMudanca = false;

    for (int i = 0; i < _servicos.length; i++) {
      final s = _servicos[i];
      if (s.status != StatusServico.planejado) continue;

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
        _servicos[i] = s.copyWith(status: StatusServico.confirmado);
        houveMudanca = true;
      }
    }

    if (houveMudanca) {
      await _salvar();
      notifyListeners();
    }
  }

  /// Simula emissão de NFS-e para um único serviço.
  /// Delay mínimo (300ms) para feedback visual — não bloqueia a UI.
  Future<bool> emitirNf(
    String servicoId,
    NotaFiscalProvider notaFiscalProvider,
    String cnpjEmissor,
  ) async {
    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return false;

    final servico = _servicos[index];
    if (!servico.status.pendenteDEmissao) return false;

    // 1. aguardandoNf
    _servicos[index] = servico.copyWith(status: StatusServico.aguardandoNf);
    await _salvar();
    notifyListeners();

    // 2. nfEmProcessamento — delay curto apenas para feedback visual
    await Future.delayed(const Duration(milliseconds: 300));
    _servicos[index] =
        _servicos[index].copyWith(status: StatusServico.nfEmProcessamento);
    await _salvar();
    notifyListeners();

    // 3. Simula resposta do ADN (300ms — não trava a UI)
    await Future.delayed(const Duration(milliseconds: 300));

    // 4. 90% autorizada, 10% rejeitada
    final autorizada = Random().nextInt(10) != 0;

    if (autorizada) {
      final numero = _gerarNumeroNota();
      final chave = _gerarChaveAcesso(servico.tomadorCnpj, servico.data);

      _servicos[index] =
          _servicos[index].copyWith(status: StatusServico.nfEmitida);
      await _salvar();

      await notaFiscalProvider.adicionarNota(NotaFiscal(
        id: const Uuid().v4(),
        servicoId: servicoId,
        tomadorRazaoSocial: servico.tomadorNome,
        tomadorCnpj: servico.tomadorCnpj,
        cnpjEmissor: cnpjEmissor,
        valor: servico.valor,
        competencia: servico.data,
        emitidaEm: DateTime.now(),
        status: StatusNota.autorizada,
        numeroNota: numero,
        chaveAcesso: chave,
        linkPdf: 'https://danfse.medvie.app/mock/$numero.pdf',
      ));
      notifyListeners();
      return true;
    } else {
      _servicos[index] =
          _servicos[index].copyWith(status: StatusServico.nfRejeitada);
      await _salvar();

      await notaFiscalProvider.adicionarNota(NotaFiscal(
        id: const Uuid().v4(),
        servicoId: servicoId,
        tomadorRazaoSocial: servico.tomadorNome,
        tomadorCnpj: servico.tomadorCnpj,
        cnpjEmissor: cnpjEmissor,
        valor: servico.valor,
        competencia: servico.data,
        emitidaEm: DateTime.now(),
        status: StatusNota.rejeitada,
        motivoRejeicao:
            'CNPJ do tomador não encontrado na Receita Federal. Verifique os dados do hospital e tente novamente.',
      ));
      notifyListeners();
      return false;
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

  /// Recoloca NF rejeitada na fila de emissão.
  Future<void> reenviarNfRejeitada(
    String servicoId,
    NotaFiscalProvider notaFiscalProvider,
  ) async {
    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return;
    if (_servicos[index].status != StatusServico.nfRejeitada) return;

    final notaAnterior = notaFiscalProvider.porServicoId(servicoId);
    if (notaAnterior != null) {
      await notaFiscalProvider.removerNota(notaAnterior.id);
    }

    _servicos[index] =
        _servicos[index].copyWith(status: StatusServico.confirmado);
    await _salvar();
    notifyListeners();
  }

  /// Reverte todos os serviços com NF (emitida, em processamento ou rejeitada)
  /// de volta para [StatusServico.confirmado], usado pelo Dev Tools ao apagar notas.
  Future<void> reverterStatusNf() async {
    bool alterou = false;
    for (int i = 0; i < _servicos.length; i++) {
      final s = _servicos[i];
      if (s.status == StatusServico.nfEmitida ||
          s.status == StatusServico.nfEmProcessamento ||
          s.status == StatusServico.nfRejeitada) {
        _servicos[i] = s.copyWith(status: StatusServico.confirmado);
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

  Future<void> carregar() async {
    _carregando = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chavePrefs);
      if (raw != null) {
        final lista = jsonDecode(raw) as List<dynamic>;
        _servicos
          ..clear()
          ..addAll(
              lista.map((e) => Servico.fromJson(e as Map<String, dynamic>)));
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

  String _gerarNumeroNota() {
    return (Random().nextInt(99999) + 1).toString().padLeft(9, '0');
  }

  String _gerarChaveAcesso(String tomadorCnpj, DateTime competencia) {
    final cnpjLimpo = tomadorCnpj.replaceAll(RegExp(r'\D'), '');
    final prefix = cnpjLimpo.length >= 8 ? cnpjLimpo.substring(0, 8) : cnpjLimpo.padLeft(8, '0');
    final ano = competencia.year.toString();
    final mes = competencia.month.toString().padLeft(2, '0');
    final rand = Random().nextInt(999999999).toString().padLeft(9, '0');
    return 'RJ$prefix$ano$mes$rand';
  }
}