import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medico.dart';
import '../models/especialidade.dart';
import '../models/perfil_atuacao.dart';

class MedvieApiService {
  late String baseUrl;
  late String _goTrueUrl;

  String? _accessToken;
  String? _refreshToken;

  static const _kRefreshTokenKey = 'gotrue_refresh_token';

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Carrega o refresh token persistido (chamado no boot do app).
  Future<void> carregarTokensPersistidos() async {
    final prefs = await SharedPreferences.getInstance();
    _refreshToken = prefs.getString(_kRefreshTokenKey);
  }

  /// Renova o access token usando o refresh token do GoTrue.
  /// Lança exceção se o refresh token estiver inválido/expirado.
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) throw Exception('Sessão expirada. Faça login novamente.');
    final response = await http.post(
      Uri.parse('$_goTrueUrl/token?grant_type=refresh_token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': _refreshToken}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken  = data['access_token']  as String?;
      _refreshToken = data['refresh_token'] as String?;
      final prefs = await SharedPreferences.getInstance();
      if (_refreshToken != null) {
        await prefs.setString(_kRefreshTokenKey, _refreshToken!);
      }
    } else {
      _accessToken  = null;
      _refreshToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRefreshTokenKey);
      throw Exception('Sessão expirada. Faça login novamente.');
    }
  }

  /// Executa [call], e em caso de 401 renova o token e retenta uma vez.
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    var response = await call();
    if (response.statusCode == 401) {
      await _refreshAccessToken();
      response = await call();
    }
    return response;
  }

  MedvieApiService() {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    baseUrl     = isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
    _goTrueUrl  = isAndroid ? 'http://10.0.2.2:9999' : 'http://localhost:9999';
  }

  /// Cria usuário no GoTrue com e-mail derivado do CPF
  Future<void> registrar(String cpf, String senha) async {
    final email = '${cpf.replaceAll(RegExp(r'\D'), '')}@medvie.local';
    final response = await http.post(
      Uri.parse('$_goTrueUrl/signup'),
      headers: _authHeaders,
      body: jsonEncode({'email': email, 'password': senha}),
    );
    // 200 = criado; 422 = já existe (ignorar silenciosamente no fluxo de boot)
    if (response.statusCode != 200 && response.statusCode != 422) {
      throw Exception('Erro ao registrar usuário: ${response.statusCode}');
    }
  }

  /// Autentica no GoTrue e armazena os tokens em memória
  Future<void> login(String cpf, String senha) async {
    final email = '${cpf.replaceAll(RegExp(r'\D'), '')}@medvie.local';
    final response = await http.post(
      Uri.parse('$_goTrueUrl/token?grant_type=password'),
      headers: _authHeaders,
      body: jsonEncode({'email': email, 'password': senha}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken  = data['access_token']  as String?;
      _refreshToken = data['refresh_token'] as String?;
      final prefs = await SharedPreferences.getInstance();
      if (_refreshToken != null) {
        await prefs.setString(_kRefreshTokenKey, _refreshToken!);
      }
    } else {
      throw Exception('CPF ou senha inválidos.');
    }
  }

  /// Cadastra um novo médico no backend
  /// Retorna: ID do médico criado
  Future<String> cadastrarMedico(Medico medico, int especialidadeId) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos');
    final body = jsonEncode({
      'cpf': medico.cpf,
      'fullName': medico.nome,
      'crm': medico.crm,
      'ufCrm': medico.ufCrm,
      'email': medico.email,
      'phone': medico.telefone,
      'especialidadeId': especialidadeId,
    });

    final response = await _send(
      () => http.post(url, headers: _authHeaders, body: body),
    );

    if (response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body);
        return data['medicoId'] ?? '';
      } catch (e) {
        throw Exception('Resposta inválida do servidor');
      }
    } else {
      throw Exception('[HTTP ${response.statusCode}] ${response.body}');
    }
  }

  /// Cadastra um CNPJ para um médico existente
  /// Retorna: ID do CNPJ próprio (cnpjProprioId)
  Future<String> cadastrarCnpj(
    String medicoId,
    CnpjComTomadores cnpj,
  ) async {
    final url = Uri.parse('$baseUrl/api/v1/cnpjs-proprios');

    // Mapear enum RegimeTributario → código numérico
    int regimeCode = 1; // default: SimplesNacional
    if (cnpj.regime == RegimeTributario.lucroPresumido) {
      regimeCode = 2;
    } else if (cnpj.regime == RegimeTributario.lucroReal) {
      regimeCode = 3;
    }

    final body = jsonEncode({
      'medicoId': medicoId,
      'cnpj': cnpj.cnpj,
      'razaoSocial': cnpj.razaoSocial,
      'inscricaoMunicipal': cnpj.inscricaoMunicipal,
      'municipio': cnpj.municipio,
      'uf': cnpj.uf,
      'regimeTributario': regimeCode,
    });

    final response = await _send(
      () => http.post(url, headers: _authHeaders, body: body),
    );

    if (response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body);
        return data['cnpjProprioId'] ?? '';
      } catch (e) {
        throw Exception('Resposta inválida do servidor');
      }
    } else {
      throw Exception(response.body);
    }
  }

  /// Cadastra um tomador para um CNPJ próprio
  /// Retorna: ID do tomador criado
  Future<String> cadastrarTomador(
    String cnpjProprioId,
    Tomador tomador,
  ) async {
    final url = Uri.parse('$baseUrl/api/v1/servicos/tomadores');

    final body = jsonEncode({
      'cnpjProprioId': cnpjProprioId,
      'cnpj': tomador.cnpj,
      'razaoSocial': tomador.razaoSocial,
      'emailFinanceiro': tomador.emailFinanceiro,
      'codigoMunicipioPrestacao': tomador.codigoIbge,
      'valorPadrao': tomador.valorPadrao,
      'retemIss': tomador.retemIss,
      'aliquotaIss': tomador.aliquotaIss,
      'retemIrrf': tomador.retemIrrf,
    });

    final response = await _send(
      () => http.post(url, headers: _authHeaders, body: body),
    );

    if (response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body);
        return data['tomadorId'] ?? '';
      } catch (e) {
        throw Exception('Resposta inválida do servidor');
      }
    } else {
      throw Exception(response.body);
    }
  }

  /// Busca um tomador pelo ID.
  /// GET /api/v1/servicos/tomadores/{tomadorId}
  Future<Tomador> getTomador(String tomadorId) async {
    final url = Uri.parse('$baseUrl/api/v1/servicos/tomadores/$tomadorId');
    final response = await _send(
      () => http.get(url, headers: _authHeaders),
    );
    if (response.statusCode == 200) {
      try {
        return Tomador.fromJson(jsonDecode(response.body));
      } catch (e) {
        throw Exception('Resposta inválida do servidor');
      }
    } else {
      throw Exception(response.body);
    }
  }

  /// Atualiza os dados editáveis de um tomador.
  /// PUT /api/v1/servicos/tomadores/{tomadorId}
  Future<void> atualizarTomador(
    String tomadorId,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl/api/v1/servicos/tomadores/$tomadorId');
    final response = await _send(
      () => http.put(url, headers: _authHeaders, body: jsonEncode(body)),
    );
    if (response.statusCode != 204) {
      throw Exception(response.body);
    }
  }

  /// Recupera os dados de um médico pelo ID
  /// Retorna: Objeto Medico com todos os CNPJs e tomadores
  Future<Medico> getMedico(String medicoId) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos/$medicoId');

    final response = await _send(() => http.get(url, headers: _authHeaders));

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        return Medico.fromJson(data);
      } catch (e) {
        throw Exception('Resposta inválida do servidor');
      }
    } else {
      throw Exception(response.body);
    }
  }

  /// Recupera os dados de um médico pelo CPF
  /// Retorna: Medico + Map de cnpjProprioIds (cnpj → id)
  Future<({Medico medico, Map<String, String> cnpjIds})> getMedicoByCpf(String cpf) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos/by-cpf/$cpf');
    final response = await _send(() => http.get(url, headers: _authHeaders));
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        final medico = Medico.fromJson(data);
        final cnpjIds = <String, String>{};
        final cnpjsRaw = data['cnpjs'] as List<dynamic>? ?? [];
        for (final c in cnpjsRaw) {
          final cnpj = c['cnpj'] as String? ?? '';
          final id = c['id'] as String? ?? '';
          if (cnpj.isNotEmpty && id.isNotEmpty) cnpjIds[cnpj] = id;
        }
        return (medico: medico, cnpjIds: cnpjIds);
      } catch (e) {
        throw Exception('Resposta inválida do servidor');
      }
    } else {
      throw Exception(response.body);
    }
  }

  /// Atualiza um médico existente
  /// Retorna: status code 204 (No Content)
  Future<void> atualizarMedico(
    String medicoId,
    String nome,
    String email,
    String telefone,
    int? especialidadeId, {
    PerfilAtuacao? perfilAtuacao,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos/$medicoId');
    final body = jsonEncode({
      'fullName': nome,
      'email': email,
      'phone': telefone,
      'especialidadeId': ?especialidadeId,
      if (perfilAtuacao != null) 'perfilAtuacao': perfilAtuacao.value,
    });

    final response = await _send(
      () => http.patch(url, headers: _authHeaders, body: body),
    );

    if (response.statusCode != 204) {
      throw Exception('[HTTP ${response.statusCode}] ${response.body}');
    }
  }

  /// Persiste o perfil de atuação selecionado no step 1b do onboarding.
  /// Retorna: status code 204 (No Content)
  Future<void> salvarStep1b(String medicoId, PerfilAtuacao perfil) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos/$medicoId/onboarding/step1b');
    final body = jsonEncode({'perfilAtuacao': perfil.value});
    debugPrint('[STEP1B] body enviado: $body');
    debugPrint('[STEP1B] medicoId: $medicoId');
    final response = await _send(
      () => http.patch(url, headers: _authHeaders, body: body),
    );
    if (response.statusCode != 204) {
      throw Exception('[HTTP ${response.statusCode}] ${response.body}');
    }
  }

  /// Lista todas as especialidades disponíveis
  /// Retorna: List<Especialidade> com cache local de 24h em SharedPreferences
  Future<List<Especialidade>> listarEspecialidades() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheDataKey = 'cache_especialidades_data';
    const cacheTimestampKey = 'cache_especialidades_ts';

    // Verificar se cache existe e ainda é válido (24h = 86400000 ms)
    final cachedJson = prefs.getString(cacheDataKey);
    final cachedTimestamp = prefs.getInt(cacheTimestampKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const cacheValidade = 24 * 60 * 60 * 1000; // 24 horas em ms

    if (cachedJson != null && (now - cachedTimestamp) < cacheValidade) {
      try {
        final cached = jsonDecode(cachedJson) as List<dynamic>;
        return cached
            .map((e) => Especialidade.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Cache inválido, ignorar e buscar novamente
      }
    }

    // Buscar da API
    final url = Uri.parse('$baseUrl/api/v1/especialidades');
    final response = await _send(() => http.get(url, headers: _authHeaders));

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as List<dynamic>;
        final especialidades = data
            .map((e) => Especialidade.fromJson(e as Map<String, dynamic>))
            .toList();

        // Salvar em cache
        await prefs.setString(cacheDataKey, jsonEncode(data));
        await prefs.setInt(cacheTimestampKey, now);

        return especialidades;
      } catch (e) {
        throw Exception('Resposta inválida do servidor');
      }
    } else {
      throw Exception(
          '[HTTP ${response.statusCode}] Erro ao listar especialidades');
    }
  }

  /// Recupera o status do onboarding de um médico
  /// Retorna: OnboardingStatusResponse com step, completo e dados do médico/CNPJs
  Future<OnboardingStatusResponse> getOnboardingStatus(String medicoId) async {
    final response = await _send(() => http.get(
      Uri.parse('$baseUrl/api/v1/medicos/$medicoId/onboarding-status'),
      headers: _authHeaders,
    ));
    if (response.statusCode == 200) {
      return OnboardingStatusResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception(jsonDecode(response.body)['description'] ?? 'Erro ao buscar status do onboarding');
  }

  Future<OnboardingStatusResponse> getOnboardingStatusByCpfHash(String cpfHash) async {
    final response = await _send(() => http.get(
      Uri.parse('$baseUrl/api/v1/medicos/status?cpfHash=$cpfHash'),
      headers: _authHeaders,
    ));
    if (response.statusCode == 200) {
      return OnboardingStatusResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception(
        jsonDecode(response.body)['description'] ?? 'Médico não encontrado pelo CPF hash');
  }

  Future<BuscarCepResponse> buscarCep(String cep) async {
    final numero = cep.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('$baseUrl/api/v1/cep/$numero');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      return BuscarCepResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('CEP não encontrado');
  }

  Future<BuscarCnpjResponse> buscarCnpj(String cnpj) async {
    final numero = cnpj.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('$baseUrl/api/v1/cnpj/$numero');
    final response = await http.get(url, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      return BuscarCnpjResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('CNPJ não encontrado na Receita Federal');
  }

  /// Persiste o step atual do onboarding no backend.
  /// PATCH /api/v1/medicos/{medicoId}/onboarding-step  body: { "step": N }
  Future<void> atualizarOnboardingStep(String medicoId, int step) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos/$medicoId/onboarding-step');
    final response = await _send(
      () => http.patch(url, headers: _authHeaders, body: jsonEncode({'step': step})),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao persistir step ($step): ${response.statusCode}');
    }
  }

  Future<void> finalizarOnboarding(String medicoId) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos/$medicoId/onboarding-finalizar');
    final response = await _send(() => http.post(url, headers: _authHeaders));
    if (response.statusCode != 204) {
      throw Exception('Erro ao finalizar onboarding: ${response.statusCode}');
    }
  }

  /// Executa GET autenticado e retorna o body como Map decodificado.
  /// Lança [Exception] para status != 200.
  Future<Map<String, dynamic>> getJson(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final response = await _send(() => http.get(url, headers: _authHeaders));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('[HTTP ${response.statusCode}] $path');
  }

  /// Busca a sugestão fiscal do médico (NBS, TipoServico, IssRetido).
  /// Chamado no modal de novo serviço para pré-preencher os campos fiscais.
  Future<SugestaoFiscalResponse> getSugestaoFiscal(String medicoId) async {
    final url = Uri.parse('$baseUrl/api/v1/medicos/$medicoId/sugestao-fiscal');
    final response = await _send(() => http.get(url, headers: _authHeaders));
    if (response.statusCode == 200) {
      return SugestaoFiscalResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('[HTTP ${response.statusCode}] Erro ao buscar sugestão fiscal');
  }

}

// ─── Resposta de Busca CEP ──────────────────────────────────────────────────

class BuscarCepResponse {
  final String logradouro;
  final String bairro;
  final String localidade;
  final String uf;

  BuscarCepResponse({
    required this.logradouro,
    required this.bairro,
    required this.localidade,
    required this.uf,
  });

  factory BuscarCepResponse.fromJson(Map<String, dynamic> json) =>
      BuscarCepResponse(
        logradouro: json['logradouro'] ?? '',
        bairro: json['bairro'] ?? '',
        localidade: json['localidade'] ?? '',
        uf: json['uf'] ?? '',
      );
}

// ─── Resposta de Busca CNPJ ─────────────────────────────────────────────────

class BuscarCnpjResponse {
  final String cnpj;
  final String razaoSocial;
  final String municipio;
  final String uf;
  final String codigoIbge;
  final String? nomeFantasia;
  final String? situacao;
  final String? porte;
  final String? abertura;

  BuscarCnpjResponse({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    required this.codigoIbge,
    this.nomeFantasia,
    this.situacao,
    this.porte,
    this.abertura,
  });

  factory BuscarCnpjResponse.fromJson(Map<String, dynamic> json) =>
      BuscarCnpjResponse(
        cnpj: json['cnpj'] ?? '',
        razaoSocial: json['razaoSocial'] ?? '',
        municipio: json['municipio'] ?? '',
        uf: json['uf'] ?? '',
        codigoIbge: json['codigoIbge'] ?? '',
        nomeFantasia: json['nomeFantasia'] as String?,
        situacao: json['situacao'] as String?,
        porte: json['porte'] as String?,
        abertura: json['abertura'] as String?,
      );
}

// ─── Resposta de Status Onboarding ──────────────────────────────────────────

class OnboardingStatusResponse {
  final int step;
  final bool completo;
  final MedicoResumoResponse? medico;
  final List<CnpjResumoResponse> cnpjs;

  OnboardingStatusResponse({
    required this.step,
    required this.completo,
    this.medico,
    required this.cnpjs,
  });

  factory OnboardingStatusResponse.fromJson(Map<String, dynamic> json) =>
      OnboardingStatusResponse(
        step: json['step'],
        completo: json['completo'],
        medico: json['medico'] != null
            ? MedicoResumoResponse.fromJson(json['medico'])
            : null,
        cnpjs: (json['cnpjs'] as List)
            .map((c) => CnpjResumoResponse.fromJson(c))
            .toList(),
      );
}

class MedicoResumoResponse {
  final String id;
  final String fullName;
  final String crm;
  final String ufCrm;
  final String email;
  final String? phone;
  final int especialidadeId;
  final PerfilAtuacao perfilAtuacao;

  MedicoResumoResponse({
    required this.id,
    required this.fullName,
    required this.crm,
    required this.ufCrm,
    required this.email,
    this.phone,
    required this.especialidadeId,
    required this.perfilAtuacao,
  });

  factory MedicoResumoResponse.fromJson(Map<String, dynamic> json) =>
      MedicoResumoResponse(
        id: json['id'],
        fullName: json['fullName'] ?? '',
        crm: json['crm'] ?? '',
        ufCrm: json['ufCrm'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'],
        especialidadeId: int.tryParse(json['especialidadeId'].toString()) ?? 0,
        perfilAtuacao: PerfilAtuacao.fromJson(json['perfilAtuacao']),
      );
}

class CnpjResumoResponse {
  final String id;
  final String cnpj;
  final String razaoSocial;
  final String codigoMunicipio;
  final String regimeTributario;
  final String inscricaoMunicipal;
  final List<TomadorResumoResponse> tomadores;

  CnpjResumoResponse({
    required this.id,
    required this.cnpj,
    required this.razaoSocial,
    required this.codigoMunicipio,
    required this.regimeTributario,
    this.inscricaoMunicipal = '',
    required this.tomadores,
  });

  factory CnpjResumoResponse.fromJson(Map<String, dynamic> json) =>
      CnpjResumoResponse(
        id: json['id'],
        cnpj: json['cnpj'],
        razaoSocial: json['razaoSocial'],
        codigoMunicipio: json['codigoMunicipio'],
        regimeTributario: json['regimeTributario'],
        inscricaoMunicipal: json['inscricaoMunicipal'] ?? '',
        tomadores: (json['tomadores'] as List)
            .map((t) => TomadorResumoResponse.fromJson(t))
            .toList(),
      );
}

class TomadorResumoResponse {
  final String id;
  final String cnpj;
  final String razaoSocial;
  final String codigoMunicipioPrestacao;
  final double? valorPadrao;
  final String? emailFinanceiro;

  TomadorResumoResponse({
    required this.id,
    required this.cnpj,
    required this.razaoSocial,
    required this.codigoMunicipioPrestacao,
    this.valorPadrao,
    this.emailFinanceiro,
  });

  factory TomadorResumoResponse.fromJson(Map<String, dynamic> json) =>
      TomadorResumoResponse(
        id: json['id'],
        cnpj: json['cnpj'],
        razaoSocial: json['razaoSocial'],
        codigoMunicipioPrestacao: json['codigoMunicipioPrestacao'],
        valorPadrao: (json['valorPadrao'] as num?)?.toDouble(),
        emailFinanceiro: json['emailFinanceiro'],
      );
}

// ─── Sugestão Fiscal ─────────────────────────────────────────────────────────

class SugestaoFiscalResponse {
  final String codigoNbs;
  /// Nome do enum backend: "PlantaoClinico", "AtoAnestesico", etc.
  final String tipoServicoDefault;
  final bool issRetidoDefault;
  final double aliquotaIssEstimada;

  SugestaoFiscalResponse({
    required this.codigoNbs,
    required this.tipoServicoDefault,
    required this.issRetidoDefault,
    required this.aliquotaIssEstimada,
  });

  factory SugestaoFiscalResponse.fromJson(Map<String, dynamic> json) =>
      SugestaoFiscalResponse(
        codigoNbs: json['codigoNbs'] as String? ?? '',
        tipoServicoDefault: json['tipoServicoDefault'] as String? ?? 'PlantaoClinico',
        issRetidoDefault: json['issRetidoDefault'] as bool? ?? false,
        aliquotaIssEstimada: (json['aliquotaIssEstimada'] as num?)?.toDouble() ?? 2.0,
      );
}
