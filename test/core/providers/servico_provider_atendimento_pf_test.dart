import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/models/servico.dart';
import 'package:medvie/core/providers/nota_fiscal_provider.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

class _MockApi extends Mock implements MedvieApiService {}

const _cnpjProprioId = 'cnpj-001';
const _cpf = '12345678909';

const EnderecoFiscalTomador _enderecoCompleto = EnderecoFiscalTomador(
  cep: '01311000',
  logradouro: 'Avenida Paulista',
  numero: '1000',
  bairro: 'Bela Vista',
  municipio: 'Sao Paulo',
  uf: 'SP',
  codigoMunicipioIbge: '3550308',
);

AtendimentoPfResponse _respostaAtendimento({
  String servicoId = 'serv-1',
  String tomadorId = 'tom-1',
  String enderecoFiscalStatus = 'Completo',
  bool prontoParaEmitir = true,
}) =>
    AtendimentoPfResponse.fromJson(<String, dynamic>{
      'atendimentoId': 'atd-1',
      'servicoId': servicoId,
      'tomador': <String, dynamic>{
        'id': tomadorId,
        'tipo': 'CPF',
        'documentoMascarado': '***.***.***-09',
        'nome': 'Julia M. Ramos',
        'enderecoFiscalStatus': enderecoFiscalStatus,
      },
      'preview': <String, dynamic>{
        'bruto': 500.0,
        'issRetido': 0.0,
        'irrfRetido': 0.0,
        'ibs': 0.5,
        'cbs': 4.0,
        'liquidoEstimado': 500.0,
        'prontoParaEmitir': prontoParaEmitir,
      },
      'status': prontoParaEmitir ? 'ProntoParaEmitir' : 'PendenteDados',
    });

Future<AtendimentoPfResponse> _confirmar(
  ServicoProvider provider, {
  TipoServico tipo = TipoServico.consulta,
  double valor = 500.0,
}) =>
    provider.confirmarAtendimentoPf(
      cnpjProprioId: _cnpjProprioId,
      documentoCpf: _cpf,
      nomePaciente: 'Julia M. Ramos',
      endereco: _enderecoCompleto,
      tipoServico: tipo,
      descricao: 'Consulta medica particular',
      valor: valor,
      competencia: DateTime(2026, 6, 9),
      email: 'julia@example.com',
      telefone: '11999990000',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      AtendimentoPfRequest(
        requisicaoId: 'fallback',
        cnpjProprioId: 'fallback',
        tomador: const AtendimentoPfTomadorRequest(
          documento: '00000000000',
          nome: 'fallback',
          endereco: EnderecoFiscalTomador(),
        ),
        servico: AtendimentoPfServicoRequest(
          tipoServico: 'Consulta',
          codigoNbs: '40101',
          descricao: 'fallback',
          valor: 0,
          competencia: DateTime(2020),
          codigoMunicipioPrestacao: '0',
        ),
      ),
    );
  });

  group('confirmarAtendimentoPf (T030)', () {
    test('cria serviço PF local a partir da resposta, sem CPF bruto', () async {
      final api = _MockApi();
      late AtendimentoPfRequest enviado;
      when(() => api.criarAtendimentoPf(any())).thenAnswer((inv) async {
        enviado = inv.positionalArguments[0] as AtendimentoPfRequest;
        return _respostaAtendimento();
      });
      final provider = ServicoProvider(api: api);

      final res = await _confirmar(provider);

      // Request: emitirAgora false (FR-017) e CPF bruto só no payload transiente.
      expect(enviado.toJson()['emitirAgora'], isFalse);
      expect(enviado.tomador.documento, _cpf);
      expect(enviado.servico.tipoServico, 'Consulta');
      expect(enviado.servico.codigoMunicipioPrestacao, '3550308');

      // Serviço local.
      expect(provider.servicos.length, 1);
      final s = provider.servicos.single;
      expect(s.id, 'serv-1');
      expect(s.tomadorId, 'tom-1');
      expect(s.tomadorTipo, TipoTomador.cpf);
      expect(s.tomadorEhPf, isTrue);
      expect(s.tomadorCnpj, '');
      expect(s.tomadorDocumentoMascarado, '***.***.***-09');
      expect(s.tomadorEnderecoFiscalStatus, 'Completo');
      expect(s.status, StatusServico.pendente);

      // SC-004: nenhum CPF bruto vaza para o serviço persistido em memória.
      expect(s.toJson().toString().contains(_cpf), isFalse);
      expect(res.servicoId, 'serv-1');
    });

    test('idempotente por servicoId — não duplica na lista', () async {
      final api = _MockApi();
      when(() => api.criarAtendimentoPf(any()))
          .thenAnswer((_) async => _respostaAtendimento());
      final provider = ServicoProvider(api: api);

      await _confirmar(provider);
      await _confirmar(provider);

      expect(provider.servicos.length, 1);
    });

    test('lookupPacientePorCpf delega ao service e não guarda estado', () async {
      final api = _MockApi();
      when(
        () => api.lookupTomadorPorCpf(
          cnpjProprioId: any(named: 'cnpjProprioId'),
          documento: any(named: 'documento'),
        ),
      ).thenAnswer(
        (_) async => const LookupTomadorResponse(
          status: LookupTomadorStatus.encontrado,
          tomadorId: 'tom-1',
          documentoMascarado: '***.***.***-09',
          nome: 'Julia M. Ramos',
        ),
      );
      final provider = ServicoProvider(api: api);

      final res = await provider.lookupPacientePorCpf(
        cnpjProprioId: _cnpjProprioId,
        documentoCpf: _cpf,
      );

      expect(res.encontrado, isTrue);
      expect(res.nome, 'Julia M. Ramos');
      // Sem efeito colateral em estado.
      expect(provider.servicos, isEmpty);
    });

    test('buscarEnderecoFiscal monta endereço com CEP e IBGE', () async {
      final api = _MockApi();
      when(() => api.buscarCep(any())).thenAnswer(
        (_) async => BuscarCepResponse.fromJson(<String, dynamic>{
          'logradouro': 'Avenida Paulista',
          'bairro': 'Bela Vista',
          'localidade': 'Sao Paulo',
          'uf': 'SP',
          'codigoIbge': '3550308',
        }),
      );
      final provider = ServicoProvider(api: api);

      final endereco = await provider.buscarEnderecoFiscal('01311-000');

      expect(endereco.cep, '01311000');
      expect(endereco.logradouro, 'Avenida Paulista');
      expect(endereco.codigoMunicipioIbge, '3550308');
      expect(endereco.numero, '');
      expect(endereco.completo, isFalse);
    });
  });

  group('repetirServico — mesmo paciente (US3/T060)', () {
    Servico basePf() => Servico.fromJson(<String, dynamic>{
          'id': 'serv-1',
          'tipoServico': 'Consulta',
          'competencia': '2026-06-01',
          'tomadorId': 'tom-1',
          'tomadorNome': 'Julia M. Ramos',
          'tomadorCnpj': null,
          'tomadorTipo': 'CPF',
          'tomadorDocumentoMascarado': '***.***.***-09',
          'tomadorEnderecoFiscalStatus': 'Completo',
          'valor': 500.0,
          'status': 'pendente',
        });

    test('reusa tomadorId, preserva PF e não envia CPF bruto', () async {
      final api = _MockApi();
      Map<String, dynamic>? enviado;
      when(() => api.criarServico(any(), any())).thenAnswer((inv) async {
        enviado = inv.positionalArguments[1] as Map<String, dynamic>;
        return <String, dynamic>{'servicoId': 'serv-2'};
      });
      final provider = ServicoProvider(api: api);

      final nova = await provider.repetirServico(
        basePf(),
        cnpjProprioId: _cnpjProprioId,
      );

      // Persistido com novo id do backend, PF preservado, sem CPF bruto.
      expect(nova.id, 'serv-2');
      expect(nova.tomadorId, 'tom-1');
      expect(nova.tomadorTipo, TipoTomador.cpf);
      expect(nova.tomadorDocumentoMascarado, '***.***.***-09');
      expect(nova.status, StatusServico.pendente);
      expect(provider.servicos.any((s) => s.id == 'serv-2'), isTrue);

      expect(enviado!['tomadorId'], 'tom-1');
      expect(enviado!['tomadorTipo'], 'CPF');
      expect(enviado!.containsKey('requisicaoId'), isTrue);
      expect(enviado!.toString().contains('12345678909'), isFalse);
    });

    test('serviço sem tomadorId não pode repetir', () async {
      final api = _MockApi();
      final provider = ServicoProvider(api: api);
      final semTomador = basePf().copyWith(tomadorId: '');

      await expectLater(
        provider.repetirServico(semTomador, cnpjProprioId: _cnpjProprioId),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => api.criarServico(any(), any()));
    });
  });

  group('Bloqueio fiscal e emissão PF (T031/T033)', () {
    test('atendimento incompleto não fica pronto para emitir', () async {
      final api = _MockApi();
      when(() => api.criarAtendimentoPf(any())).thenAnswer(
        (_) async => _respostaAtendimento(
          enderecoFiscalStatus: 'Incompleto',
          prontoParaEmitir: false,
        ),
      );
      final provider = ServicoProvider(api: api);

      final res = await _confirmar(provider);

      expect(res.preview!.prontoParaEmitir, isFalse);
      final s = provider.servicos.single;
      expect(s.tomadorEnderecoFiscalStatus, 'Incompleto');
    });

    test('emissão PF reusa emitirNf — POST /notas por servicoId (FR-017)',
        () async {
      final api = _MockApi();
      when(() => api.criarAtendimentoPf(any()))
          .thenAnswer((_) async => _respostaAtendimento());
      when(
        () => api.emitirNota(
          servicoId: any(named: 'servicoId'),
          cnpjProprioId: any(named: 'cnpjProprioId'),
          tomadorId: any(named: 'tomadorId'),
          aliquotaIss: any(named: 'aliquotaIss'),
          issRetido: any(named: 'issRetido'),
        ),
      ).thenAnswer((_) async => 'nota-1');
      // Reload assíncrono (3s) é best-effort; stub evita throw fora do try.
      when(
        () => api.listarServicos(
          any(),
          pagina: any(named: 'pagina'),
          tamanhoPagina: any(named: 'tamanhoPagina'),
        ),
      ).thenAnswer((_) async => <Map<String, dynamic>>[]);

      final provider = ServicoProvider(api: api);
      await _confirmar(provider);
      final servicoId = provider.servicos.single.id;

      final ok = await provider.emitirNf(
        servicoId,
        NotaFiscalProvider(api),
        '12345678000190',
        cnpjProprioGuidParaReload: 'guid-cnpj',
      );

      expect(ok, isTrue);
      expect(
        provider.servicos.single.status,
        StatusServico.nfEmProcessamento,
      );
      // PF: ISS/IRRF zero (FR-007) — emitirNota recebe issRetido=false.
      final captured = verify(
        () => api.emitirNota(
          servicoId: captureAny(named: 'servicoId'),
          cnpjProprioId: any(named: 'cnpjProprioId'),
          tomadorId: captureAny(named: 'tomadorId'),
          aliquotaIss: any(named: 'aliquotaIss'),
          issRetido: captureAny(named: 'issRetido'),
        ),
      ).captured;
      expect(captured[0], servicoId);
      expect(captured[1], 'tom-1');
      expect(captured[2], isFalse);
    });
  });
}
