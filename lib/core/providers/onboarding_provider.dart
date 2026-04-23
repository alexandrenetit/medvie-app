// lib/core/providers/onboarding_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medico.dart';
import '../models/especialidade.dart';
import '../models/perfil_atuacao.dart';
import '../services/medvie_api_service.dart';

class OnboardingProvider extends ChangeNotifier {
  // --- Serviço de API ---
  final MedvieApiService api;

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
  String ufAtual = '';
  String inscricaoMunicipalAtual = '';
  String? nomeFantasiaAtual;
  String? situacaoAtual;
  String? porteAtual;
  String? aberturaAtual;
  bool buscandoCnpj = false;
  String? erroCnpj;
  RegimeTributario regimeAtual = RegimeTributario.simplesNacional;

  /// Método de assinatura escolhido para o CNPJ atual
  MetodoAssinatura metodoAssinaturaAtual = MetodoAssinatura.certificadoA1;

  /// Status da credencial do CNPJ atual
  /// No protótipo: vira [ativo] após simulação de upload/conexão
  StatusCertificado statusCertificadoAtual = StatusCertificado.pendente;

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

  // --- CPF digits salvo em SharedPreferences (presença indica usuário existente) ---
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

  OnboardingProvider({required this.api}) {
    _restaurarSessao();
  }

  static String _computeCpfHash(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    return sha256.convert(utf8.encode(digits)).toString();
  }

  /// Boot: apenas detecta se já existe usuário registrado (sem chamadas à API).
  /// O login e a restauração de dados são feitos via [loginERestaurar].
  Future<void> _restaurarSessao() async {
    restaurando = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    cpfDigitsSalvo = prefs.getString('cpfDigits');
    restaurando = false;
    notifyListeners();
  }

  /// Chamado pela AuthScreen após o médico informar CPF + senha.
  /// Faz login no GoTrue e restaura os dados do onboarding via API.
  /// Lança exceção em caso de credenciais inválidas.
  Future<void> loginERestaurar(String cpf, String senha) async {
    await api.login(cpf, senha);

    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('cpfHash');
    final cpfHash = storedHash ?? _computeCpfHash(cpf);
    if (storedHash == null) {
      await prefs.setString('cpfHash', cpfHash);
      await prefs.setString('cpfDigits', cpf.replaceAll(RegExp(r'\D'), ''));
    }

    // Carrega cnpjsFinalizados locais para recuperar campos não retornados pelo backend
    final cnpjsJson = prefs.getString('cnpjsFinalizados');
    final cnpjsLocais = <String, CnpjComTomadores>{};
    if (cnpjsJson != null) {
      try {
        final lista = (jsonDecode(cnpjsJson) as List)
            .map((j) => CnpjComTomadores.fromJson(j))
            .toList();
        for (final c in lista) {
          cnpjsLocais[c.cnpj] = c;
        }
      } catch (_) {}
    }

    try {
      final status = await api.getOnboardingStatusByCpfHash(cpfHash);
      medicoIdSalvo = status.medico?.id;
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
        cpf = prefs.getString('cpf') ?? cpf;

        // FIX 1: resolve especialidade nome (24h cache)
        final especialidades = await api.listarEspecialidades();
        especialidade = especialidades.firstWhere(
          (e) => e.id == m.especialidadeId,
          orElse: () => Especialidade(id: m.especialidadeId, nome: ''),
        );
      }
      cnpjProprioIdsPorCnpj = {
        for (final c in status.cnpjs) c.cnpj: c.id
      };

      // FIX 2: resolve city name for each CNPJ (falls back to IBGE code on error)
      final listaFinalizada = <CnpjComTomadores>[];
      for (final c in status.cnpjs) {
        String nomeMunicipio = c.codigoMunicipio;
        try {
          final dadosCnpj = await api.buscarCnpj(c.cnpj);
          nomeMunicipio = dadosCnpj.municipio;
        } catch (_) {}

        // Backend não retorna inscricaoMunicipal — recupera do cache local
        final inscricao = c.inscricaoMunicipal.isNotEmpty
            ? c.inscricaoMunicipal
            : (cnpjsLocais[c.cnpj]?.inscricaoMunicipal ?? '');
        listaFinalizada.add(CnpjComTomadores(
          cnpj: c.cnpj,
          razaoSocial: c.razaoSocial,
          municipio: nomeMunicipio,
          tomadores: c.tomadores.map((t) => Tomador(
            cnpj: t.cnpj,
            razaoSocial: t.razaoSocial,
            municipio: t.codigoMunicipioPrestacao,
            uf: '',
            valorPadrao: t.valorPadrao ?? 0.0,
            emailFinanceiro: t.emailFinanceiro,
            codigoIbge: t.codigoMunicipioPrestacao,
          )).toList(),
          inscricaoMunicipal: inscricao,
          regime: RegimeTributario.values.firstWhere(
            (r) => r.name.toLowerCase() == c.regimeTributario.toLowerCase(),
            orElse: () => RegimeTributario.simplesNacional,
          ),
          metodoAssinatura: MetodoAssinatura.certificadoA1,
          statusCertificado: StatusCertificado.pendente,
        ));
      }
      cnpjsFinalizados = listaFinalizada;

      // FIX 3: restore tomadoresAtual so agenda/syncview can read them
      tomadoresAtual = cnpjsFinalizados
          .expand((c) => c.tomadores)
          .toList();

      // FIX 4: sempre restaura cnpjAtual quando há CNPJs cadastrados.
      // A restrição anterior (stepAtual 3-5) fazia cnpjAtual ficar vazio
      // ao voltar para o passo 4 com stepAtual == 6 (Confirmação).
      if (cnpjsFinalizados.isNotEmpty) {
        final ultimo = cnpjsFinalizados.last;
        cnpjAtual               = ultimo.cnpj;
        razaoSocialAtual        = ultimo.razaoSocial;
        municipioAtual          = ultimo.municipio;
        inscricaoMunicipalAtual = ultimo.inscricaoMunicipal;
        _tomadoresCadastradosPorCnpj[ultimo.cnpj] =
            ultimo.tomadores.map((t) => t.cnpj).toSet();
        // tomadoresAtual restrito ao CNPJ atual somente durante o step 3 (Tomadores)
        if (stepAtual >= 3 && stepAtual <= 5) {
          tomadoresAtual = ultimo.tomadores.toList();
        }
      }
    } catch (e) {
      debugPrint('[OnboardingProvider] erro ignorado: $e');
    }
    if (stepAtual > 0 && medicoIdSalvo != null) {
      final stepPendente = prefs.getInt('stepPendente') ?? 0;
      if (stepPendente > stepAtual) {
        try {
          await api.atualizarOnboardingStep(medicoIdSalvo!, stepPendente);
          stepAtual = stepPendente;
        } catch (_) {}
        await prefs.remove('stepPendente');
      }
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

  Future<void> _persistirStepComRetry(int step, {required int tentativa}) async {
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
        nome     = m.fullName;
        crm      = m.crm;
        ufCrm    = m.ufCrm;
        email    = m.email;
        telefone = m.phone ?? '';
        perfilAtuacao = m.perfilAtuacao;
        final prefs = await SharedPreferences.getInstance();
        cpf = prefs.getString('cpf') ?? cpf;
      }
      if (status.cnpjs.isNotEmpty) {
        cnpjProprioIdsPorCnpj = {
          for (final c in status.cnpjs) c.cnpj: c.id
        };
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[OnboardingProvider] erro ignorado: $e');
    }
  }

  // -------------------------------------------------------
  // Aliases de compatibilidade
  // -------------------------------------------------------
  Medico? get medicoSalvo => medico;
  List<Tomador> get tomadores => tomadoresAtual;
  bool get carregandoTomador => false;
  String? get erroComador => null;
  bool get carregandoCnpjProprio => buscandoCnpj;
  String get razaoSocialPropria => razaoSocialAtual;
  String? get erroCnpjProprio => erroCnpj;
  Future<bool> buscarCnpjProprio(String cnpj) => buscarCnpj(cnpj);

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

    await api.atualizarMedico(
      medicoIdSalvo!,
      nome,
      email,
      telefone,
      esp.id,
    );
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

      await api.registrar(cpf, senha);
      await api.login(cpf, senha);

      // especialidadeId 29 (Outra) como default — step 1c atualizará via PATCH
      final id = await api.cadastrarMedico(medicoTemp, especialidade?.id ?? 29);
      medicoIdSalvo = id;

      final cpfDigits = cpf.replaceAll(RegExp(r'\D'), '');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cpfHash', _computeCpfHash(cpf));
      await prefs.setString('cpfDigits', cpfDigits);
      await prefs.setString('medicoId', medicoIdSalvo!);
      await prefs.setString('cpf', cpf.replaceAll(RegExp(r'\D'), ''));

      notifyListeners();
      _persistirStep(1); // avançou para step 1b
    } catch (e) {
      if (e.toString().contains('CpfDuplicado')) {
        // CPF duplicado: carregar dados do médico existente
        try {
          final resultado = await api.getMedicoByCpf(cpf);
          medicoIdSalvo = resultado.medico.id;
          cnpjProprioIdsPorCnpj = Map.from(resultado.cnpjIds);

          // Restaurar CNPJs já cadastrados no provider
          if (resultado.medico.cnpjs.isNotEmpty) {
            for (final cnpj in resultado.medico.cnpjs) {
              cnpjsFinalizados.add(cnpj);
            }
            medico = resultado.medico;
          }

          final cpfDigits = cpf.replaceAll(RegExp(r'\D'), '');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cpfHash', _computeCpfHash(cpf));
          await prefs.setString('cpfDigits', cpfDigits);
          await prefs.setString('medicoId', medicoIdSalvo!);
          await prefs.setString('cpf', cpf.replaceAll(RegExp(r'\D'), ''));

          notifyListeners();
          return; // Retorna silenciosamente
        } catch (erroCarregamento) {
          throw Exception('Erro ao carregar dados do médico: $erroCarregamento');
        }
      }
      rethrow;
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
        final tomadoresCadastrados = _tomadoresCadastradosPorCnpj.putIfAbsent(cnpj.cnpj, () => <String>{});
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

    final jaExiste = medico!.cnpjs
        .any((c) => c.cnpj.replaceAll(RegExp(r'\D'), '') == numero);
    if (jaExiste) return 'Este CNPJ já está cadastrado.';

    try {
      final dados = await api.buscarCnpj(numero);
      final novo = CnpjComTomadores(
        cnpj: cnpj,
        razaoSocial: dados.razaoSocial,
        municipio: dados.municipio,
        tomadores: [],
        inscricaoMunicipal: '',
        regime: RegimeTributario.simplesNacional,
        metodoAssinatura: MetodoAssinatura.certificadoA1,
        statusCertificado: StatusCertificado.pendente,
      );
      final cnpjsAtualizados =
          List<CnpjComTomadores>.from(medico!.cnpjs)..add(novo);
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
    final cnpjsAtualizados =
        medico!.cnpjs.where((c) => c.cnpj != cnpj).toList();
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

  Future<void> atualizarRegimeCnpj(
      String cnpj, RegimeTributario regime) async {
    if (medico == null) return;
    final cnpjsAtualizados = medico!.cnpjs.map((c) {
      if (c.cnpj == cnpj) {
        return CnpjComTomadores(
          cnpj: c.cnpj,
          razaoSocial: c.razaoSocial,
          municipio: c.municipio,
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
    double valorPadrao = 0.0,
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
        emailFinanceiro: emailFinanceiro?.isEmpty == true ? null : emailFinanceiro,
      );
      final cnpjsAtualizados = medico!.cnpjs.map((c) {
        if (c.cnpj == cnpjProprio) {
          return CnpjComTomadores(
            cnpj: c.cnpj,
            razaoSocial: c.razaoSocial,
            municipio: c.municipio,
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
      String cnpjProprio, String tomadorCnpj, double valor) async {
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
      return e.toString().replaceAll('Exception: ', '');
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
      ufAtual = dados.uf;
      nomeFantasiaAtual = dados.nomeFantasia;
      situacaoAtual = dados.situacao;
      porteAtual = dados.porte;
      aberturaAtual = dados.abertura;
      buscandoCnpj = false;
      notifyListeners();
      return true;
    } catch (e) {
      erroCnpj = 'CNPJ não encontrado na Receita Federal';
      buscandoCnpj = false;
      notifyListeners();
      return false;
    }
  }

  void setRegime(RegimeTributario regime) {
    regimeAtual = regime;
    notifyListeners();
  }

  void setInscricaoMunicipal(String inscricao) {
    inscricaoMunicipalAtual = inscricao;
    notifyListeners();
  }

  /// Define o método de assinatura para o CNPJ atual
  void setMetodoAssinatura(MetodoAssinatura metodo) {
    metodoAssinaturaAtual = metodo;
    // Ao trocar o método, a credencial volta a pendente
    statusCertificadoAtual = StatusCertificado.pendente;
    notifyListeners();
  }

  /// Simula o upload do certificado A1 ou a conexão gov.br
  /// No produto real: faria o upload para o middleware / OAuth gov.br
  Future<void> simularConfiguracaoCredencial() async {
    // Simula latência de upload/conexão
    await Future.delayed(const Duration(milliseconds: 1200));
    statusCertificadoAtual = StatusCertificado.ativo;
    notifyListeners();
    _persistirStep(5); // avançou para step 3 (Tomadores)
  }


  // -------------------------------------------------------
  // Step 3 — Tomadores do CNPJ atual (onboarding)
  // -------------------------------------------------------
  Future<bool> adicionarTomador(
    String cnpj, {
    double valorPadrao = 0.0,
    String? emailFinanceiro,
    bool retemIss = false,
    double aliquotaIss = 0.0,
    bool retemIrrf = false,
  }) async {
    final numero = cnpj.replaceAll(RegExp(r'\D'), '');

    try {
      final dados = await api.buscarCnpj(numero);
      tomadoresAtual.add(Tomador(
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
      ));
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
        final cadastrados = _tomadoresCadastradosPorCnpj.putIfAbsent(cnpjAtual, () => <String>{});
        for (final tomador in tomadoresAtual) {
          if (!cadastrados.contains(tomador.cnpj)) {
            await api.cadastrarTomador(cnpjProprioId, tomador);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cnpjsFinalizados',
      jsonEncode(cnpjsFinalizados.map((c) => c.toJson()).toList()));
    notifyListeners();
    _persistirStep(6); // avançou para step 4 (Confirmação)
  }

  void iniciarNovoCnpj() {
    cnpjAtual = '';
    razaoSocialAtual = '';
    municipioAtual = '';
    inscricaoMunicipalAtual = '';
    nomeFantasiaAtual = null;
    situacaoAtual = null;
    porteAtual = null;
    aberturaAtual = null;
    tomadoresAtual = [];
    erroCnpj = null;
    regimeAtual = RegimeTributario.simplesNacional;
    metodoAssinaturaAtual = MetodoAssinatura.certificadoA1;
    statusCertificadoAtual = StatusCertificado.pendente;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('medico', jsonEncode(medico!.toJson()));
    notifyListeners();
  }

  // -------------------------------------------------------
  // Carregar médico salvo
  // -------------------------------------------------------
  Future<void> carregarMedico() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('medico');
    if (json != null) {
      medico = Medico.fromJson(jsonDecode(json));
      notifyListeners();
    }
    medicoIdSalvo ??= prefs.getString('medicoId');
  }

  bool onboardingCompleto() {
    return medico != null;
  }

  // -------------------------------------------------------
  // Reset de sessão (Criar conta — limpa memória sem tocar no SharedPreferences)
  // -------------------------------------------------------
  void resetarSessao() {
    stepAtual               = 0;
    medicoIdSalvo           = null;
    cnpjAtual               = '';
    razaoSocialAtual        = '';
    municipioAtual          = '';
    ufAtual                 = '';
    inscricaoMunicipalAtual = '';
    nomeFantasiaAtual       = null;
    situacaoAtual           = null;
    porteAtual              = null;
    aberturaAtual           = null;
    nome                    = '';
    cpf                     = '';
    crm                     = '';
    ufCrm                   = '';
    especialidade           = null;
    email                   = '';
    telefone                = '';
    tomadoresAtual          = [];
    cnpjsFinalizados        = [];
    cnpjProprioIdsPorCnpj   = {};
    _tomadoresCadastradosPorCnpj.clear();
    medico                  = null;
    erroFinalizar           = null;
    salvandoMedico          = false;
    salvandoCnpj            = false;
    salvandoTomadores       = false;
    onboardingCompletoFlag  = false;
    perfilAtuacao           = PerfilAtuacao.medicoClinico;
    regimeAtual             = RegimeTributario.simplesNacional;
    metodoAssinaturaAtual   = MetodoAssinatura.certificadoA1;
    statusCertificadoAtual  = StatusCertificado.pendente;
    notifyListeners();
  }

  // -------------------------------------------------------
  // Reset (DevTools)
  // -------------------------------------------------------
  Future<void> resetar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('medico');
    await prefs.remove('cpfHash');
    await prefs.remove('cpfDigits');
    await prefs.remove('medicoId');
    await prefs.remove('onboarding_completo');
    await prefs.remove('cpf');
    await prefs.remove('stepPendente');
    await prefs.remove('cnpjsFinalizados');
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
    statusCertificadoAtual = StatusCertificado.pendente;
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