// lib/core/models/medico.dart

import 'especialidade.dart';

// ─── RegimeTributario ──────────────────────────────────────────────────────

enum RegimeTributario {
  simplesNacional,
  lucroPresumido,
  lucroReal,
}

extension RegimeTributarioExt on RegimeTributario {
  String get label {
    switch (this) {
      case RegimeTributario.simplesNacional:
        return 'Simples Nacional';
      case RegimeTributario.lucroPresumido:
        return 'Lucro Presumido';
      case RegimeTributario.lucroReal:
        return 'Lucro Real';
    }
  }

  String get descricao {
    switch (this) {
      case RegimeTributario.simplesNacional:
        return 'Faturamento até R\$ 4,8M/ano — DAS unificado';
      case RegimeTributario.lucroPresumido:
        return 'Faturamento até R\$ 78M/ano — mais comum para médicos';
      case RegimeTributario.lucroReal:
        return 'Obrigatório acima de R\$ 78M/ano';
    }
  }

  String get toJson {
    switch (this) {
      case RegimeTributario.simplesNacional:
        return 'simplesNacional';
      case RegimeTributario.lucroPresumido:
        return 'lucroPresumido';
      case RegimeTributario.lucroReal:
        return 'lucroReal';
    }
  }

  static RegimeTributario fromJson(String? value) {
    switch (value) {
      case 'lucroPresumido':
        return RegimeTributario.lucroPresumido;
      case 'lucroReal':
        return RegimeTributario.lucroReal;
      default:
        return RegimeTributario.simplesNacional;
    }
  }
}

// ─── MetodoAssinatura ──────────────────────────────────────────────────────

/// Como o médico assina as NFS-e deste CNPJ.
enum MetodoAssinatura {
  /// Certificado e-CNPJ A1 (.pfx) — 100% automático via middleware
  certificadoA1,

  /// Login gov.br (OAuth ICP-Brasil nível prata/ouro) — médico autoriza 1x
  govBr,
}

extension MetodoAssinaturaExt on MetodoAssinatura {
  String get label {
    switch (this) {
      case MetodoAssinatura.certificadoA1:
        return 'e-CNPJ (certificado A1)';
      case MetodoAssinatura.govBr:
        return 'gov.br';
    }
  }

  String get descricao {
    switch (this) {
      case MetodoAssinatura.certificadoA1:
        return 'Arquivo .pfx cadastrado uma única vez. Emissão 100% automática.';
      case MetodoAssinatura.govBr:
        return 'Login com CPF + senha + biometria. Sem necessidade de certificado.';
    }
  }

  String get toJson {
    switch (this) {
      case MetodoAssinatura.certificadoA1:
        return 'certificadoA1';
      case MetodoAssinatura.govBr:
        return 'govBr';
    }
  }

  static MetodoAssinatura fromJson(String? value) {
    switch (value) {
      case 'govBr':
        return MetodoAssinatura.govBr;
      default:
        return MetodoAssinatura.certificadoA1;
    }
  }
}

// ─── StatusCertificado ─────────────────────────────────────────────────────

/// Status da credencial de assinatura deste CNPJ.
///
/// Mantém compatibilidade com o backend Medvie (fragment OpenAPI
/// `certificado.openapi.yaml`, commit-pinned em `specs/cd-upload/contracts/api-pin.json`).
enum StatusCertificado {
  /// Nenhuma credencial configurada ainda
  pendente,

  /// Credencial configurada e válida
  ativo,

  /// Certificado A1 vencido ou token gov.br expirado
  expirado,

  /// Certificado anterior trocado por um novo (histórico)
  substituido,

  /// Certificado removido pelo usuário — emissão bloqueada até novo upload
  removido,

  /// Estado fora do contrato conhecido — exibir como warning, nunca silenciar
  desconhecido,
}

extension StatusCertificadoExt on StatusCertificado {
  String get label {
    switch (this) {
      case StatusCertificado.pendente:
        return 'Pendente';
      case StatusCertificado.ativo:
        return 'Ativo';
      case StatusCertificado.expirado:
        return 'Expirado';
      case StatusCertificado.substituido:
        return 'Substituído';
      case StatusCertificado.removido:
        return 'Removido';
      case StatusCertificado.desconhecido:
        return 'Desconhecido';
    }
  }

  /// Serialização alinhada ao contrato OpenAPI (`certificado.openapi.yaml`):
  /// enum oficial em PascalCase — `[Pendente, Ativo, Expirado, Substituido, Removido]`.
  String get toJson {
    switch (this) {
      case StatusCertificado.pendente:
        return 'Pendente';
      case StatusCertificado.ativo:
        return 'Ativo';
      case StatusCertificado.expirado:
        return 'Expirado';
      case StatusCertificado.substituido:
        return 'Substituido';
      case StatusCertificado.removido:
        return 'Removido';
      case StatusCertificado.desconhecido:
        return 'Desconhecido';
    }
  }

  /// Desserializa o status do backend. Aceita tanto PascalCase (forma canônica
  /// do contrato OpenAPI) quanto lowercase (forma legada usada em fixtures
  /// antigas). Valor fora do contrato vai para [StatusCertificado.desconhecido]
  /// — estado explícito, sem fallback silencioso.
  static StatusCertificado fromJson(String? value) {
    if (value == null) return StatusCertificado.desconhecido;
    switch (value.toLowerCase()) {
      case 'pendente':
        return StatusCertificado.pendente;
      case 'ativo':
        return StatusCertificado.ativo;
      case 'expirado':
        return StatusCertificado.expirado;
      case 'substituido':
        return StatusCertificado.substituido;
      case 'removido':
        return StatusCertificado.removido;
      default:
        return StatusCertificado.desconhecido;
    }
  }
}

// ─── Endereco ──────────────────────────────────────────────────────────────

class Endereco {
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;

  Endereco({
    this.cep = '',
    this.logradouro = '',
    this.numero = '',
    this.complemento = '',
    this.bairro = '',
    this.cidade = '',
    this.uf = '',
  });

  bool get preenchido => cep.isNotEmpty && logradouro.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'cep': cep,
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
        'bairro': bairro,
        'cidade': cidade,
        'uf': uf,
      };

  factory Endereco.fromJson(Map<String, dynamic> json) => Endereco(
        cep: json['cep'] ?? '',
        logradouro: json['logradouro'] ?? '',
        numero: json['numero'] ?? '',
        complemento: json['complemento'] ?? '',
        bairro: json['bairro'] ?? '',
        cidade: json['cidade'] ?? '',
        uf: json['uf'] ?? '',
      );
}

// ─── TipoTomador ───────────────────────────────────────────────────────────

/// Natureza fiscal do tomador. `CPF` é o Paciente (PF); `CNPJ` é a
/// Empresa/Convênio/Hospital recorrente. Default `cnpj` preserva
/// compatibilidade com tomadores já cadastrados que não trazem o campo.
enum TipoTomador { cpf, cnpj }

extension TipoTomadorExt on TipoTomador {
  bool get isPf => this == TipoTomador.cpf;

  /// Rótulo de UI. PF é apresentado como "Paciente".
  String get label => isPf ? 'Paciente' : 'Empresa/Convênio';

  /// Serialização alinhada ao contrato backend (`tipo`: `CPF`|`CNPJ`).
  String get toJson => isPf ? 'CPF' : 'CNPJ';

  static TipoTomador fromJson(String? value) =>
      (value?.toUpperCase() == 'CPF') ? TipoTomador.cpf : TipoTomador.cnpj;
}

// ─── EnderecoFiscalTomador ──────────────────────────────────────────────────

/// Endereço fiscal nacional completo exigido para emitir NFS-e com tomador PF
/// (FR-003). `codigoMunicipioIbge` é obrigatório para liberar a emissão.
class EnderecoFiscalTomador {
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String municipio;
  final String uf;
  final String codigoMunicipioIbge;

  const EnderecoFiscalTomador({
    this.cep = '',
    this.logradouro = '',
    this.numero = '',
    this.complemento = '',
    this.bairro = '',
    this.municipio = '',
    this.uf = '',
    this.codigoMunicipioIbge = '',
  });

  /// Completo o suficiente para emitir (FR-005). `complemento` é opcional;
  /// os demais campos são obrigatórios.
  bool get completo =>
      cep.isNotEmpty &&
      logradouro.isNotEmpty &&
      numero.isNotEmpty &&
      bairro.isNotEmpty &&
      municipio.isNotEmpty &&
      uf.isNotEmpty &&
      codigoMunicipioIbge.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'cep': cep,
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
        'bairro': bairro,
        'municipio': municipio,
        'uf': uf,
        'codigoMunicipioIbge': codigoMunicipioIbge,
      };

  /// Tolera as duas formas de chave de município/IBGE: o contrato de
  /// atendimento/lookup usa `municipio`/`codigoMunicipioIbge`; o autofill de
  /// CEP (`GET /api/v1/cep`) usa `municipio`/`codigoIbge`.
  factory EnderecoFiscalTomador.fromJson(Map<String, dynamic> json) =>
      EnderecoFiscalTomador(
        cep: json['cep'] ?? '',
        logradouro: json['logradouro'] ?? '',
        numero: json['numero'] ?? '',
        complemento: json['complemento'] ?? '',
        bairro: json['bairro'] ?? '',
        municipio: json['municipio'] ?? json['cidade'] ?? '',
        uf: json['uf'] ?? '',
        codigoMunicipioIbge:
            json['codigoMunicipioIbge'] ?? json['codigoIbge'] ?? '',
      );

  EnderecoFiscalTomador copyWith({
    String? cep,
    String? logradouro,
    String? numero,
    String? complemento,
    String? bairro,
    String? municipio,
    String? uf,
    String? codigoMunicipioIbge,
  }) =>
      EnderecoFiscalTomador(
        cep: cep ?? this.cep,
        logradouro: logradouro ?? this.logradouro,
        numero: numero ?? this.numero,
        complemento: complemento ?? this.complemento,
        bairro: bairro ?? this.bairro,
        municipio: municipio ?? this.municipio,
        uf: uf ?? this.uf,
        codigoMunicipioIbge: codigoMunicipioIbge ?? this.codigoMunicipioIbge,
      );
}

// ─── Tomador ───────────────────────────────────────────────────────────────

class Tomador {
  final String id;
  final String cnpj;
  final String razaoSocial;
  final String municipio;
  final String uf;
  final double valorPadrao;
  final String? emailFinanceiro;
  final String codigoIbge;
  final String inscricaoMunicipal;
  final bool retemIss;
  final double aliquotaIss;
  final bool retemIrrf;
  final double aliquotaIrrf;

  // ─── Campos PF (feature 017) ───────────────────────────────────────────
  /// Natureza do tomador. Default `cnpj` para tomadores legados sem o campo.
  final TipoTomador tipo;

  /// Documento mascarado (`***.***.***-09`). CPF bruto NUNCA persiste no app
  /// (FR-002): só a forma mascarada trafega para a UI/modelo.
  final String documentoMascarado;

  /// Endereço fiscal nacional do tomador PF. `null` para CNPJ recorrente.
  final EnderecoFiscalTomador? enderecoFiscal;

  /// Status fiscal informado pelo backend (`Completo`/`Incompleto`).
  final String enderecoFiscalStatus;

  Tomador({
    this.id = '',
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    this.valorPadrao = 0.0,
    this.emailFinanceiro,
    this.codigoIbge = '',
    this.inscricaoMunicipal = '',
    this.retemIss = false,
    this.aliquotaIss = 0.0,
    this.retemIrrf = false,
    this.aliquotaIrrf = 1.5,
    this.tipo = TipoTomador.cnpj,
    this.documentoMascarado = '',
    this.enderecoFiscal,
    this.enderecoFiscalStatus = '',
  });

  /// Endereço fiscal completo o suficiente para emitir NFS-e PF (FR-005).
  /// Confia no status do backend quando presente; senão deriva do endereço.
  bool get enderecoFiscalCompleto =>
      enderecoFiscalStatus.toLowerCase() == 'completo' ||
      (enderecoFiscal?.completo ?? false);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cnpj': cnpj,
        'razaoSocial': razaoSocial,
        'municipio': municipio,
        'uf': uf,
        'valorPadrao': valorPadrao,
        'emailFinanceiro': emailFinanceiro,
        'codigoIbge': codigoIbge,
        'inscricaoMunicipal': inscricaoMunicipal,
        'retemIss': retemIss,
        'aliquotaIss': aliquotaIss,
        'retemIrrf': retemIrrf,
        'aliquotaIrrf': aliquotaIrrf,
        'tipo': tipo.toJson,
        'documentoMascarado': documentoMascarado,
        'enderecoFiscal': enderecoFiscal?.toJson(),
        'enderecoFiscalStatus': enderecoFiscalStatus,
      };

  factory Tomador.fromJson(Map<String, dynamic> json) => Tomador(
        id: json['id'] ?? '',
        cnpj: json['cnpj'] ?? '',
        // PF traz `nome`; CNPJ recorrente traz `razaoSocial`.
        razaoSocial: json['razaoSocial'] ?? json['nome'] ?? '',
        municipio: json['municipio'] ?? '',
        uf: json['uf'] ?? '',
        valorPadrao: (json['valorPadrao'] ?? 0.0).toDouble(),
        emailFinanceiro: json['emailFinanceiro'],
        codigoIbge: json['codigoIbge'] ?? '',
        inscricaoMunicipal: json['inscricaoMunicipal'] ?? '',
        retemIss: json['retemIss'] ?? false,
        aliquotaIss: (json['aliquotaIss'] ?? 0.0).toDouble(),
        retemIrrf: json['retemIrrf'] ?? false,
        aliquotaIrrf: (json['aliquotaIrrf'] ?? 1.5).toDouble(),
        tipo: TipoTomadorExt.fromJson(json['tipo']),
        documentoMascarado: json['documentoMascarado'] ?? '',
        // Aceita `enderecoFiscal` (atendimento) ou `endereco` (lookup).
        enderecoFiscal: json['enderecoFiscal'] != null
            ? EnderecoFiscalTomador.fromJson(
                Map<String, dynamic>.from(json['enderecoFiscal'] as Map))
            : (json['endereco'] != null
                ? EnderecoFiscalTomador.fromJson(
                    Map<String, dynamic>.from(json['endereco'] as Map))
                : null),
        enderecoFiscalStatus: json['enderecoFiscalStatus'] ?? '',
      );
}

// ─── CnpjComTomadores ──────────────────────────────────────────────────────

class CnpjComTomadores {
  final String id;
  final String cnpj;
  final String razaoSocial;
  final String municipio;
  final String uf;
  final String codigoMunicipio;
  final String inscricaoMunicipal;
  final List<Tomador> tomadores;
  final RegimeTributario regime;

  /// Como o médico assina as NFS-e deste CNPJ
  final MetodoAssinatura metodoAssinatura;

  /// Status da credencial de assinatura
  final StatusCertificado statusCertificado;

  CnpjComTomadores({
    this.id = '',
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.tomadores,
    this.uf = '',
    this.codigoMunicipio = '',
    this.inscricaoMunicipal = '',
    this.regime = RegimeTributario.simplesNacional,
    this.metodoAssinatura = MetodoAssinatura.certificadoA1,
    this.statusCertificado = StatusCertificado.pendente,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cnpj': cnpj,
        'razaoSocial': razaoSocial,
        'municipio': municipio,
        'uf': uf,
        'codigoMunicipio': codigoMunicipio,
        'inscricaoMunicipal': inscricaoMunicipal,
        'tomadores': tomadores.map((t) => t.toJson()).toList(),
        'regime': regime.toJson,
        'metodoAssinatura': metodoAssinatura.toJson,
        'statusCertificado': statusCertificado.toJson,
      };

  factory CnpjComTomadores.fromJson(Map<String, dynamic> json) =>
      CnpjComTomadores(
        // Aceita 'id' ou 'Id' (backend pode serializar PascalCase em alguns payloads).
        id: json['id'] ?? json['Id'] ?? '',
        cnpj: json['cnpj'] ?? '',
        razaoSocial: json['razaoSocial'] ?? '',
        municipio: json['municipio'] ?? '',
        uf: json['uf'] ?? '',
        codigoMunicipio: json['codigoMunicipio'] ?? json['codigoIbge'] ?? '',
        inscricaoMunicipal: json['inscricaoMunicipal'] ?? '',
        tomadores: (json['tomadores'] as List<Object?>? ?? const <Object?>[])
            .map((t) => Tomador.fromJson(Map<String, dynamic>.from(t as Map)))
            .toList(),
        regime: RegimeTributarioExt.fromJson(json['regime']),
        metodoAssinatura:
            MetodoAssinaturaExt.fromJson(json['metodoAssinatura']),
        statusCertificado:
            StatusCertificadoExt.fromJson(json['statusCertificado']),
      );
}

// ─── Medico ────────────────────────────────────────────────────────────────

class Medico {
  final String id;
  final String nome;
  final String cpf;
  final String crm;
  final String ufCrm;
  final Especialidade? especialidade;
  final String telefone;
  final String email;
  final List<CnpjComTomadores> cnpjs;
  final Endereco? endereco;

  Medico({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.crm,
    required this.ufCrm,
    required this.especialidade,
    this.telefone = '',
    this.email = '',
    required this.cnpjs,
    this.endereco,
  });

  List<Tomador> get todosTomadores =>
      cnpjs.expand((c) => c.tomadores).toList();

  List<Tomador> get tomadores => todosTomadores;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cpf': cpf,
        'crm': crm,
        'ufCrm': ufCrm,
        'especialidadeId': especialidade?.id,
        'telefone': telefone,
        'email': email,
        'cnpjs': cnpjs.map((c) => c.toJson()).toList(),
        'endereco': endereco?.toJson(),
      };

  factory Medico.fromJson(Map<String, dynamic> json) {
    Especialidade? especialidade;
    final especialidadeId = json['especialidadeId'];
    final especialidadeNome = json['especialidadeNome'] ?? json['especialidade'];

    if (especialidadeId != null) {
      especialidade = Especialidade(
        id: especialidadeId as int,
        nome: especialidadeNome as String? ?? '',
      );
    }

    return Medico(
      // Aceita ambos: 'id' ou 'Id' (do backend)
      id: json['id'] ?? json['Id'] ?? '',
      // Aceita ambos os padrões: 'nome' ou 'fullName'
      nome: json['nome'] ?? json['fullName'] ?? '',
      cpf: json['cpf'] ?? '',
      crm: json['crm'] ?? '',
      ufCrm: json['ufCrm'] ?? '',
      especialidade: especialidade,
      // Aceita ambos: 'telefone' ou 'phone'
      telefone: json['telefone'] ?? json['phone'] ?? '',
      email: json['email'] ?? '',
      cnpjs: (json['cnpjs'] as List<Object?>? ?? const <Object?>[])
          .map(
            (c) => CnpjComTomadores.fromJson(
              Map<String, dynamic>.from(c as Map),
            ),
          )
          .toList(),
      endereco: json['endereco'] != null
          ? Endereco.fromJson(json['endereco'])
          : null,
    );
  }
}
