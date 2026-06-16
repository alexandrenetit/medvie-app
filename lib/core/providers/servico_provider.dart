// lib/core/providers/servico_provider.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/medico.dart' show EnderecoFiscalTomador, TipoTomador, Tomador;
import '../models/nota_fiscal.dart';
import '../models/servico.dart';
import '../services/medvie_api_service.dart';
import 'dashboard_provider.dart';
import 'nota_fiscal_provider.dart';

class ServicoProvider extends ChangeNotifier {
  final MedvieApiService? _api;

  /// Referência ao DashboardProvider injetada por [SyncViewCard] para permitir
  /// atualização in-memory após POST /servicos, sem GET /dashboard adicional.
  DashboardProvider? _dashboardRef;
  set dashboardRef(DashboardProvider? ref) => _dashboardRef = ref;

  /// [api] é opcional para manter retrocompatibilidade com testes que
  /// instanciam o provider sem injeção.
  ServicoProvider({MedvieApiService? api}) : _api = api;

  bool _mounted = true;

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  final List<Servico> _servicos = [];
  bool _carregando = false;

  // ─── Paginação ───────────────────────────────────────────────────────────
  static const _kTamanhoPagina = 50;
  int _pagina = 1;
  bool _temMais = true;
  bool _carregandoMais = false;

  bool get temMais => _temMais;
  bool get carregandoMais => _carregandoMais;

  // ─────────────────────────────────────────────
  // Getters — listas
  // ─────────────────────────────────────────────

  List<Servico> get servicos => List.unmodifiable(_servicos);
  bool get carregando => _carregando;

  DateTime? _diaFiltrado;

  List<Servico> get servicosFiltrados {
    if (_diaFiltrado == null) return servicos;
    return _servicos
        .where(
          (s) =>
              s.data.year == _diaFiltrado!.year &&
              s.data.month == _diaFiltrado!.month &&
              s.data.day == _diaFiltrado!.day,
        )
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
  List<Servico> get pendentesDEmissao =>
      _servicos.where((s) => s.status.pendenteDEmissao).toList()
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

  List<Servico> doMes(int ano, int mes) =>
      _servicos.where((s) => s.data.year == ano && s.data.month == mes).toList()
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
  /// Em sucesso (ou sem API), mantém em memória durante a sessão.
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
      final requisicaoId = const Uuid().v4();
      debugPrint(
        '[PROVIDER] criarServico — cnpjProprioId=$cnpjProprioId requisicaoId=$requisicaoId',
      );
      final response = await _api.criarServico(cnpjProprioId, {
        ...servico.toJson(),
        'requisicaoId': requisicaoId,
      });
      debugPrint(
        '[PROVIDER] criarServico OK — response keys=${response.keys.toList()}',
      );
      // Atualiza dashboard com os totais do response antes de notificar,
      // evitando GET /dashboard redundante disparado pelo listener.
      final bruto = (response['brutoAcumuladoMes'] as num?)?.toDouble() ?? 0;
      final liquido = (response['liquidoEstimadoMes'] as num?)?.toDouble() ?? 0;
      final meta = (response['metaMensal'] as num?)?.toDouble() ?? 0;
      if (bruto > 0) {
        _dashboardRef?.atualizarComTotais(
          bruto: bruto,
          liquido: liquido,
          meta: meta,
        );
      }
      // Inserção otimista — UI reflete o novo item imediatamente, mesmo se GET falhar
      _servicos.add(servico);
      notifyListeners();
      // Sincroniza com backend para garantir consistência (IDs, campos calculados)
      debugPrint('[PROVIDER] iniciando carregar pós-POST');
      try {
        await carregar(cnpjProprioId: cnpjProprioId);
        debugPrint('[PROVIDER] carregar pós-POST OK');
      } catch (e) {
        debugPrint('[PROVIDER] carregar pós-POST ERRO (ignorado): $e');
        // Sync pós-POST é best-effort — serviço já persistido no backend
      }
      debugPrint(
        '[PROVIDER] adicionarServico concluído — retornando ao caller',
      );
    } else {
      debugPrint('[PROVIDER] sem API/cnpjProprioId — apenas memória');
      // Sem sessão ativa ou cnpjProprioId: mantém apenas em memória
      _servicos.add(servico);
      notifyListeners();
    }
  }

  Future<void> atualizarServico(Servico atualizado) async {
    final index = _servicos.indexWhere((s) => s.id == atualizado.id);
    if (index == -1) return;
    _servicos[index] = atualizado;
    notifyListeners();
  }

  Future<void> removerServico(String id) => Future<void>.sync(() {
    _servicos.removeWhere((s) => s.id == id);
    notifyListeners();
  });

  Future<void> excluirServico(String servicoId, String cnpjProprioId) async {
    final api = _api;
    if (api != null) await api.excluirServico(servicoId, cnpjProprioId);
    _servicos.removeWhere((s) => s.id == servicoId);
    notifyListeners();
  }

  Future<void> limparServicos() => Future<void>.sync(() {
    _servicos.clear();
    notifyListeners();
  });

  // ─────────────────────────────────────────────
  // Ciclo de vida fiscal
  // ─────────────────────────────────────────────

  Future<void> confirmarExecucao(String servicoId) async {
    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return;
    final servico = _servicos[index];
    if (servico.status != StatusServico.pendente) return;
    // pendente já é o estado executável; no-op mas mantido para compatibilidade
    notifyListeners();
  }

  /// Promove pendentes cuja data/hora já passou (mantém retrocompatibilidade).
  Future<void> sincronizarStatusPorTempo() => Future<void>.sync(() {
    final agora = DateTime.now();
    bool houveMudanca = false;

    for (int i = 0; i < _servicos.length; i++) {
      final s = _servicos[i];
      if (s.status != StatusServico.pendente) continue;

      DateTime dataFim;
      if (s.horaFim != null) {
        dataFim = DateTime(
          s.data.year,
          s.data.month,
          s.data.day,
          s.horaFim!.hour,
          s.horaFim!.minute,
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
      notifyListeners();
    }
  });

  /// Emite NFS-e via backend para um único serviço.
  ///
  /// Contratos de IDs:
  /// - [cnpjEmissor]: CNPJ raw 14 dígitos (POST /api/v1/notas aceita via CnpjResolver).
  /// - [cnpjProprioGuidParaReload]: Guid do CnpjProprio (GET /api/v1/notas e GET
  ///   /api/v1/servicos exigem Guid — não há resolver no caminho de leitura).
  /// Sem fallback: parâmetro obrigatório para evitar 400 silencioso no reload.
  Future<bool> emitirNf(
    String servicoId,
    NotaFiscalProvider notaFiscalProvider,
    String cnpjEmissor, {
    required String cnpjProprioGuidParaReload,
  }) async {
    if (_api == null) throw Exception('MedvieApiService não injetado');

    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return false;

    final servico = _servicos[index];
    if (!servico.status.pendenteDEmissao) return false;

    // A-08: valida tomadorId antes de chamar a API
    if (servico.tomadorId == null || servico.tomadorId!.isEmpty) {
      throw Exception(
        'Tomador não vinculado — sincronize os serviços antes de emitir',
      );
    }

    // 1. Feedback visual imediato
    _servicos[index] = servico.copyWith(
      status: StatusServico.nfEmProcessamento,
    );
    notifyListeners();

    try {
      final notaFiscalId = await _api.emitirNota(
        servicoId: servicoId,
        cnpjProprioId: cnpjEmissor,
        tomadorId: servico.tomadorId!,
        aliquotaIss: servico.aliquotaIss,
        issRetido: servico.issRetido,
      );

      if (notaFiscalId != null && notaFiscalId.trim().isNotEmpty) {
        final agoraUtc = DateTime.now().toUtc();
        notaFiscalProvider.adicionarNotaLocal(
          NotaFiscal(
            id: notaFiscalId.trim(),
            status: StatusNota.emProcessamento.name,
            codigoNbs: servico.tipo.codigoNbs,
            servicoId: servicoId,
            tomadorNome: servico.tomadorNome,
            valorBruto: servico.valor,
            tipoServico: servico.tipo.toJson,
            dataServico: DateTime.utc(
              servico.data.year,
              servico.data.month,
              servico.data.day,
            ),
            dataEmissao: agoraUtc,
            createdAt: agoraUtc,
            updatedAt: agoraUtc,
          ),
        );
      }

      // Recarrega lista após 3s para capturar status final do backend.
      // Usa SEMPRE o Guid — GET /notas e GET /servicos rejeitam CNPJ raw com 400.
      Future.delayed(const Duration(seconds: 3), () async {
        if (!_mounted) return;
        try {
          await notaFiscalProvider.carregar(cnpjProprioGuidParaReload);
          if (!_mounted) return;
          await carregar(cnpjProprioId: cnpjProprioGuidParaReload);
        } catch (_) {}
      });

      return true;
    } catch (e) {
      // Reverte para pendente em caso de erro de rede/servidor
      _servicos[index] = _servicos[index].copyWith(
        status: StatusServico.pendente,
      );
      notifyListeners();
      rethrow;
    }
  }

  /// Emite NFS-e para todos os pendentes em PARALELO via Future.wait.
  /// Evita loop sequencial que travava a UI thread.
  Future<Map<String, int>> emitirTodasNfsPendentes(
    NotaFiscalProvider notaFiscalProvider,
    String cnpjEmissor, {
    required String cnpjProprioGuidParaReload,
  }) async {
    final pendentes = List<Servico>.from(pendentesDEmissao);
    if (pendentes.isEmpty) return {'autorizadas': 0, 'rejeitadas': 0};

    final resultados = await Future.wait(
      pendentes.map(
        (s) => emitirNf(
          s.id,
          notaFiscalProvider,
          cnpjEmissor,
          cnpjProprioGuidParaReload: cnpjProprioGuidParaReload,
        ),
      ),
    );

    final autorizadas = resultados.where((r) => r).length;
    final rejeitadas = resultados.where((r) => !r).length;

    return {'autorizadas': autorizadas, 'rejeitadas': rejeitadas};
  }

  // ─────────────────────────────────────────────
  // Atendimento PF (feature 017)
  // ─────────────────────────────────────────────

  /// Auto-load CPF-first (FR-015): consulta o backend pelo CPF e devolve o
  /// resultado tipado (encontrado/novoPaciente/cpfInvalido). O CPF é apenas
  /// argumento transiente — nunca é armazenado no provider nem logado (SC-004).
  Future<LookupTomadorResponse> lookupPacientePorCpf({
    required String cnpjProprioId,
    required String documentoCpf,
  }) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');
    return api.lookupTomadorPorCpf(
      cnpjProprioId: cnpjProprioId,
      documento: documentoCpf,
    );
  }

  /// Autofill de endereço fiscal via backend (FR-004). Retorna o endereço com
  /// `numero`/`complemento` vazios para o médico completar. Em falha (CEP
  /// inexistente/timeout), relança — a UI cai no preenchimento manual.
  Future<EnderecoFiscalTomador> buscarEnderecoFiscal(String cep) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');
    final cepNumerico = cep.replaceAll(RegExp(r'\D'), '');
    final resposta = await api.buscarCep(cepNumerico);
    return resposta.toEnderecoFiscal(cepNumerico);
  }

  /// Confirma o atendimento PF (FR-017, passo 1): cria tomador PF + serviço de
  /// forma atômica e idempotente (`emitirAgora=false`). NÃO emite a nota aqui —
  /// a emissão é o passo seguinte via [emitirNf] disparada pelo
  /// `EmissaoConfirmacaoSheet`, exatamente como no plantonista.
  ///
  /// O `documentoCpf` é transiente: vai só no request e é descartado. O
  /// [Servico] local guarda apenas o documento mascarado (FR-002/SC-004).
  /// Retorna a resposta do backend (`servicoId`/`tomadorId`/preview) para a UI
  /// abrir a confirmação de emissão.
  Future<AtendimentoPfResponse> confirmarAtendimentoPf({
    required String cnpjProprioId,
    required String documentoCpf,
    required String nomePaciente,
    required EnderecoFiscalTomador endereco,
    required TipoServico tipoServico,
    required String descricao,
    required double valor,
    required DateTime competencia,
    String? email,
    String? telefone,
  }) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');

    final request = AtendimentoPfRequest(
      requisicaoId: const Uuid().v4(),
      cnpjProprioId: cnpjProprioId,
      tomador: AtendimentoPfTomadorRequest(
        documento: documentoCpf,
        nome: nomePaciente,
        email: email,
        telefone: telefone,
        endereco: endereco,
      ),
      servico: AtendimentoPfServicoRequest(
        tipoServico: tipoServico.backendEnumName,
        codigoNbs: tipoServico.codigoNbs,
        descricao: descricao,
        valor: valor,
        competencia: competencia,
        codigoMunicipioPrestacao: endereco.codigoMunicipioIbge,
      ),
    );

    final response = await api.criarAtendimentoPf(request);

    // Serviço local a partir da resposta — sem CPF bruto, só mascarado.
    final servico = Servico(
      id: response.servicoId,
      tipo: tipoServico,
      data: competencia,
      tomadorCnpj: '',
      tomadorNome: response.tomador.razaoSocial.isNotEmpty
          ? response.tomador.razaoSocial
          : nomePaciente,
      tomadorId: response.tomador.id,
      valor: valor,
      status: StatusServico.pendente,
      observacao: descricao,
      tomadorTipo: TipoTomador.cpf,
      tomadorDocumentoMascarado: response.tomador.documentoMascarado,
      tomadorEnderecoFiscalStatus: response.tomador.enderecoFiscalStatus,
    );

    // Idempotência: o backend reusa por requisicaoId; substitui se já existir.
    final idx = _servicos.indexWhere((s) => s.id == servico.id);
    if (idx >= 0) {
      _servicos[idx] = servico;
    } else {
      _servicos.add(servico);
    }
    notifyListeners();
    return response;
  }

  /// Preview fiscal live do atendimento (PF ou CNPJ — agnóstico a tomador):
  /// IBS/CBS regime-aware, SEM persistir serviço. Delega ao backend (fonte única
  /// da verdade); o app só renderiza. ISS/IRRF do tomador NÃO vêm deste preview
  /// (o endpoint não recebe tomador) — vêm do cadastro do tomador. A UI exibe
  /// "a definir no envio" / "Não retém" e nunca infere alíquota (G7/F5).
  Future<AtendimentoFiscalPreview> previewFiscalAtendimento({
    required String cnpjProprioId,
    required double valor,
    required DateTime competencia,
  }) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');
    return api.previewAtendimentoPf(
      cnpjProprioId: cnpjProprioId,
      valor: valor,
      competencia: competencia,
    );
  }

  /// Confirma o atendimento Empresa/Convênio (tomador CNPJ): persiste o serviço
  /// vinculado a um [Tomador] que JÁ existe no backend — usa o `tomadorId`, NÃO
  /// cria tomador (diferente de [confirmarAtendimentoPf], que cria o tomador PF
  /// junto). Idempotente por `requisicaoId`; `emitirAgora=false` — a emissão é o
  /// passo seguinte via [emitirNf] disparada pelo `EmissaoConfirmacaoSheet`,
  /// igual ao plantonista/PF.
  ///
  /// As retenções (ISS/IRRF) vêm do cadastro do [tomador] (fonte de verdade do
  /// tomador); o preview fiscal oficial é do backend ([previewFiscalAtendimento]).
  /// A UI de captura NÃO infere alíquota (G7/F5).
  ///
  /// Retorna o [Servico] persistido (com o `servicoId` do backend) para a UI
  /// abrir a confirmação de emissão.
  Future<Servico> confirmarAtendimentoCnpj({
    required String cnpjProprioId,
    required Tomador tomador,
    required TipoServico tipoServico,
    required String descricao,
    required double valor,
    required DateTime competencia,
    required StatusServico status,
    TimeOfDay? horaInicio,
    TimeOfDay? horaFim,
  }) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');
    if (tomador.id.isEmpty) {
      throw Exception('Tomador sem id — cadastre o tomador antes de confirmar');
    }

    final servico = Servico(
      id: const Uuid().v4(),
      tipo: tipoServico,
      data: competencia,
      tomadorCnpj: tomador.cnpj,
      tomadorNome: tomador.razaoSocial,
      tomadorId: tomador.id,
      valor: valor,
      status: status,
      observacao: descricao,
      horaInicio: horaInicio,
      horaFim: horaFim,
      aliquotaIss: tomador.aliquotaIss,
      issRetido: tomador.retemIss,
      retemIrrf: tomador.retemIrrf,
      aliquotaIrrf: tomador.aliquotaIrrf,
      tomadorTipo: TipoTomador.cnpj,
    );

    // Backend é fonte primária; idempotente por requisicaoId (não emite NFS-e).
    final response = await api.criarServico(cnpjProprioId, {
      ...servico.toJson(),
      'requisicaoId': const Uuid().v4(),
    });

    final servicoId = response['servicoId'] as String?;
    final persistido = (servicoId != null && servicoId.isNotEmpty)
        ? servico.copyWith(id: servicoId)
        : servico;

    // Idempotência: substitui se o backend reusou a criação anterior.
    final idx = _servicos.indexWhere((s) => s.id == persistido.id);
    if (idx >= 0) {
      _servicos[idx] = persistido;
    } else {
      _servicos.add(persistido);
    }
    notifyListeners();
    return persistido;
  }

  /// Cadastra um tomador CNPJ standalone (Ramo A — cadastro inline F3) e retorna
  /// o [Tomador] com o `id` gerado pelo backend, pronto para a UI auto-selecionar.
  /// Backend = fonte da verdade do tomador (retenções/alíquotas vêm do cadastro).
  /// O provider NÃO guarda a lista de tomadores (vive no `OnboardingProvider`,
  /// T0.2) — a inclusão na lista + seleção é responsabilidade da UI (F3).
  ///
  /// ⚠ O body de [MedvieApiService.cadastrarTomador] ainda não envia
  /// `aliquotaIrrf`/`inscricaoMunicipal`/endereço fiscal completo (§10) —
  /// pendência de contrato a fechar em F3.T3.1 (estender body vs backend derivar).
  Future<Tomador> criarTomadorCnpj({
    required String cnpjProprioId,
    required Tomador tomador,
  }) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');
    if (tomador.cnpj.trim().isEmpty) {
      throw Exception('CNPJ obrigatório para cadastrar o tomador');
    }

    final tomadorId = await api.cadastrarTomador(cnpjProprioId, tomador);
    if (tomadorId.isEmpty) {
      throw Exception('Backend não retornou o id do tomador');
    }
    return tomador.copyWith(id: tomadorId);
  }

  /// Lookup de CNPJ no backend (F3.T3.2) para o cadastro inline de tomador.
  /// Retorna um [Tomador] pré-preenchido com razão social, município/UF e
  /// código IBGE vindos da Receita (backend = verdade); demais campos
  /// (e-mail/valor/retenções) o usuário completa no form. DV não é exigido no
  /// app (CNPJ alfanumérico jul/2026). Propaga a exceção do service em falha
  /// (CNPJ não encontrado / rede) — a UI decide a mensagem.
  Future<Tomador> buscarTomadorPorCnpj(String cnpj) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');
    final limpo = cnpj.trim();
    if (limpo.isEmpty) throw Exception('CNPJ obrigatório para o lookup');

    final dados = await api.buscarCnpj(limpo);
    return Tomador(
      cnpj: limpo,
      razaoSocial: dados.razaoSocial,
      municipio: dados.municipio,
      uf: dados.uf,
      codigoIbge: dados.codigoIbge,
    );
  }

  /// "Mesmo paciente, mesmo serviço" (US3/T060): repete um atendimento usando
  /// o `tomadorId` já existente — NÃO precisa de CPF bruto (reusa o tomador no
  /// backend). Preserva tipo/valor/descrição/documento mascarado/status fiscal
  /// e gera nova competência (hoje). Persiste via `POST /servicos` (idempotente
  /// por requisicaoId) e adiciona o novo serviço à lista.
  Future<Servico> repetirServico(
    Servico base, {
    required String cnpjProprioId,
  }) async {
    final api = _api;
    if (api == null) throw Exception('MedvieApiService não injetado');
    if (base.tomadorId == null || base.tomadorId!.isEmpty) {
      throw Exception(
        'Serviço sem tomador vinculado — não é possível repetir',
      );
    }

    final nova = base.copyWith(
      id: const Uuid().v4(),
      data: DateTime.now(),
      status: StatusServico.pendente,
    );
    final response = await api.criarServico(cnpjProprioId, {
      ...nova.toJson(),
      'requisicaoId': const Uuid().v4(),
    });

    final servicoId = response['servicoId'] as String?;
    final persistida = (servicoId != null && servicoId.isNotEmpty)
        ? nova.copyWith(id: servicoId)
        : nova;
    _servicos.add(persistida);
    notifyListeners();
    return persistida;
  }

  /// Recoloca serviço cancelado na fila de emissão.
  Future<void> reenviarNfRejeitada(
    String servicoId,
    NotaFiscalProvider notaFiscalProvider,
  ) async {
    final index = _servicos.indexWhere((s) => s.id == servicoId);
    if (index == -1) return;
    if (_servicos[index].status != StatusServico.cancelado) return;

    _servicos[index] = _servicos[index].copyWith(
      status: StatusServico.pendente,
    );
    notifyListeners();
  }

  /// Reverte serviços com NF de volta para [StatusServico.pendente].
  /// Usado pelo Dev Tools ao apagar notas.
  Future<void> reverterStatusNf() => Future<void>.sync(() {
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
      notifyListeners();
    }
  });

  // ─────────────────────────────────────────────
  // Carregamento (session-only — sem cache em disco)
  // ─────────────────────────────────────────────

  /// Carrega serviços — sempre reseta para página 1.
  /// Se [cnpjProprioId] for fornecido e [_api] estiver injetado, busca do
  /// backend. Sem API ou sem cnpjProprioId, retorna lista vazia (session-only).
  Future<void> carregar({String? cnpjProprioId}) async {
    _carregando = true;
    _pagina = 1;
    _temMais = true;
    notifyListeners();
    try {
      if (_api != null && cnpjProprioId != null && cnpjProprioId.isNotEmpty) {
        // Fonte primária: backend (página 1)
        final lista = await _api.listarServicos(
          cnpjProprioId,
          pagina: 1,
          tamanhoPagina: _kTamanhoPagina,
        );
        _servicos
          ..clear()
          ..addAll(lista.map((e) => Servico.fromJson(e)));
        if (lista.length < _kTamanhoPagina) _temMais = false;
      } else {
        // Sem sessão ativa: lista vazia — dados carregados após autenticação
        _temMais = false;
      }
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Carrega a próxima página de serviços e anexa à lista atual.
  /// No-op se já está carregando, não há mais itens, ou sem API.
  Future<void> carregarMais(String cnpjProprioId) async {
    if (_api == null || !_temMais || _carregandoMais || _carregando) return;
    _carregandoMais = true;
    notifyListeners();
    try {
      _pagina++;
      final lista = await _api.listarServicos(
        cnpjProprioId,
        pagina: _pagina,
        tamanhoPagina: _kTamanhoPagina,
      );
      _servicos.addAll(lista.map((e) => Servico.fromJson(e)));
      if (lista.length < _kTamanhoPagina) _temMais = false;
    } catch (_) {
      _pagina--; // reverte em caso de erro para permitir retry
    } finally {
      _carregandoMais = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // Helpers mock
  // ─────────────────────────────────────────────
}
