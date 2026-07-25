// lib/core/providers/onboarding_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../errors/mensagem_erro.dart';
import '../models/medico.dart';
import '../models/especialidade.dart';
import '../models/perfil_atuacao.dart';
import '../services/medvie_api_service.dart';
import 'certificado_provider.dart';

// M-08: ID fixo para "Outra especialidade" no backend.
// Definido como constante para facilitar rastreamento se o backend renumerar.
const _kEspecialidadeOutraId = 29;
const _kCpfHashKey = 'cpfHash';
const _kCpfDigitsKey = 'cpfDigits';
const _kCpfKey = 'cpf';
const _kMedicoKey = 'medico';
const _kMedicoIdKey = 'medicoId';
const _kRefreshTokenKey = 'auth_refresh_token';
const _kLegacyRefreshTokenKey = 'gotrue_refresh_token';
const _kLegacyGoTrueEmailKey = 'gotrue_email';

class OnboardingProvider extends ChangeNotifier {
  // --- Serviço de API ---
  final MedvieApiService api;
  final FlutterSecureStorage _secureStorage;

  // --- Dados do médico (Step 1) ---
  String nome = '';
  String cpf = '';
  String crm = '';
  String ufCrm = '';
  Especialidade? especialidade;

  // --- Step atual do onboarding (fonte: backend) ---
  int stepAtual = 0;

  // --- CNPJ atual sendo cadastrado (Step 2) ---
  String cnpjAtual = '';
  String razaoSocialAtual = '';
  String municipioAtual = '';
  String codigoMunicipioAtual = '';
  String ufAtual = '';
  String inscricaoMunicipalAtual = '';
  String? nomeFantasiaAtual;
  String? situacaoAtual;
  String? porteAtual;
  String? aberturaAtual;
  bool buscandoCnpj = false;
  String? erroCnpj;
  bool erroCnpjApiDown = false;
  RegimeTributario regimeAtual = RegimeTributario.simplesNacional;

  /// Método de assinatura escolhido para o CNPJ atual
  MetodoAssinatura metodoAssinaturaAtual = MetodoAssinatura.certificadoA1;

  /// Status agregado da credencial do CNPJ atual em onboarding.
  ///
  /// Derivado em runtime a partir do método de assinatura e — quando A1 — do
  /// estado real do [CertificadoProvider] anexado via [attachCertificado].
  /// Evita duplicação de fonte de verdade (backend é o dono via
  /// `CertificadoProvider`; este getter apenas reflete o estado para a UI de
  /// onboarding sem precisar do consumer expor o provider de certificado).
  ///
  /// Regras:
  /// - Método != `certificadoA1` (ex.: gov.br) → [StatusCertificado.ativo],
  ///   pois não exige PFX para liberar avanço.
  /// - Método `certificadoA1`:
  ///   - [CertificadoSuccess]  → status retornado pelo backend (Ativo, Expirado, ...).
  ///   - qualquer outro estado → [StatusCertificado.pendente].
  StatusCertificado get statusCertificadoAtual {
    if (metodoAssinaturaAtual != MetodoAssinatura.certificadoA1) {
      return StatusCertificado.ativo;
    }
    final state = _cert?.state;
    if (state is CertificadoSuccess) return state.metadata.status;
    return StatusCertificado.pendente;
  }

  // --- Tomadores do CNPJ atual (Step 3) ---
  List<Tomador> tomadoresAtual = [];

  // --- Lista acumulada de CNPJs já finalizados ---
  List<CnpjComTomadores> cnpjsFinalizados = [];

  // --- Perfil de atuação (step 1b) ---
  // Backend é fonte da verdade — restaurado via onboarding-status.
  // Default: medicoClinico para médicos sem perfil definido.
  PerfilAtuacao perfilAtuacao = PerfilAtuacao.medicoClinico;

  /// True quando step 3 (tomadores) deve ser exibido no wizard.
  bool get mostrarStep3 => perfilAtuacao == PerfilAtuacao.plantonistaHospitalar;

  // --- Médico carregado após onboarding completo ---
  Medico? medico;

  // A-06: fonte única de verdade para o ID do médico.
  String? get medicoId => medico?.id ?? medicoIdSalvo;

  // Mantido só para compatibilidade de UI/testes legados; não é persistido.
  String? cpfDigitsSalvo;

  // --- Erro durante finalização do onboarding ---
  String? erroFinalizar;

  // --- Persistência progressiva ---
  String? medicoIdSalvo;
  bool restaurando = true;
  Map<String, String> cnpjProprioIdsPorCnpj = {};
  final Map<String, Set<String>> _tomadoresCadastradosPorCnpj = {};
  bool salvandoMedico = false;
  bool salvandoCnpj = false;
  bool salvandoTomadores = false;
  bool onboardingCompletoFlag = false;

  /// Referência ao [CertificadoProvider] usada pelo gate do step 2b.
  /// Injetada via [attachCertificado] em `main()` — opcional para testes que
  /// não exercitam o fluxo de certificado digital.
  CertificadoProvider? _cert;

  OnboardingProvider({required this.api, FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _restaurarSessao();
  }

  /// Boot: apenas detecta se já existe usuário registrado (sem chamadas à API).
  /// O login e a restauração de dados são feitos via [loginERestaurar].
  Future<void> _restaurarSessao() async {
    restaurando = true;
    notifyListeners();
    await _limparIdentidadePrimariaLocal();
    cpfDigitsSalvo = null;
    restaurando = false;
    notifyListeners();
  }

  /// Chamado pela AuthScreen após o médico informar CPF + senha.
  /// Faz login no backend e restaura os dados do onboarding via API.
  /// Lança exceção em caso de credenciais inválidas.
  Future<void> loginERestaurar(String cpf, String senha) async {
    final medicoIdAutenticado = await api.login(cpf, senha);
    medicoIdSalvo = medicoIdAutenticado;
    cpfDigitsSalvo = null;
    this.cpf = cpf;

    try {
      final status = await api.getOnboardingStatus(medicoIdAutenticado);
      medicoIdSalvo = status.medico?.id;
      medicoIdSalvo ??= medicoIdAutenticado;
      onboardingCompletoFlag = status.completo;
      stepAtual = status.step;
      if (status.medico != null) {
        final m = status.medico!;
        nome = m.fullName;
        crm = m.crm;
        ufCrm = m.ufCrm;
        email = m.email;
        telefone = m.phone ?? '';
        perfilAtuacao = m.perfilAtuacao;
        this.cpf = cpf;

        // FIX 1: resolve especialidade nome (24h cache)
        final especialidades = await api.listarEspecialidades();
        especialidade = especialidades.firstWhere(
          (e) => e.id == m.especialidadeId,
          orElse: () => Especialidade(id: m.especialidadeId, nome: ''),
        );
      }
      cnpjProprioIdsPorCnpj = {for (final c in status.cnpjs) c.cnpj: c.id};

      // A-02: resolve nomes de município em paralelo (elimina N+1 sequencial).
      // FIX 2: falls back to IBGE code if buscarCnpj fails.
      final municipiosResult = await Future.wait(
        status.cnpjs.map((c) async {
          try {
            final dados = await api.buscarCnpj(c.cnpj);
            return dados.municipio;
          } catch (_) {
            return c.codigoMunicipio;
          }
        }),
      );

      cnpjsFinalizados = List.generate(status.cnpjs.length, (i) {
        final c = status.cnpjs[i];
        return CnpjComTomadores(
          id: c.id,
          cnpj: c.cnpj,
          razaoSocial: c.razaoSocial,
          municipio: municipiosResult[i],
          codigoMunicipio: c.codigoMunicipio,
          tomadores: c.tomadores
              .map(
                (t) => Tomador(
                  id: t.id,
                  cnpj: t.cnpj ?? '',
                  razaoSocial: t.razaoSocial,
                  municipio: t.codigoMunicipioPrestacao,
                  uf: '',
                  valorPadrao: t.valorPadrao,
                  emailFinanceiro: t.emailFinanceiro,
                  codigoIbge: t.codigoMunicipioPrestacao,
                  retemIss: t.retemIss,
                  retemIrrf: t.retemIrrf,
                  aliquotaIss: t.aliquotaIss,
                  aliquotaIrrf: t.aliquotaIrrf,
                  inscricaoMunicipal: t.inscricaoMunicipal ?? '',
                  tipo: t.tipo,
                  documentoMascarado: t.documentoMascarado ?? '',
                ),
              )
              .toList(),
          inscricaoMunicipal: c.inscricaoMunicipal,
          regime: RegimeTributario.values.firstWhere(
            (r) => r.name.toLowerCase() == c.regimeTributario.toLowerCase(),
            orElse: () => RegimeTributario.simplesNacional,
          ),
          metodoAssinatura: MetodoAssinatura.certificadoA1,
          statusCertificado: StatusCertificado.pendente,
        );
      });

      // FIX 3: restore tomadoresAtual so agenda/syncview can read them
      tomadoresAtual = cnpjsFinalizados.expand((c) => c.tomadores).toList();

      // FIX 4: sempre restaura cnpjAtual quando há CNPJs cadastrados.
      // A restrição anterior (stepAtual 3-5) fazia cnpjAtual ficar vazio
      // ao voltar para o passo 4 com stepAtual == 6 (Confirmação).
      if (cnpjsFinalizados.isNotEmpty) {
        final ultimo = cnpjsFinalizados.last;
        cnpjAtual = ultimo.cnpj;
        razaoSocialAtual = ultimo.razaoSocial;
        municipioAtual = ultimo.municipio;
        codigoMunicipioAtual = ultimo.codigoMunicipio;
        inscricaoMunicipalAtual = ultimo.inscricaoMunicipal;
        _tomadoresCadastradosPorCnpj[ultimo.cnpj] = ultimo.tomadores
            .map((t) => t.cnpj)
            .toSet();
        // tomadoresAtual restrito ao CNPJ atual somente durante o step 3 (Tomadores)
        if (stepAtual >= 3 && stepAtual <= 5) {
          tomadoresAtual = ultimo.tomadores.toList();
        }
      }

      // Constrói Medico a partir do backend (fonte única da verdade)
      if (onboardingCompletoFlag && medicoIdSalvo != null) {
        medico = Medico(
          id: medicoIdSalvo!,
          nome: nome,
          cpf: cpf,
          crm: crm,
          ufCrm: ufCrm,
          especialidade: especialidade,
          email: email,
          telefone: telefone,
          cnpjs: List.from(cnpjsFinalizados),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[OnboardingProvider] erro ignorado: $e');
    }
    if (stepAtual > 0 && medicoIdSalvo != null) {
      final prefs = await SharedPreferences.getInstance();
      final stepPendente = prefs.getInt('stepPendente') ?? 0;
      if (stepPendente > stepAtual) {
        try {
          await api.atualizarOnboardingStep(medicoIdSalvo!, stepPendente);
          stepAtual = stepPendente;
        } catch (_) {}
        await prefs.remove('stepPendente');
      }
    }
    if (kDebugMode) {
      debugPrint('>>> LOGIN RESTAURAR medico: $medico');
      debugPrint('>>> LOGIN RESTAURAR cnpjs: ${medico?.cnpjs.length}');
    }
    notifyListeners();
  }

  // -------------------------------------------------------
  // Persistir step no backend (fire-and-forget)
  // -------------------------------------------------------
  /// Envia PATCH onboarding-step sem bloquear a navegação.
  /// Nunca regride: ignora chamadas com step <= stepAtual.
  void _persistirStep(int step) {
    if (medicoIdSalvo == null) return;
    if (step <= stepAtual) return;
    _persistirStepComRetry(step, tentativa: 1);
  }

  Future<void> _persistirStepComRetry(
    int step, {
    required int tentativa,
  }) async {
    try {
      await api.atualizarOnboardingStep(medicoIdSalvo!, step);
      stepAtual = step;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('stepPendente');
      notifyListeners();
    } catch (e) {
      if (tentativa < 3) {
        await Future.delayed(const Duration(seconds: 1));
        await _persistirStepComRetry(step, tentativa: tentativa + 1);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('stepPendente', step);
      }
    }
  }

  // -------------------------------------------------------
  // Restaurar progresso do backend (fonte única da verdade)
  // -------------------------------------------------------
  /// Consulta GET /api/v1/medicos/{medicoId}/onboarding-status e sincroniza
  /// stepAtual + onboardingCompletoFlag. Não usa SharedPreferences.
  Future<void> restaurarProgressoDoBackend(String medicoId) async {
    try {
      final status = await api.getOnboardingStatus(medicoId);
      stepAtual = status.step;
      onboardingCompletoFlag = status.completo;
      if (status.medico != null) {
        final m = status.medico!;
        nome = m.fullName;
        crm = m.crm;
        ufCrm = m.ufCrm;
        email = m.email;
        telefone = m.phone ?? '';
        perfilAtuacao = m.perfilAtuacao;
      }
      if (status.cnpjs.isNotEmpty) {
        cnpjProprioIdsPorCnpj = {for (final c in status.cnpjs) c.cnpj: c.id};
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[OnboardingProvider] erro ignorado: $e');
    }
  }

  // -------------------------------------------------------
  // Aliases de compatibilidade
  // -------------------------------------------------------
  Medico? get medicoSalvo => medico;
  List<Tomador> get tomadores {
    // [DEBUG-FILTRO-TOMADOR] log de diagnóstico — remover após validação.
    debugPrint('[TOMADORES-GET] count=${tomadoresAtual.length} '
        'tipos=${tomadoresAtual.map((t) => '${t.razaoSocial}=${t.tipo.name}').toList()}');
    return tomadoresAtual;
  }
  bool get carregandoTomador => false;
  String? get erroComador => null;
  bool get carregandoCnpjProprio => buscandoCnpj;
  String get razaoSocialPropria => razaoSocialAtual;
  String? get erroCnpjProprio => erroCnpj;
  Future<bool> buscarCnpjProprio(String cnpj) => buscarCnpj(cnpj);

  /// F3.T3.3 — insere na lista em memória ([tomadoresAtual], fonte do sheet de
  /// seleção — T0.2) um tomador já persistido no backend (retornado por
  /// `ServicoProvider.criarTomadorCnpj`) e notifica os ouvintes, exibindo-o de
  /// imediato sem refazer o fetch completo do médico. Idempotente: ignora se o
  /// mesmo `id` já estiver na lista.
  void adicionarTomadorEmMemoria(Tomador tomador) {
    // [DEBUG-FILTRO-TOMADOR] log de diagnóstico — remover após validação.
    debugPrint('[TOMADOR-ADD] id=${tomador.id} cnpj=${tomador.cnpj} '
        'razao=${tomador.razaoSocial} tipo=${tomador.tipo.name}');
    if (tomador.id.isNotEmpty &&
        tomadoresAtual.any((t) => t.id == tomador.id)) {
      return;
    }
    tomadoresAtual = [...tomadoresAtual, tomador];
    notifyListeners();
  }

  // -------------------------------------------------------
  // Validação CPF
  // -------------------------------------------------------
  static bool validarCpf(String cpf) {
    final numeros = cpf.replaceAll(RegExp(r'\D'), '');
    if (numeros.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(numeros)) return false;

    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += int.parse(numeros[i]) * (10 - i);
    }
    int d1 = (soma * 10) % 11;
    if (d1 == 10 || d1 == 11) d1 = 0;
    if (d1 != int.parse(numeros[9])) return false;

    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += int.parse(numeros[i]) * (11 - i);
    }
    int d2 = (soma * 10) % 11;
    if (d2 == 10 || d2 == 11) d2 = 0;
    if (d2 != int.parse(numeros[10])) return false;

    return true;
  }

  // -------------------------------------------------------
  // Step 1 — Perfil
  // -------------------------------------------------------
  String email = '';
  String telefone = '';

  void setPerfil({
    required String nome,
    required String cpf,
    required String crm,
    required String ufCrm,
    required Especialidade? especialidade,
    required String email,
    required String telefone,
  }) {
    this.nome = nome;
    this.cpf = cpf;
    this.crm = crm;
    this.ufCrm = ufCrm;
    this.especialidade = especialidade;
    this.email = email;
    this.telefone = telefone;
    notifyListeners();
  }

  // -------------------------------------------------------
  // Step 1b — Salvar Perfil de Atuação
  // -------------------------------------------------------
  /// Persiste o perfil de atuação localmente e no backend via PATCH.
  /// Chamado imediatamente após o médico selecionar um card na tela 1b.
  Future<void> salvarPerfilAtuacao(PerfilAtuacao perfil) async {
    perfilAtuacao = perfil;
    notifyListeners();

    if (medicoIdSalvo == null) return;

    await api.salvarStep1b(medicoIdSalvo!, perfil);
    _persistirStep(2); // avançou para step 1c
  }

  // -------------------------------------------------------
  // Step 1c — Salvar Especialidade
  // -------------------------------------------------------
  /// Persiste a especialidade localmente e no backend via PATCH.
  /// Chamado ao confirmar seleção na tela 1c.
  Future<void> salvarEspecialidade(Especialidade esp) async {
    especialidade = esp;
    notifyListeners();

    if (medicoIdSalvo == null) return;

    await api.atualizarMedico(medicoIdSalvo!, nome, email, telefone, esp.id);
    _persistirStep(3); // avançou para step 2a (CNPJ)
  }

  // -------------------------------------------------------
  // Persistência Progressiva — Salvar Médico (Step 1)
  // -------------------------------------------------------
  Future<void> salvarMedico(String senha) async {
    if (medicoIdSalvo != null) return; // Já foi salvo

    salvandoMedico = true;
    notifyListeners();

    try {
      final medicoTemp = Medico(
        id: '',
        nome: nome,
        cpf: cpf,
        crm: crm,
        ufCrm: ufCrm,
        especialidade: especialidade,
        email: email,
        telefone: telefone,
        cnpjs: [],
      );

      // especialidadeId (Outra) como default — step 1c atualizará via PATCH
      final id = await api.registrar(
        medicoTemp,
        especialidade?.id ?? _kEspecialidadeOutraId,
        senha,
      );
      medicoIdSalvo = id;

      notifyListeners();
      _persistirStep(1); // avançou para step 1b
    } finally {
      salvandoMedico = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------
  // Persistência Progressiva — Salvar CNPJ (Step 2)
  // -------------------------------------------------------
  Future<String> salvarCnpj(CnpjComTomadores cnpj) async {
    late String cnpjProprioId;

    // Se CNPJ já foi cadastrado, recupera o id existente
    if (cnpjProprioIdsPorCnpj.containsKey(cnpj.cnpj)) {
      cnpjProprioId = cnpjProprioIdsPorCnpj[cnpj.cnpj]!;
    } else {
      // Cadastra novo CNPJ
      salvandoCnpj = true;
      notifyListeners();

      try {
        cnpjProprioId = await api.cadastrarCnpj(medicoIdSalvo!, cnpj);
        cnpjProprioIdsPorCnpj[cnpj.cnpj] = cnpjProprioId;
        _persistirStep(4); // avançou para step 2b (Assinatura)
      } finally {
        salvandoCnpj = false;
        notifyListeners();
      }
    }

    // Cadastra apenas tomadores ainda não cadastrados
    if (cnpj.tomadores.isNotEmpty) {
      salvandoTomadores = true;
      notifyListeners();

      try {
        final tomadoresCadastrados = _tomadoresCadastradosPorCnpj.putIfAbsent(
          cnpj.cnpj,
          () => <String>{},
        );
        // Aqui você pode adicionar lógica para recuperar tomadores já cadastrados
        // Por enquanto, cadastra todos os tomadores da lista atual
        for (final tomador in cnpj.tomadores) {
          if (!tomadoresCadastrados.contains(tomador.cnpj)) {
            await api.cadastrarTomador(cnpjProprioId, tomador);
            tomadoresCadastrados.add(tomador.cnpj);
          }
        }
      } finally {
        salvandoTomadores = false;
        notifyListeners();
      }
    }

    return cnpjProprioId;
  }

  // -------------------------------------------------------
  // CRUD — Perfil (ProfileScreen — CPF imutável)
  // -------------------------------------------------------
  Future<void> atualizarPerfil({
    required String nome,
    required String crm,
    required String ufCrm,
    required Especialidade? especialidade,
    required String telefone,
    required String email,
  }) async {
    if (medico == null) return;
    medico = Medico(
      id: medico!.id,
      nome: nome,
      cpf: medico!.cpf, // CPF nunca é alterado
      crm: crm,
      ufCrm: ufCrm,
      especialidade: especialidade,
      telefone: telefone,
      email: email,
      cnpjs: medico!.cnpjs,
      endereco: medico!.endereco,
    );
    await _persistir();
  }

  // -------------------------------------------------------
  // CRUD — Endereço (ProfileScreen)
  // -------------------------------------------------------
  Future<void> atualizarEndereco(Endereco endereco) async {
    if (medico == null) return;
    medico = Medico(
      id: medico!.id,
      nome: medico!.nome,
      cpf: medico!.cpf,
      crm: medico!.crm,
      ufCrm: medico!.ufCrm,
      especialidade: medico!.especialidade,
      telefone: medico!.telefone,
      email: medico!.email,
      cnpjs: medico!.cnpjs,
      endereco: endereco,
    );
    await _persistir();
  }

  // -------------------------------------------------------
  // CRUD — CNPJs (ProfileScreen)
  // -------------------------------------------------------
  Future<String?> adicionarCnpj(String cnpj) async {
    if (medico == null) return 'Médico não carregado.';
    final numero = cnpj.replaceAll(RegExp(r'\D'), '');

    final jaExiste = medico!.cnpjs.any(
      (c) => c.cnpj.replaceAll(RegExp(r'\D'), '') == numero,
    );
    if (jaExiste) return 'Este CNPJ já está cadastrado.';

    try {
      final dados = await api.buscarCnpj(numero);
      final novo = CnpjComTomadores(
        cnpj: cnpj,
        razaoSocial: dados.razaoSocial,
        municipio: dados.municipio,
        codigoMunicipio: dados.codigoIbge,
        tomadores: [],
        inscricaoMunicipal: '',
        regime: RegimeTributario.simplesNacional,
        metodoAssinatura: MetodoAssinatura.certificadoA1,
        statusCertificado: StatusCertificado.pendente,
      );
      final cnpjsAtualizados = List<CnpjComTomadores>.from(medico!.cnpjs)
        ..add(novo);
      medico = Medico(
        id: medico!.id,
        nome: medico!.nome,
        cpf: medico!.cpf,
        crm: medico!.crm,
        ufCrm: medico!.ufCrm,
        especialidade: medico!.especialidade,
        telefone: medico!.telefone,
        email: medico!.email,
        cnpjs: cnpjsAtualizados,
        endereco: medico!.endereco,
      );
      await _persistir();
      return null;
    } catch (_) {
      return 'CNPJ não encontrado na Receita Federal.';
    }
  }

  Future<void> removerCnpj(String cnpj) async {
    if (medico == null) return;
    final cnpjsAtualizados = medico!.cnpjs
        .where((c) => c.cnpj != cnpj)
        .toList();
    medico = Medico(
      id: medico!.id,
      nome: medico!.nome,
      cpf: medico!.cpf,
      crm: medico!.crm,
      ufCrm: medico!.ufCrm,
      especialidade: medico!.especialidade,
      telefone: medico!.telefone,
      email: medico!.email,
      cnpjs: cnpjsAtualizados,
      endereco: medico!.endereco,
    );
    await _persistir();
  }

  Future<void> atualizarRegimeCnpj(String cnpj, RegimeTributario regime) async {
    if (medico == null) return;
    final cnpjsAtualizados = medico!.cnpjs.map((c) {
      if (c.cnpj == cnpj) {
        return CnpjComTomadores(
          cnpj: c.cnpj,
          razaoSocial: c.razaoSocial,
          municipio: c.municipio,
          codigoMunicipio: c.codigoMunicipio,
          tomadores: c.tomadores,
          inscricaoMunicipal: c.inscricaoMunicipal,
          regime: regime,
          metodoAssinatura: c.metodoAssinatura,
          statusCertificado: c.statusCertificado,
        );
      }
      return c;
    }).toList();
    medico = Medico(
      id: medico!.id,
      nome: medico!.nome,
      cpf: medico!.cpf,
      crm: medico!.crm,
      ufCrm: medico!.ufCrm,
      especialidade: medico!.especialidade,
      telefone: medico!.telefone,
      email: medico!.email,
      cnpjs: cnpjsAtualizados,
      endereco: medico!.endereco,
    );
    await _persistir();
  }

  // -------------------------------------------------------
  // CRUD — Tomadores (ProfileScreen)
  // -------------------------------------------------------
  Future<String?> adicionarTomadorAoCnpj(
    String cnpjProprio,
    String cnpjTomador, {
    double? valorPadrao,
    String? emailFinanceiro,
  }) async {
    if (medico == null) return 'Médico não carregado.';
    final numero = cnpjTomador.replaceAll(RegExp(r'\D'), '');

    try {
      final dados = await api.buscarCnpj(numero);
      final tomador = Tomador(
        cnpj: cnpjTomador,
        razaoSocial: dados.razaoSocial,
        municipio: dados.municipio,
        uf: dados.uf,
        valorPadrao: valorPadrao,
        emailFinanceiro: emailFinanceiro?.isEmpty == true
            ? null
            : emailFinanceiro,
      );
      final cnpjsAtualizados = medico!.cnpjs.map((c) {
        if (c.cnpj == cnpjProprio) {
          return CnpjComTomadores(
            cnpj: c.cnpj,
            razaoSocial: c.razaoSocial,
            municipio: c.municipio,
            codigoMunicipio: c.codigoMunicipio,
            tomadores: List<Tomador>.from(c.tomadores)..add(tomador),
            inscricaoMunicipal: c.inscricaoMunicipal,
            regime: c.regime,
            metodoAssinatura: c.metodoAssinatura,
            statusCertificado: c.statusCertificado,
          );
        }
        return c;
      }).toList();
      medico = Medico(
        id: medico!.id,
        nome: medico!.nome,
        cpf: medico!.cpf,
        crm: medico!.crm,
        ufCrm: medico!.ufCrm,
        especialidade: medico!.especialidade,
        telefone: medico!.telefone,
        email: medico!.email,
        cnpjs: cnpjsAtualizados,
        endereco: medico!.endereco,
      );
      await _persistir();
      return null;
    } catch (_) {
      return 'CNPJ do tomador não encontrado na Receita Federal.';
    }
  }

  Future<void> removerTomadorDoCnpj(String cnpjProprio, int index) async {
    if (medico == null) return;
    final cnpjsAtualizados = medico!.cnpjs.map((c) {
      if (c.cnpj == cnpjProprio) {
        final tomadoresAtualizados = List<Tomador>.from(c.tomadores)
          ..removeAt(index);
        return CnpjComTomadores(
          cnpj: c.cnpj,
          razaoSocial: c.razaoSocial,
          municipio: c.municipio,
          codigoMunicipio: c.codigoMunicipio,
          tomadores: tomadoresAtualizados,
          inscricaoMunicipal: c.inscricaoMunicipal,
          regime: c.regime,
          metodoAssinatura: c.metodoAssinatura,
          statusCertificado: c.statusCertificado,
        );
      }
      return c;
    }).toList();
    medico = Medico(
      id: medico!.id,
      nome: medico!.nome,
      cpf: medico!.cpf,
      crm: medico!.crm,
      ufCrm: medico!.ufCrm,
      especialidade: medico!.especialidade,
      telefone: medico!.telefone,
      email: medico!.email,
      cnpjs: cnpjsAtualizados,
      endereco: medico!.endereco,
    );
    await _persistir();
  }

  Future<void> atualizarValorPadrao(
    String cnpjProprio,
    String tomadorCnpj,
    double? valor,
  ) async {
    if (medico == null) return;
    final cnpjsAtualizados = medico!.cnpjs.map((c) {
      if (c.cnpj == cnpjProprio) {
        final tomadoresAtualizados = c.tomadores.map((t) {
          if (t.cnpj == tomadorCnpj) {
            return Tomador(
              cnpj: t.cnpj,
              razaoSocial: t.razaoSocial,
              municipio: t.municipio,
              uf: t.uf,
              valorPadrao: valor,
              emailFinanceiro: t.emailFinanceiro,
            );
          }
          return t;
        }).toList();
        return CnpjComTomadores(
          cnpj: c.cnpj,
          razaoSocial: c.razaoSocial,
          municipio: c.municipio,
          codigoMunicipio: c.codigoMunicipio,
          tomadores: tomadoresAtualizados,
          inscricaoMunicipal: c.inscricaoMunicipal,
          regime: c.regime,
          metodoAssinatura: c.metodoAssinatura,
          statusCertificado: c.statusCertificado,
        );
      }
      return c;
    }).toList();
    medico = Medico(
      id: medico!.id,
      nome: medico!.nome,
      cpf: medico!.cpf,
      crm: medico!.crm,
      ufCrm: medico!.ufCrm,
      especialidade: medico!.especialidade,
      telefone: medico!.telefone,
      email: medico!.email,
      cnpjs: cnpjsAtualizados,
      endereco: medico!.endereco,
    );
    await _persistir();
  }

  /// Envia PUT ao backend e atualiza o tomador localmente.
  /// Retorna `null` em sucesso ou mensagem de erro.
  Future<String?> atualizarTomador(
    String cnpjProprio,
    Tomador tomadorAtualizado,
  ) async {
    if (medico == null) return 'Médico não carregado.';
    if (tomadorAtualizado.id.isEmpty) {
      return 'Tomador sem ID — não é possível atualizar.';
    }

    try {
      await api.atualizarTomador(tomadorAtualizado.id, {
        'emailFinanceiro': tomadorAtualizado.emailFinanceiro,
        'valorPadrao': tomadorAtualizado.valorPadrao,
        'codigoMunicipioPrestacao': tomadorAtualizado.codigoIbge,
        'retemIss': tomadorAtualizado.retemIss,
        'aliquotaIss': tomadorAtualizado.aliquotaIss,
        'retemIrrf': tomadorAtualizado.retemIrrf,
        'inscricaoMunicipal': tomadorAtualizado.inscricaoMunicipal,
      });
    } catch (e) {
      return mensagemDeErro(e);
    }

    final cnpjsAtualizados = medico!.cnpjs.map((c) {
      if (c.cnpj != cnpjProprio) return c;
      final tomadoresAtualizados = c.tomadores.map((t) {
        final match = t.id.isNotEmpty
            ? t.id == tomadorAtualizado.id
            : t.cnpj == tomadorAtualizado.cnpj;
        return match ? tomadorAtualizado : t;
      }).toList();
      return CnpjComTomadores(
        cnpj: c.cnpj,
        razaoSocial: c.razaoSocial,
        municipio: c.municipio,
        codigoMunicipio: c.codigoMunicipio,
        tomadores: tomadoresAtualizados,
        inscricaoMunicipal: c.inscricaoMunicipal,
        regime: c.regime,
        metodoAssinatura: c.metodoAssinatura,
        statusCertificado: c.statusCertificado,
      );
    }).toList();

    medico = Medico(
      id: medico!.id,
      nome: medico!.nome,
      cpf: medico!.cpf,
      crm: medico!.crm,
      ufCrm: medico!.ufCrm,
      especialidade: medico!.especialidade,
      telefone: medico!.telefone,
      email: medico!.email,
      cnpjs: cnpjsAtualizados,
      endereco: medico!.endereco,
    );
    await _persistir();
    notifyListeners();
    return null;
  }

  // -------------------------------------------------------
  // Step 2 — CNPJ via BrasilAPI (onboarding)
  // -------------------------------------------------------
  Future<bool> buscarCnpj(String cnpj) async {
    final numero = cnpj.replaceAll(RegExp(r'\D'), '');
    buscandoCnpj = true;
    erroCnpj = null;
    notifyListeners();
    try {
      final dados = await api.buscarCnpj(numero);
      cnpjAtual = cnpj;
      razaoSocialAtual = dados.razaoSocial;
      municipioAtual = dados.municipio;
      codigoMunicipioAtual = dados.codigoIbge;
      ufAtual = dados.uf;
      nomeFantasiaAtual = dados.nomeFantasia;
      situacaoAtual = dados.situacao;
      porteAtual = dados.porte;
      aberturaAtual = dados.abertura;
      buscandoCnpj = false;
      erroCnpjApiDown = false;
      notifyListeners();
      return true;
    } catch (e) {
      final eStr = e.toString();
      erroCnpjApiDown =
          eStr.contains('timeout') ||
          eStr.contains('SocketException') ||
          eStr.contains('500') ||
          eStr.contains('502') ||
          eStr.contains('503');
      erroCnpj = erroCnpjApiDown
          ? null
          : 'CNPJ não encontrado na Receita Federal';
      buscandoCnpj = false;
      notifyListeners();
      return false;
    }
  }

  /// Ativa modo de preenchimento manual quando a Receita Federal está indisponível.
  void ativarModoManual(String cnpj) {
    cnpjAtual = cnpj;
    razaoSocialAtual = '';
    municipioAtual = '';
    codigoMunicipioAtual = '';
    erroCnpj = null;
    erroCnpjApiDown = false;
    notifyListeners();
  }

  void setRazaoSocial(String v) {
    razaoSocialAtual = v.trim();
    notifyListeners();
  }

  void setMunicipio(String v) {
    municipioAtual = v.trim();
    notifyListeners();
  }

  void setRegime(RegimeTributario regime) {
    regimeAtual = regime;
    notifyListeners();
  }

  void setInscricaoMunicipal(String inscricao) {
    inscricaoMunicipalAtual = inscricao;
    notifyListeners();
  }

  /// Define o método de assinatura para o CNPJ atual.
  /// O getter [statusCertificadoAtual] já reflete a transição (gov.br → ativo,
  /// certificadoA1 → pendente enquanto não há `CertificadoSuccess`).
  void setMetodoAssinatura(MetodoAssinatura metodo) {
    metodoAssinaturaAtual = metodo;
    notifyListeners();
  }

  /// Injeta o [CertificadoProvider] após a construção. Idempotente — chamada
  /// com a mesma instância é no-op. Substituir a instância remove o listener
  /// antigo. Mantém o acoplamento opcional para que testes possam construir o
  /// provider sem o domínio de certificado.
  void attachCertificado(CertificadoProvider cert) {
    if (identical(_cert, cert)) return;
    _cert?.removeListener(_onCertChanged);
    _cert = cert;
    cert.addListener(_onCertChanged);
  }

  /// Propaga mudanças do [CertificadoProvider] para os consumers do
  /// [OnboardingProvider], permitindo que UIs que leem [statusCertificadoAtual]
  /// rebuildem sem depender de um segundo `Consumer<CertificadoProvider>`.
  void _onCertChanged() => notifyListeners();

  @override
  void dispose() {
    _cert?.removeListener(_onCertChanged);
    super.dispose();
  }

  /// Dispara o fetch do status do certificado para o CNPJ corrente em onboarding.
  /// No-op se [_cert] não foi anexado, se [cnpjAtual] está vazio ou se o backend
  /// ainda não retornou o `cnpjProprioId` associado.
  Future<void> carregarStatusCertificadoStep2b() async {
    final cert = _cert;
    if (cert == null) return;
    if (cnpjAtual.isEmpty) return;
    final cnpjId = cnpjProprioIdsPorCnpj[cnpjAtual];
    if (cnpjId == null) return;
    await cert.carregar(cnpjId);
  }

  /// Gate de avanço do step 2b (Assinatura Digital).
  ///
  /// - `govBr` (ou qualquer método != A1): libera sempre — não exige upload.
  /// - `certificadoA1`: libera somente quando o backend confirma certificado
  ///   ativo via [CertificadoSuccess].
  bool get podeAvancarStep2b {
    if (metodoAssinaturaAtual != MetodoAssinatura.certificadoA1) return true;
    return _cert?.state is CertificadoSuccess;
  }

  // -------------------------------------------------------
  // Step 3 — Tomadores do CNPJ atual (onboarding)
  // -------------------------------------------------------
  Future<bool> adicionarTomador(
    String cnpj, {
    double? valorPadrao,
    String? emailFinanceiro,
    bool retemIss = false,
    double aliquotaIss = 0.0,
    bool retemIrrf = false,
    double aliquotaIrrf = 1.5,
  }) async {
    final numero = cnpj.replaceAll(RegExp(r'\D'), '');

    try {
      final dados = await api.buscarCnpj(numero);
      tomadoresAtual.add(
        Tomador(
          cnpj: cnpj,
          razaoSocial: dados.razaoSocial,
          municipio: dados.municipio,
          uf: dados.uf,
          valorPadrao: valorPadrao,
          emailFinanceiro: emailFinanceiro,
          codigoIbge: dados.codigoIbge,
          retemIss: retemIss,
          aliquotaIss: retemIss ? aliquotaIss : 0.0,
          retemIrrf: retemIrrf,
          aliquotaIrrf: retemIrrf ? aliquotaIrrf : 1.5,
        ),
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  void marcarTomadoresIniciado() => _persistirStep(5);

  void removerTomador(int index) {
    tomadoresAtual.removeAt(index);
    notifyListeners();
  }

  // -------------------------------------------------------
  // Step 4 — Confirmar CNPJ atual (onboarding)
  // -------------------------------------------------------
  Future<void> confirmarCnpjAtual() async {
    // CNPJ já foi salvo no Step 2 — apenas persiste tomadores novos
    if (cnpjAtual.isEmpty) return;
    final cnpjProprioId = cnpjProprioIdsPorCnpj[cnpjAtual];
    if (cnpjProprioId == null) return;

    if (tomadoresAtual.isNotEmpty) {
      salvandoTomadores = true;
      notifyListeners();
      try {
        final cadastrados = _tomadoresCadastradosPorCnpj.putIfAbsent(
          cnpjAtual,
          () => <String>{},
        );
        for (int i = 0; i < tomadoresAtual.length; i++) {
          final tomador = tomadoresAtual[i];
          if (!cadastrados.contains(tomador.cnpj)) {
            final novoId = await api.cadastrarTomador(cnpjProprioId, tomador);
            if (novoId.isNotEmpty) {
              tomadoresAtual[i] = Tomador(
                id: novoId,
                cnpj: tomador.cnpj,
                razaoSocial: tomador.razaoSocial,
                municipio: tomador.municipio,
                uf: tomador.uf,
                valorPadrao: tomador.valorPadrao,
                emailFinanceiro: tomador.emailFinanceiro,
                codigoIbge: tomador.codigoIbge,
                inscricaoMunicipal: tomador.inscricaoMunicipal,
                retemIss: tomador.retemIss,
                aliquotaIss: tomador.aliquotaIss,
                retemIrrf: tomador.retemIrrf,
                aliquotaIrrf: tomador.aliquotaIrrf,
              );
            }
            cadastrados.add(tomador.cnpj);
          }
        }
      } finally {
        salvandoTomadores = false;
        notifyListeners();
      }
    }

    final cnpj = CnpjComTomadores(
      cnpj: cnpjAtual,
      razaoSocial: razaoSocialAtual,
      municipio: municipioAtual,
      codigoMunicipio: codigoMunicipioAtual,
      tomadores: List.from(tomadoresAtual),
      inscricaoMunicipal: inscricaoMunicipalAtual,
      regime: regimeAtual,
      metodoAssinatura: metodoAssinaturaAtual,
      statusCertificado: statusCertificadoAtual,
    );
    // Upsert: remove entrada existente (pode vir do restore) e substitui
    // com a versão atualizada que inclui os tomadores recém-adicionados.
    cnpjsFinalizados.removeWhere((c) => c.cnpj == cnpjAtual);
    cnpjsFinalizados.add(cnpj);
    notifyListeners();
    _persistirStep(6); // avançou para step 4 (Confirmação)
  }

  void iniciarNovoCnpj() {
    cnpjAtual = '';
    razaoSocialAtual = '';
    municipioAtual = '';
    codigoMunicipioAtual = '';
    inscricaoMunicipalAtual = '';
    nomeFantasiaAtual = null;
    situacaoAtual = null;
    porteAtual = null;
    aberturaAtual = null;
    tomadoresAtual = [];
    erroCnpj = null;
    regimeAtual = RegimeTributario.simplesNacional;
    metodoAssinaturaAtual = MetodoAssinatura.certificadoA1;
    notifyListeners();
  }

  // -------------------------------------------------------
  // Finalizar onboarding
  // -------------------------------------------------------
  Future<void> finalizar() async {
    erroFinalizar = null;
    notifyListeners();

    try {
      await api.finalizarOnboarding(medicoIdSalvo!);

      medico = Medico(
        id: medicoIdSalvo!,
        nome: nome,
        cpf: cpf,
        crm: crm,
        ufCrm: ufCrm,
        especialidade: especialidade,
        email: email,
        telefone: telefone,
        cnpjs: List.from(cnpjsFinalizados),
      );

      onboardingCompletoFlag = true;
      notifyListeners();
    } catch (e) {
      erroFinalizar = e.toString();
      notifyListeners();
    }
  }

  // -------------------------------------------------------
  // Persistência interna
  // -------------------------------------------------------
  Future<void> _persistir() async {
    if (medico == null) return;
    notifyListeners();
  }

  // -------------------------------------------------------
  // Carregar médico salvo
  // -------------------------------------------------------
  Future<void> carregarMedico() async {
    await _limparIdentidadePrimariaLocal();
  }

  bool onboardingCompleto() {
    return medico != null;
  }

  // -------------------------------------------------------
  // Reset de sessão (Criar conta — limpa memória sem tocar no SharedPreferences)
  // -------------------------------------------------------
  void resetarSessao() {
    api.limparSessaoEmMemoria();
    stepAtual = 0;
    medicoIdSalvo = null;
    cnpjAtual = '';
    razaoSocialAtual = '';
    municipioAtual = '';
    ufAtual = '';
    inscricaoMunicipalAtual = '';
    nomeFantasiaAtual = null;
    situacaoAtual = null;
    porteAtual = null;
    aberturaAtual = null;
    nome = '';
    cpf = '';
    crm = '';
    ufCrm = '';
    especialidade = null;
    email = '';
    telefone = '';
    tomadoresAtual = [];
    cnpjsFinalizados = [];
    cnpjProprioIdsPorCnpj = {};
    _tomadoresCadastradosPorCnpj.clear();
    medico = null;
    erroFinalizar = null;
    salvandoMedico = false;
    salvandoCnpj = false;
    salvandoTomadores = false;
    onboardingCompletoFlag = false;
    perfilAtuacao = PerfilAtuacao.medicoClinico;
    regimeAtual = RegimeTributario.simplesNacional;
    metodoAssinaturaAtual = MetodoAssinatura.certificadoA1;
    cpfDigitsSalvo = null;
    _limparDadosSeguros();
    notifyListeners();
  }

  /// Remove os dados sensíveis do secure storage (fire-and-forget).
  void _limparDadosSeguros() {
    _secureStorage.delete(key: _kCpfHashKey);
    _secureStorage.delete(key: _kCpfDigitsKey);
    _secureStorage.delete(key: _kCpfKey);
    _secureStorage.delete(key: _kMedicoKey);
    _secureStorage.delete(key: _kMedicoIdKey);
    _secureStorage.delete(key: _kRefreshTokenKey);
    _secureStorage.delete(key: _kLegacyRefreshTokenKey);
    _secureStorage.delete(key: _kLegacyGoTrueEmailKey);
  }

  Future<void> _limparIdentidadePrimariaLocal() async {
    await _secureStorage.delete(key: _kCpfHashKey);
    await _secureStorage.delete(key: _kCpfDigitsKey);
    await _secureStorage.delete(key: _kCpfKey);
    await _secureStorage.delete(key: _kMedicoKey);
    await _secureStorage.delete(key: _kMedicoIdKey);
    await _secureStorage.delete(key: _kLegacyGoTrueEmailKey);
  }

  // -------------------------------------------------------
  // Reset (DevTools)
  // -------------------------------------------------------
  Future<void> resetar() async {
    api.limparSessaoEmMemoria();
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _kMedicoKey);
    await _secureStorage.delete(key: _kCpfHashKey);
    await _secureStorage.delete(key: _kCpfDigitsKey);
    await _secureStorage.delete(key: _kMedicoIdKey);
    await _secureStorage.delete(key: _kCpfKey);
    await _secureStorage.delete(key: _kRefreshTokenKey);
    await _secureStorage.delete(key: _kLegacyRefreshTokenKey);
    await _secureStorage.delete(key: _kLegacyGoTrueEmailKey);
    await prefs.remove('stepPendente');
    await prefs.remove('especialidades_cache');
    await prefs.remove('especialidades_cache_ts');
    nome = '';
    cpf = '';
    crm = '';
    ufCrm = '';
    especialidade = null;
    email = '';
    telefone = '';
    cnpjAtual = '';
    razaoSocialAtual = '';
    municipioAtual = '';
    tomadoresAtual = [];
    cnpjsFinalizados = [];
    regimeAtual = RegimeTributario.simplesNacional;
    metodoAssinaturaAtual = MetodoAssinatura.certificadoA1;
    medico = null;
    erroFinalizar = null;
    medicoIdSalvo = null;
    cpfDigitsSalvo = null;
    cnpjProprioIdsPorCnpj = {};
    salvandoMedico = false;
    salvandoCnpj = false;
    salvandoTomadores = false;
    perfilAtuacao = PerfilAtuacao.medicoClinico;
    notifyListeners();
  }
}
