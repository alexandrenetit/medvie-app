// test/models/medico_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/medico.dart';

// ── Helpers de fixture ────────────────────────────────────────────────────────

Map<String, dynamic> _tomadorJson({
  String id = 'tom-001',
  String cnpj = '00.000.000/0001-00',
  String razaoSocial = 'Hospital Teste',
  bool retemIss = true,
  double aliquotaIss = 2.0,
}) =>
    {
      'id': id,
      'cnpj': cnpj,
      'razaoSocial': razaoSocial,
      'municipio': 'São Paulo',
      'uf': 'SP',
      'valorPadrao': 3000.0,
      'emailFinanceiro': 'fin@hospital.com',
      'codigoIbge': '3550308',
      'inscricaoMunicipal': '123456',
      'retemIss': retemIss,
      'aliquotaIss': aliquotaIss,
      'retemIrrf': false,
      'aliquotaIrrf': 1.5,
    };

Map<String, dynamic> _cnpjJson({
  String regime = 'simplesNacional',
  String metodo = 'certificadoA1',
  String statusCert = 'ativo',
  List<Map<String, dynamic>>? tomadores,
}) =>
    {
      'id': 'cnpj-001',
      'cnpj': '12.345.678/0001-99',
      'razaoSocial': 'João Silva ME',
      'municipio': 'São Paulo',
      'uf': 'SP',
      'inscricaoMunicipal': '9876543',
      'tomadores': tomadores ?? [_tomadorJson()],
      'regime': regime,
      'metodoAssinatura': metodo,
      'statusCertificado': statusCert,
    };

Map<String, dynamic> _enderecoJson() => {
      'cep': '01310-000',
      'logradouro': 'Av. Paulista',
      'numero': '1000',
      'complemento': 'Sala 10',
      'bairro': 'Bela Vista',
      'cidade': 'São Paulo',
      'uf': 'SP',
    };

Map<String, dynamic> _medicoJson({
  String id = 'medico-001',
  String chaveId = 'id',
  String nomeKey = 'nome',
  String nome = 'Dr. João Silva',
  int? especialidadeId = 1,
  String? especialidadeNome = 'Anestesiologia',
  List<Map<String, dynamic>>? cnpjs,
  Map<String, dynamic>? endereco,
}) =>
    {
      chaveId: id,
      nomeKey: nome,
      'cpf': '123.456.789-00',
      'crm': '54321',
      'ufCrm': 'SP',
      'especialidadeId': especialidadeId,
      'especialidadeNome': especialidadeNome,
      'telefone': '(11) 99999-0001',
      'email': 'joao@medico.com',
      'cnpjs': cnpjs ?? [],
      'endereco': endereco,
    };

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── RegimeTributario ─────────────────────────────────────────────────────

  group('RegimeTributario.fromJson', () {
    test('reconhece todos os valores', () {
      expect(RegimeTributarioExt.fromJson('simplesNacional'), RegimeTributario.simplesNacional);
      expect(RegimeTributarioExt.fromJson('lucroPresumido'), RegimeTributario.lucroPresumido);
      expect(RegimeTributarioExt.fromJson('lucroReal'), RegimeTributario.lucroReal);
    });

    test('nulo retorna simplesNacional', () {
      expect(RegimeTributarioExt.fromJson(null), RegimeTributario.simplesNacional);
    });

    test('valor desconhecido retorna simplesNacional', () {
      expect(RegimeTributarioExt.fromJson('invalido'), RegimeTributario.simplesNacional);
    });
  });

  group('RegimeTributario extensions', () {
    test('toJson retorna string correta para cada regime', () {
      expect(RegimeTributario.simplesNacional.toJson, 'simplesNacional');
      expect(RegimeTributario.lucroPresumido.toJson, 'lucroPresumido');
      expect(RegimeTributario.lucroReal.toJson, 'lucroReal');
    });

    test('label retorna texto legível', () {
      expect(RegimeTributario.simplesNacional.label, 'Simples Nacional');
      expect(RegimeTributario.lucroPresumido.label, 'Lucro Presumido');
      expect(RegimeTributario.lucroReal.label, 'Lucro Real');
    });

    test('descricao retorna texto não-vazio para cada regime', () {
      for (final r in RegimeTributario.values) {
        expect(r.descricao, isNotEmpty);
      }
    });
  });

  // ── MetodoAssinatura ─────────────────────────────────────────────────────

  group('MetodoAssinatura.fromJson', () {
    test('reconhece govBr', () {
      expect(MetodoAssinaturaExt.fromJson('govBr'), MetodoAssinatura.govBr);
    });

    test('reconhece certificadoA1', () {
      expect(MetodoAssinaturaExt.fromJson('certificadoA1'), MetodoAssinatura.certificadoA1);
    });

    test('nulo retorna certificadoA1', () {
      expect(MetodoAssinaturaExt.fromJson(null), MetodoAssinatura.certificadoA1);
    });

    test('desconhecido retorna certificadoA1', () {
      expect(MetodoAssinaturaExt.fromJson('outro'), MetodoAssinatura.certificadoA1);
    });
  });

  group('MetodoAssinatura extensions', () {
    test('toJson retorna string correta', () {
      expect(MetodoAssinatura.govBr.toJson, 'govBr');
      expect(MetodoAssinatura.certificadoA1.toJson, 'certificadoA1');
    });

    test('label retorna texto não-vazio', () {
      expect(MetodoAssinatura.govBr.label, isNotEmpty);
      expect(MetodoAssinatura.certificadoA1.label, isNotEmpty);
    });

    test('descricao retorna texto não-vazio', () {
      expect(MetodoAssinatura.govBr.descricao, isNotEmpty);
      expect(MetodoAssinatura.certificadoA1.descricao, isNotEmpty);
    });
  });

  // ── StatusCertificado ────────────────────────────────────────────────────

  group('StatusCertificado.fromJson', () {
    test('reconhece todos os valores', () {
      expect(StatusCertificadoExt.fromJson('ativo'), StatusCertificado.ativo);
      expect(StatusCertificadoExt.fromJson('expirado'), StatusCertificado.expirado);
      expect(StatusCertificadoExt.fromJson('pendente'), StatusCertificado.pendente);
    });

    test('nulo retorna pendente', () {
      expect(StatusCertificadoExt.fromJson(null), StatusCertificado.pendente);
    });

    test('desconhecido retorna pendente', () {
      expect(StatusCertificadoExt.fromJson('outro'), StatusCertificado.pendente);
    });
  });

  group('StatusCertificado extensions', () {
    test('toJson retorna string correta', () {
      expect(StatusCertificado.ativo.toJson, 'ativo');
      expect(StatusCertificado.expirado.toJson, 'expirado');
      expect(StatusCertificado.pendente.toJson, 'pendente');
    });

    test('label retorna texto legível', () {
      expect(StatusCertificado.ativo.label, 'Ativo');
      expect(StatusCertificado.expirado.label, 'Expirado');
      expect(StatusCertificado.pendente.label, 'Pendente');
    });
  });

  // ── Endereco ─────────────────────────────────────────────────────────────

  group('Endereco.fromJson', () {
    test('parseia todos os campos', () {
      final e = Endereco.fromJson(_enderecoJson());

      expect(e.cep, '01310-000');
      expect(e.logradouro, 'Av. Paulista');
      expect(e.numero, '1000');
      expect(e.complemento, 'Sala 10');
      expect(e.bairro, 'Bela Vista');
      expect(e.cidade, 'São Paulo');
      expect(e.uf, 'SP');
    });

    test('campos ausentes usam string vazia como default', () {
      final e = Endereco.fromJson({});
      expect(e.cep, '');
      expect(e.logradouro, '');
      expect(e.cidade, '');
    });
  });

  group('Endereco.preenchido', () {
    test('true quando cep e logradouro preenchidos', () {
      expect(Endereco.fromJson(_enderecoJson()).preenchido, true);
    });

    test('false quando cep vazio', () {
      final e = Endereco(cep: '', logradouro: 'Av. Paulista');
      expect(e.preenchido, false);
    });

    test('false quando logradouro vazio', () {
      final e = Endereco(cep: '01310-000', logradouro: '');
      expect(e.preenchido, false);
    });
  });

  group('Endereco.toJson round-trip', () {
    test('fromJson → toJson → fromJson preserva todos os campos', () {
      final original = Endereco.fromJson(_enderecoJson());
      final copy = Endereco.fromJson(original.toJson());

      expect(copy.cep, original.cep);
      expect(copy.logradouro, original.logradouro);
      expect(copy.numero, original.numero);
      expect(copy.complemento, original.complemento);
      expect(copy.bairro, original.bairro);
      expect(copy.cidade, original.cidade);
      expect(copy.uf, original.uf);
    });
  });

  // ── Tomador ──────────────────────────────────────────────────────────────

  group('Tomador.fromJson', () {
    test('parseia todos os campos', () {
      final t = Tomador.fromJson(_tomadorJson());

      expect(t.id, 'tom-001');
      expect(t.cnpj, '00.000.000/0001-00');
      expect(t.razaoSocial, 'Hospital Teste');
      expect(t.municipio, 'São Paulo');
      expect(t.uf, 'SP');
      expect(t.valorPadrao, 3000.0);
      expect(t.emailFinanceiro, 'fin@hospital.com');
      expect(t.codigoIbge, '3550308');
      expect(t.inscricaoMunicipal, '123456');
      expect(t.retemIss, true);
      expect(t.aliquotaIss, 2.0);
      expect(t.retemIrrf, false);
      expect(t.aliquotaIrrf, 1.5);
    });

    test('campos numéricos ausentes usam defaults', () {
      final t = Tomador.fromJson({
        'cnpj': '00.000.000/0001-00',
        'razaoSocial': 'X',
        'municipio': 'Y',
        'uf': 'SP',
      });
      expect(t.valorPadrao, 0.0);
      expect(t.aliquotaIss, 0.0);
      expect(t.aliquotaIrrf, 1.5);
      expect(t.retemIss, false);
      expect(t.retemIrrf, false);
    });
  });

  group('Tomador.toJson round-trip', () {
    test('preserva campos numéricos e booleanos', () {
      final original = Tomador.fromJson(_tomadorJson());
      final copy = Tomador.fromJson(original.toJson());

      expect(copy.valorPadrao, original.valorPadrao);
      expect(copy.aliquotaIss, original.aliquotaIss);
      expect(copy.aliquotaIrrf, original.aliquotaIrrf);
      expect(copy.retemIss, original.retemIss);
      expect(copy.retemIrrf, original.retemIrrf);
    });
  });

  // ── CnpjComTomadores ─────────────────────────────────────────────────────

  group('CnpjComTomadores.fromJson', () {
    test('parseia cnpj, razaoSocial e campos de configuração', () {
      final c = CnpjComTomadores.fromJson(_cnpjJson());

      expect(c.id, 'cnpj-001');
      expect(c.cnpj, '12.345.678/0001-99');
      expect(c.razaoSocial, 'João Silva ME');
      expect(c.municipio, 'São Paulo');
      expect(c.uf, 'SP');
      expect(c.inscricaoMunicipal, '9876543');
    });

    test('parseia regime simplesNacional', () {
      final c = CnpjComTomadores.fromJson(_cnpjJson(regime: 'simplesNacional'));
      expect(c.regime, RegimeTributario.simplesNacional);
    });

    test('parseia regime lucroPresumido', () {
      final c = CnpjComTomadores.fromJson(_cnpjJson(regime: 'lucroPresumido'));
      expect(c.regime, RegimeTributario.lucroPresumido);
    });

    test('parseia metodoAssinatura govBr', () {
      final c = CnpjComTomadores.fromJson(_cnpjJson(metodo: 'govBr'));
      expect(c.metodoAssinatura, MetodoAssinatura.govBr);
    });

    test('parseia statusCertificado ativo', () {
      final c = CnpjComTomadores.fromJson(_cnpjJson(statusCert: 'ativo'));
      expect(c.statusCertificado, StatusCertificado.ativo);
    });

    test('parseia lista de tomadores', () {
      final c = CnpjComTomadores.fromJson(_cnpjJson(
        tomadores: [_tomadorJson(), _tomadorJson(id: 'tom-002', cnpj: '11.111.111/0001-11')],
      ));
      expect(c.tomadores.length, 2);
      expect(c.tomadores.first.id, 'tom-001');
    });

    test('tomadores null no JSON resulta em lista vazia', () {
      final json = _cnpjJson();
      json['tomadores'] = null;
      final c = CnpjComTomadores.fromJson(json);
      expect(c.tomadores, isEmpty);
    });
  });

  group('CnpjComTomadores.toJson round-trip', () {
    test('preserva regime, metodo e statusCertificado', () {
      final original = CnpjComTomadores.fromJson(_cnpjJson(
        regime: 'lucroPresumido',
        metodo: 'govBr',
        statusCert: 'expirado',
      ));
      final copy = CnpjComTomadores.fromJson(original.toJson());

      expect(copy.regime, RegimeTributario.lucroPresumido);
      expect(copy.metodoAssinatura, MetodoAssinatura.govBr);
      expect(copy.statusCertificado, StatusCertificado.expirado);
    });

    test('preserva lista de tomadores', () {
      final original = CnpjComTomadores.fromJson(_cnpjJson(
        tomadores: [_tomadorJson(), _tomadorJson(id: 'tom-002', cnpj: '99.999.999/0001-99')],
      ));
      final copy = CnpjComTomadores.fromJson(original.toJson());
      expect(copy.tomadores.length, 2);
    });
  });

  // ── Medico ───────────────────────────────────────────────────────────────

  group('Medico.fromJson', () {
    test('parseia todos os campos com cnpjs e endereço', () {
      final json = _medicoJson(cnpjs: [_cnpjJson()], endereco: _enderecoJson());
      final m = Medico.fromJson(json);

      expect(m.id, 'medico-001');
      expect(m.nome, 'Dr. João Silva');
      expect(m.cpf, '123.456.789-00');
      expect(m.crm, '54321');
      expect(m.ufCrm, 'SP');
      expect(m.telefone, '(11) 99999-0001');
      expect(m.email, 'joao@medico.com');
      expect(m.especialidade?.id, 1);
      expect(m.especialidade?.nome, 'Anestesiologia');
      expect(m.cnpjs.length, 1);
      expect(m.endereco?.cidade, 'São Paulo');
    });

    test('sem especialidadeId — especialidade é null', () {
      final json = _medicoJson(especialidadeId: null, especialidadeNome: null);
      expect(Medico.fromJson(json).especialidade, isNull);
    });

    test('sem endereço — endereco é null', () {
      final json = _medicoJson();
      expect(Medico.fromJson(json).endereco, isNull);
    });

    test('aceita "fullName" como alternativa a "nome"', () {
      final json = {
        'id': 'x',
        'fullName': 'Dr. Alternativo',
        'cpf': '',
        'crm': '',
        'ufCrm': '',
        'cnpjs': <dynamic>[],
      };
      expect(Medico.fromJson(json).nome, 'Dr. Alternativo');
    });

    test('aceita "Id" maiúsculo como alternativa a "id"', () {
      final json = {
        'Id': 'id-maiusculo',
        'nome': 'Dr. X',
        'cpf': '',
        'crm': '',
        'ufCrm': '',
        'cnpjs': <dynamic>[],
      };
      expect(Medico.fromJson(json).id, 'id-maiusculo');
    });

    test('aceita "phone" como alternativa a "telefone"', () {
      final json = {
        'id': 'x',
        'nome': 'Dr. X',
        'cpf': '',
        'crm': '',
        'ufCrm': '',
        'phone': '(21) 98888-0000',
        'cnpjs': <dynamic>[],
      };
      expect(Medico.fromJson(json).telefone, '(21) 98888-0000');
    });

    test('cnpjs null no JSON resulta em lista vazia', () {
      final json = {
        'id': 'x',
        'nome': 'Dr. X',
        'cpf': '',
        'crm': '',
        'ufCrm': '',
        'cnpjs': null,
      };
      expect(Medico.fromJson(json).cnpjs, isEmpty);
    });
  });

  group('Medico.toJson', () {
    test('produz mapa com chaves esperadas', () {
      final m = Medico.fromJson(_medicoJson(cnpjs: [_cnpjJson()], endereco: _enderecoJson()));
      final out = m.toJson();

      expect(out.containsKey('id'), true);
      expect(out.containsKey('nome'), true);
      expect(out.containsKey('cpf'), true);
      expect(out.containsKey('crm'), true);
      expect(out.containsKey('cnpjs'), true);
      expect(out.containsKey('endereco'), true);
    });

    test('especialidadeId serializado corretamente', () {
      final m = Medico.fromJson(_medicoJson());
      expect(m.toJson()['especialidadeId'], 1);
    });
  });

  group('Medico getters', () {
    test('todosTomadores agrega tomadores de todos os cnpjs', () {
      final m = Medico.fromJson(_medicoJson(cnpjs: [
        _cnpjJson(tomadores: [_tomadorJson(), _tomadorJson(id: 'tom-002')]),
        _cnpjJson(tomadores: [_tomadorJson(id: 'tom-003')]),
      ]));
      expect(m.todosTomadores.length, 3);
    });

    test('todosTomadores vazio quando sem cnpjs', () {
      expect(Medico.fromJson(_medicoJson()).todosTomadores, isEmpty);
    });

    test('tomadores é alias de todosTomadores', () {
      final m = Medico.fromJson(_medicoJson(cnpjs: [_cnpjJson()]));
      expect(m.tomadores.length, m.todosTomadores.length);
    });
  });
}
