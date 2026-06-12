import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medvie/core/errors/api_error.dart';
import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

const _baseUrl = 'https://api.example.test';

MedvieApiService _service(http.Client client) {
  final service = MedvieApiService(client: client);
  service.baseUrl = _baseUrl;
  return service;
}

http.Response _json(String body, int statusCode) => http.Response(
      body,
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

AtendimentoPfRequest _requestValido() => AtendimentoPfRequest(
      requisicaoId: 'req-001',
      cnpjProprioId: 'cnpj-001',
      tomador: const AtendimentoPfTomadorRequest(
        documento: '12345678909',
        nome: 'Julia M. Ramos',
        email: 'julia@example.com',
        telefone: '11999990000',
        endereco: EnderecoFiscalTomador(
          cep: '01311000',
          logradouro: 'Avenida Paulista',
          numero: '1000',
          complemento: 'cj 101',
          bairro: 'Bela Vista',
          municipio: 'Sao Paulo',
          uf: 'SP',
          codigoMunicipioIbge: '3550308',
        ),
      ),
      servico: AtendimentoPfServicoRequest(
        tipoServico: 'Consulta',
        codigoNbs: '40111',
        descricao: 'Consulta medica particular',
        valor: 500.00,
        competencia: DateTime(2026, 6, 9),
        codigoMunicipioPrestacao: '3550308',
      ),
    );

const _responseCriado = '''
{
  "atendimentoId": "atd-1",
  "servicoId": "serv-1",
  "tomador": {
    "id": "tom-1",
    "tipo": "CPF",
    "documentoMascarado": "***.***.***-09",
    "nome": "Julia M. Ramos",
    "enderecoFiscalStatus": "Completo"
  },
  "preview": {
    "bruto": 500.00,
    "issRetido": 0.00,
    "irrfRetido": 0.00,
    "ibs": 0.50,
    "cbs": 4.00,
    "liquidoEstimado": 500.00,
    "prontoParaEmitir": true
  },
  "nota": null,
  "status": "ProntoParaEmitir"
}
''';

const _responseLookupEncontrado = '''
{
  "tomadorId": "tom-1",
  "tipo": "CPF",
  "documentoMascarado": "***.***.***-09",
  "nome": "Julia M. Ramos",
  "email": "julia@example.com",
  "telefone": "11999990000",
  "enderecoFiscalStatus": "Completo",
  "endereco": {
    "cep": "01311000",
    "logradouro": "Avenida Paulista",
    "numero": "1000",
    "complemento": "cj 101",
    "bairro": "Bela Vista",
    "municipio": "Sao Paulo",
    "uf": "SP",
    "codigoMunicipioIbge": "3550308"
  },
  "ultimoServico": {
    "tipoServico": "Consulta",
    "codigoNbs": "40111",
    "descricao": "Consulta medica particular",
    "competencia": "2026-06-05"
  }
}
''';

void main() {
  group('AtendimentoPfRequest.toJson', () {
    test('emitirAgora é sempre false (FR-017)', () {
      final json = _requestValido().toJson();
      expect(json['emitirAgora'], isFalse);
    });

    test('tomador usa tipo CPF, documento bruto e endereco no contrato', () {
      final json = _requestValido().toJson();
      final tomador = json['tomador'] as Map<String, dynamic>;
      expect(tomador['tipo'], 'CPF');
      expect(tomador['documento'], '12345678909');
      final endereco = tomador['endereco'] as Map<String, dynamic>;
      expect(endereco['codigoMunicipioIbge'], '3550308');
      expect(endereco['numero'], '1000');
    });

    test('competencia serializa como yyyy-MM-dd', () {
      final json = _requestValido().toJson();
      final servico = json['servico'] as Map<String, dynamic>;
      expect(servico['competencia'], '2026-06-09');
      expect(servico['valor'], 500.00);
    });

    test('email/telefone vazios são omitidos do payload', () {
      const req = AtendimentoPfTomadorRequest(
        documento: '12345678909',
        nome: 'Sem Contato',
        endereco: EnderecoFiscalTomador(),
      );
      final json = req.toJson();
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('telefone'), isFalse);
    });
  });

  group('criarAtendimentoPf', () {
    test('201 parseia atendimento, serviço, tomador PF e preview', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _json(_responseCriado, 201);
      });
      final service = _service(client);

      final res = await service.criarAtendimentoPf(_requestValido());

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/v1/atendimentos');
      final sentBody = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sentBody['emitirAgora'], isFalse);

      expect(res.atendimentoId, 'atd-1');
      expect(res.servicoId, 'serv-1');
      expect(res.status, 'ProntoParaEmitir');
      expect(res.tomador.tipo, TipoTomador.cpf);
      expect(res.tomador.documentoMascarado, '***.***.***-09');
      expect(res.tomador.enderecoFiscalCompleto, isTrue);
      expect(res.preview, isNotNull);
      expect(res.preview!.issRetido, 0.0);
      expect(res.preview!.irrfRetido, 0.0);
      expect(res.preview!.prontoParaEmitir, isTrue);
    });

    test('200 (reuso idempotente) também é sucesso', () async {
      final client = MockClient((_) async => _json(_responseCriado, 200));
      final service = _service(client);
      final res = await service.criarAtendimentoPf(_requestValido());
      expect(res.servicoId, 'serv-1');
    });

    test('422 endereço incompleto lança ApiException com code', () async {
      const body = '''
      {"code":"Tomador.EnderecoFiscal.Incompleto",
       "description":"Endereco fiscal do tomador PF incompleto."}''';
      final client = MockClient((_) async => _json(body, 422));
      final service = _service(client);

      await expectLater(
        service.criarAtendimentoPf(_requestValido()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'Tomador.EnderecoFiscal.Incompleto')
              .having((e) => e.isValidation, 'isValidation', isTrue),
        ),
      );
    });

    test('SC-004: nenhum CPF bruto exposto pela resposta parseada', () async {
      final client = MockClient((_) async => _json(_responseCriado, 201));
      final service = _service(client);
      final res = await service.criarAtendimentoPf(_requestValido());
      expect(res.tomador.documentoMascarado.contains('*'), isTrue);
      expect(res.tomador.toJson().toString().contains('12345678909'), isFalse);
    });
  });

  group('lookupTomadorPorCpf', () {
    test('200 → encontrado com endereço, contato e último serviço', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _json(_responseLookupEncontrado, 200);
      });
      final service = _service(client);

      final res = await service.lookupTomadorPorCpf(
        cnpjProprioId: 'cnpj-001',
        documento: '12345678909',
      );

      expect(captured.url.path, '/api/v1/atendimentos/tomador/lookup');
      final sent = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sent['documento'], '12345678909');
      expect(sent['cnpjProprioId'], 'cnpj-001');

      expect(res.status, LookupTomadorStatus.encontrado);
      expect(res.encontrado, isTrue);
      expect(res.nome, 'Julia M. Ramos');
      expect(res.email, 'julia@example.com');
      expect(res.telefone, '11999990000');
      expect(res.documentoMascarado, '***.***.***-09');
      expect(res.endereco, isNotNull);
      expect(res.endereco!.codigoMunicipioIbge, '3550308');
      expect(res.enderecoFiscalCompleto, isTrue);
      expect(res.ultimoServico!.tipoServico, 'Consulta');
      expect(res.ultimoServico!.codigoNbs, '40111');
    });

    test('404 → novoPaciente, sem dados e sem exceção', () async {
      final client = MockClient(
        (_) async => _json('{"code":"Tomador.NaoEncontrado"}', 404),
      );
      final service = _service(client);
      final res = await service.lookupTomadorPorCpf(
        cnpjProprioId: 'cnpj-001',
        documento: '12345678909',
      );
      expect(res.status, LookupTomadorStatus.novoPaciente);
      expect(res.novoPaciente, isTrue);
      expect(res.nome, '');
      expect(res.endereco, isNull);
    });

    test('422 → cpfInvalido', () async {
      final client = MockClient(
        (_) async => _json('{"code":"Tomador.Cpf.Invalido"}', 422),
      );
      final service = _service(client);
      final res = await service.lookupTomadorPorCpf(
        cnpjProprioId: 'cnpj-001',
        documento: '00000000000',
      );
      expect(res.status, LookupTomadorStatus.cpfInvalido);
      expect(res.cpfInvalido, isTrue);
    });

    test('5xx inesperado lança ApiException', () async {
      final client = MockClient((_) async => _json('{}', 500));
      final service = _service(client);
      await expectLater(
        service.lookupTomadorPorCpf(
          cnpjProprioId: 'cnpj-001',
          documento: '12345678909',
        ),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('BuscarCepResponse (endereço fiscal PF)', () {
    test('fromJson lê codigoIbge e tolera municipio/localidade', () {
      final r = BuscarCepResponse.fromJson(<String, dynamic>{
        'logradouro': 'Avenida Paulista',
        'bairro': 'Bela Vista',
        'municipio': 'Sao Paulo',
        'uf': 'SP',
        'codigoIbge': '3550308',
      });
      expect(r.municipio, 'Sao Paulo');
      expect(r.codigoIbge, '3550308');
    });

    test('toEnderecoFiscal injeta cep e deixa numero vazio (FR-004)', () {
      final r = BuscarCepResponse.fromJson(<String, dynamic>{
        'logradouro': 'Avenida Paulista',
        'bairro': 'Bela Vista',
        'localidade': 'Sao Paulo',
        'uf': 'SP',
        'codigoIbge': '3550308',
      });
      final e = r.toEnderecoFiscal('01311000');
      expect(e.cep, '01311000');
      expect(e.codigoMunicipioIbge, '3550308');
      expect(e.numero, '');
      expect(e.completo, isFalse);
    });
  });

  group('mensagemErroAtendimentoPf', () {
    test('mapeia códigos conhecidos para mensagem segura pt-BR', () {
      String msg(String? code) => MedvieApiService.mensagemErroAtendimentoPf(
            ApiError(statusCode: 422, code: code),
          );
      expect(
        msg('Tomador.EnderecoFiscal.Incompleto'),
        contains('Endereço fiscal'),
      );
      expect(msg('Tomador.Cpf.Duplicado'), contains('Já existe'));
      expect(msg('Tomador.Cpf.Invalido'), contains('CPF inválido'));
    });

    test('fallback por faixa de status sem expor payload técnico', () {
      expect(
        MedvieApiService.mensagemErroAtendimentoPf(
          const ApiError(statusCode: 500),
        ),
        contains('Falha temporária'),
      );
      expect(
        MedvieApiService.mensagemErroAtendimentoPf(
          const ApiError(statusCode: 422),
        ),
        contains('validar'),
      );
    });
  });
}
