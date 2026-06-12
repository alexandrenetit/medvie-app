// test/core/models/tomador_pf_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/medico.dart';

/// Resposta `tomador` de `POST /api/v1/atendimentos` (PF).
Map<String, dynamic> _tomadorPfAtendimento() => <String, dynamic>{
      'id': 'guid-tom-1',
      'tipo': 'CPF',
      'documentoMascarado': '***.***.***-09',
      'nome': 'Julia M. Ramos',
      'enderecoFiscalStatus': 'Completo',
    };

/// Resposta de `POST /api/v1/atendimentos/tomador/lookup` (paciente existe).
Map<String, dynamic> _tomadorPfLookup() => <String, dynamic>{
      'tomadorId': 'guid-tom-1',
      'tipo': 'CPF',
      'documentoMascarado': '***.***.***-09',
      'nome': 'Julia M. Ramos',
      'email': 'julia@example.com',
      'telefone': '11999990000',
      'enderecoFiscalStatus': 'Completo',
      'endereco': <String, dynamic>{
        'cep': '01311000',
        'logradouro': 'Avenida Paulista',
        'numero': '1000',
        'complemento': 'cj 101',
        'bairro': 'Bela Vista',
        'municipio': 'Sao Paulo',
        'uf': 'SP',
        'codigoMunicipioIbge': '3550308',
      },
    };

/// Tomador CNPJ legado — payload anterior à feature 017, sem campos PF.
Map<String, dynamic> _tomadorCnpjLegado() => <String, dynamic>{
      'id': 'guid-cnpj-1',
      'cnpj': '12.345.678/0001-90',
      'razaoSocial': 'Hospital Sao Lucas',
      'municipio': 'Sao Paulo',
      'uf': 'SP',
      'codigoIbge': '3550308',
    };

void main() {
  group('TipoTomador', () {
    test('serializa/desserializa CPF e CNPJ alinhado ao contrato', () {
      expect(TipoTomador.cpf.toJson, 'CPF');
      expect(TipoTomador.cnpj.toJson, 'CNPJ');
      expect(TipoTomadorExt.fromJson('CPF'), TipoTomador.cpf);
      expect(TipoTomadorExt.fromJson('cpf'), TipoTomador.cpf);
      expect(TipoTomadorExt.fromJson('CNPJ'), TipoTomador.cnpj);
    });

    test('valor ausente/desconhecido cai para CNPJ (compat legado)', () {
      expect(TipoTomadorExt.fromJson(null), TipoTomador.cnpj);
      expect(TipoTomadorExt.fromJson(''), TipoTomador.cnpj);
      expect(TipoTomadorExt.fromJson('outro'), TipoTomador.cnpj);
    });

    test('isPf e label refletem a natureza', () {
      expect(TipoTomador.cpf.isPf, isTrue);
      expect(TipoTomador.cpf.label, 'Paciente');
      expect(TipoTomador.cnpj.isPf, isFalse);
      expect(TipoTomador.cnpj.label, 'Empresa/Convênio');
    });
  });

  group('EnderecoFiscalTomador', () {
    test('completo exige todos os campos menos complemento', () {
      const completo = EnderecoFiscalTomador(
        cep: '01311000',
        logradouro: 'Avenida Paulista',
        numero: '1000',
        bairro: 'Bela Vista',
        municipio: 'Sao Paulo',
        uf: 'SP',
        codigoMunicipioIbge: '3550308',
      );
      expect(completo.completo, isTrue);
    });

    test('sem numero ou sem codigo IBGE não é completo (FR-005)', () {
      const semNumero = EnderecoFiscalTomador(
        cep: '01311000',
        logradouro: 'Avenida Paulista',
        bairro: 'Bela Vista',
        municipio: 'Sao Paulo',
        uf: 'SP',
        codigoMunicipioIbge: '3550308',
      );
      const semIbge = EnderecoFiscalTomador(
        cep: '01311000',
        logradouro: 'Avenida Paulista',
        numero: '1000',
        bairro: 'Bela Vista',
        municipio: 'Sao Paulo',
        uf: 'SP',
      );
      expect(semNumero.completo, isFalse);
      expect(semIbge.completo, isFalse);
    });

    test('fromJson tolera chave codigoMunicipioIbge (atendimento/lookup)', () {
      final e = EnderecoFiscalTomador.fromJson(<String, dynamic>{
        'cep': '01311000',
        'logradouro': 'Avenida Paulista',
        'numero': '1000',
        'bairro': 'Bela Vista',
        'municipio': 'Sao Paulo',
        'uf': 'SP',
        'codigoMunicipioIbge': '3550308',
      });
      expect(e.codigoMunicipioIbge, '3550308');
      expect(e.municipio, 'Sao Paulo');
      expect(e.completo, isTrue);
    });

    test('fromJson tolera chaves codigoIbge/cidade (autofill CEP)', () {
      final e = EnderecoFiscalTomador.fromJson(<String, dynamic>{
        'cep': '01311000',
        'logradouro': 'Avenida Paulista',
        'bairro': 'Bela Vista',
        'cidade': 'Sao Paulo',
        'uf': 'SP',
        'codigoIbge': '3550308',
      });
      expect(e.codigoMunicipioIbge, '3550308');
      expect(e.municipio, 'Sao Paulo');
      // numero vazio no autofill → ainda incompleto, médico preenche depois.
      expect(e.completo, isFalse);
    });

    test('copyWith atualiza numero sobre o autofill de CEP', () {
      const base = EnderecoFiscalTomador(
        cep: '01311000',
        logradouro: 'Avenida Paulista',
        bairro: 'Bela Vista',
        municipio: 'Sao Paulo',
        uf: 'SP',
        codigoMunicipioIbge: '3550308',
      );
      final preenchido = base.copyWith(numero: '1000');
      expect(preenchido.numero, '1000');
      expect(preenchido.logradouro, 'Avenida Paulista');
      expect(preenchido.completo, isTrue);
    });

    test('toJson usa chave codigoMunicipioIbge (round-trip)', () {
      const e = EnderecoFiscalTomador(
        cep: '01311000',
        numero: '1000',
        municipio: 'Sao Paulo',
        codigoMunicipioIbge: '3550308',
      );
      final json = e.toJson();
      expect(json['codigoMunicipioIbge'], '3550308');
      expect(json['municipio'], 'Sao Paulo');
      final volta = EnderecoFiscalTomador.fromJson(json);
      expect(volta.codigoMunicipioIbge, '3550308');
    });
  });

  group('Tomador PF (feature 017)', () {
    test('fromJson de atendimento lê tipo/mascarado/status e nome', () {
      final t = Tomador.fromJson(_tomadorPfAtendimento());
      expect(t.tipo, TipoTomador.cpf);
      expect(t.documentoMascarado, '***.***.***-09');
      // PF: nome mapeia para razaoSocial.
      expect(t.razaoSocial, 'Julia M. Ramos');
      expect(t.enderecoFiscalStatus, 'Completo');
      // Status "Completo" libera emissão mesmo sem endereço embarcado.
      expect(t.enderecoFiscalCompleto, isTrue);
    });

    test('fromJson de lookup hidrata endereco fiscal pela chave endereco', () {
      final t = Tomador.fromJson(_tomadorPfLookup());
      expect(t.tipo, TipoTomador.cpf);
      expect(t.enderecoFiscal, isNotNull);
      expect(t.enderecoFiscal!.numero, '1000');
      expect(t.enderecoFiscal!.codigoMunicipioIbge, '3550308');
      expect(t.enderecoFiscal!.completo, isTrue);
      expect(t.enderecoFiscalCompleto, isTrue);
    });

    test('enderecoFiscalCompleto deriva do endereco quando status vazio', () {
      final t = Tomador.fromJson(<String, dynamic>{
        'id': 'guid-tom-2',
        'tipo': 'CPF',
        'documentoMascarado': '***.***.***-09',
        'nome': 'Paciente Novo',
        'enderecoFiscal': <String, dynamic>{
          'cep': '01311000',
          'logradouro': 'Avenida Paulista',
          'numero': '500',
          'bairro': 'Bela Vista',
          'municipio': 'Sao Paulo',
          'uf': 'SP',
          'codigoMunicipioIbge': '3550308',
        },
      });
      expect(t.enderecoFiscalStatus, '');
      expect(t.enderecoFiscalCompleto, isTrue);
    });

    test('PF incompleto não libera emissão', () {
      final t = Tomador.fromJson(<String, dynamic>{
        'id': 'guid-tom-3',
        'tipo': 'CPF',
        'documentoMascarado': '***.***.***-09',
        'nome': 'Paciente Sem Numero',
        'enderecoFiscalStatus': 'Incompleto',
        'enderecoFiscal': <String, dynamic>{
          'cep': '01311000',
          'logradouro': 'Avenida Paulista',
          'bairro': 'Bela Vista',
          'municipio': 'Sao Paulo',
          'uf': 'SP',
          'codigoMunicipioIbge': '3550308',
        },
      });
      expect(t.enderecoFiscalCompleto, isFalse);
    });

    test('SC-004: nenhum CPF bruto no modelo ou no toJson', () {
      final t = Tomador.fromJson(_tomadorPfLookup());
      final dump = t.toJson().toString();
      expect(dump.contains('12345678909'), isFalse);
      expect(t.documentoMascarado.contains('*'), isTrue);
    });
  });

  group('Tomador CNPJ legado (compat)', () {
    test('payload sem campos PF assume tipo cnpj e não quebra', () {
      final t = Tomador.fromJson(_tomadorCnpjLegado());
      expect(t.tipo, TipoTomador.cnpj);
      expect(t.tipo.isPf, isFalse);
      expect(t.razaoSocial, 'Hospital Sao Lucas');
      expect(t.documentoMascarado, '');
      expect(t.enderecoFiscal, isNull);
      expect(t.enderecoFiscalStatus, '');
      expect(t.enderecoFiscalCompleto, isFalse);
    });

    test('default do construtor é CNPJ (tomadores existentes)', () {
      final t = Tomador(
        cnpj: '12.345.678/0001-90',
        razaoSocial: 'Clinica X',
        municipio: 'Sao Paulo',
        uf: 'SP',
      );
      expect(t.tipo, TipoTomador.cnpj);
    });
  });
}
