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
enum StatusCertificado {
  /// Nenhuma credencial configurada ainda
  pendente,

  /// Credencial configurada e válida
  ativo,

  /// Certificado A1 vencido ou token gov.br expirado
  expirado,
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
    }
  }

  String get toJson {
    switch (this) {
      case StatusCertificado.pendente:
        return 'pendente';
      case StatusCertificado.ativo:
        return 'ativo';
      case StatusCertificado.expirado:
        return 'expirado';
    }
  }

  static StatusCertificado fromJson(String? value) {
    switch (value) {
      case 'ativo':
        return StatusCertificado.ativo;
      case 'expirado':
        return StatusCertificado.expirado;
      default:
        return StatusCertificado.pendente;
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
  });

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
      };

  factory Tomador.fromJson(Map<String, dynamic> json) => Tomador(
        id: json['id'] ?? '',
        cnpj: json['cnpj'] ?? '',
        razaoSocial: json['razaoSocial'] ?? '',
        municipio: json['municipio'] ?? '',
        uf: json['uf'] ?? '',
        valorPadrao: (json['valorPadrao'] ?? 0.0).toDouble(),
        emailFinanceiro: json['emailFinanceiro'],
        codigoIbge: json['codigoIbge'] ?? '',
        inscricaoMunicipal: json['inscricaoMunicipal'] ?? '',
        retemIss: json['retemIss'] ?? false,
        aliquotaIss: (json['aliquotaIss'] ?? 0.0).toDouble(),
        retemIrrf: json['retemIrrf'] ?? false,
      );
}

// ─── CnpjComTomadores ──────────────────────────────────────────────────────

class CnpjComTomadores {
  final String cnpj;
  final String razaoSocial;
  final String municipio;
  final String uf;
  final String inscricaoMunicipal;
  final List<Tomador> tomadores;
  final RegimeTributario regime;

  /// Como o médico assina as NFS-e deste CNPJ
  final MetodoAssinatura metodoAssinatura;

  /// Status da credencial de assinatura
  final StatusCertificado statusCertificado;

  CnpjComTomadores({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.tomadores,
    this.uf = '',
    this.inscricaoMunicipal = '',
    this.regime = RegimeTributario.simplesNacional,
    this.metodoAssinatura = MetodoAssinatura.certificadoA1,
    this.statusCertificado = StatusCertificado.pendente,
  });

  Map<String, dynamic> toJson() => {
        'cnpj': cnpj,
        'razaoSocial': razaoSocial,
        'municipio': municipio,
        'uf': uf,
        'inscricaoMunicipal': inscricaoMunicipal,
        'tomadores': tomadores.map((t) => t.toJson()).toList(),
        'regime': regime.toJson,
        'metodoAssinatura': metodoAssinatura.toJson,
        'statusCertificado': statusCertificado.toJson,
      };

  factory CnpjComTomadores.fromJson(Map<String, dynamic> json) =>
      CnpjComTomadores(
        cnpj: json['cnpj'] ?? '',
        razaoSocial: json['razaoSocial'] ?? '',
        municipio: json['municipio'] ?? '',
        uf: json['uf'] ?? '',
        inscricaoMunicipal: json['inscricaoMunicipal'] ?? '',
        tomadores: (json['tomadores'] as List<dynamic>? ?? [])
            .map((t) => Tomador.fromJson(t))
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
      cnpjs: (json['cnpjs'] as List<dynamic>? ?? [])
          .map((c) => CnpjComTomadores.fromJson(c))
          .toList(),
      endereco: json['endereco'] != null
          ? Endereco.fromJson(json['endereco'])
          : null,
    );
  }
}