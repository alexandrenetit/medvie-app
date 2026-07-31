// test/core/irrf_cadastro_tri_estado_test.dart
//
// F-04 / A6 no cliente: `retemIrrf` é TRI-ESTADO
// (medvie-api/docs/fiscal/RETENCAO-IRRF-PJ.md, D9).
//   - ausente/`null` → não informado, o backend aplica o default legal do
//     art. 714 do RIR/2018;
//   - `false`        → recusa explícita;
//   - `true`         → retenção declarada.
//
// O gap original era o app mandar `false` por omissão. Estes testes são o
// guard: se alguém voltar a serializar a chave sem declaração, quebram.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medvie/core/constants/irrf_cadastro.dart';
import 'package:medvie/core/errors/api_error.dart';
import 'package:medvie/core/errors/api_exception.dart';
import 'package:medvie/core/errors/mensagem_erro.dart';
import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

const _baseUrl = 'https://api.example.test';

MedvieApiService _service(http.Client client) {
  final service = MedvieApiService(client: client);
  service.baseUrl = _baseUrl;
  return service;
}

Tomador _tomador({Object? retemIrrf = _naoInformado}) => Tomador(
      cnpj: '12345678000190',
      razaoSocial: 'Hospital Santa Marta Ltda',
      municipio: 'Sao Paulo',
      uf: 'SP',
      codigoIbge: '3550308',
      retemIrrf: identical(retemIrrf, _naoInformado) ? null : retemIrrf as bool?,
    );

const Object _naoInformado = Object();

void main() {
  group('Tomador — tri-estado de retemIrrf', () {
    test('QuandoNaoInformado_ShouldSumirDoToJson', () {
      final json = _tomador().toJson();
      expect(json.containsKey('retemIrrf'), isFalse);
    });

    test('QuandoRecusaExplicita_ShouldPersistirFalse', () {
      final json = _tomador(retemIrrf: false).toJson();
      expect(json['retemIrrf'], isFalse);
    });

    test('QuandoRoundTripDeNaoInformado_ShouldContinuarNulo', () {
      final volta = Tomador.fromJson(_tomador().toJson());
      expect(volta.retemIrrf, isNull);
    });

    test('QuandoRoundTripDeRecusa_ShouldContinuarFalse', () {
      final volta = Tomador.fromJson(_tomador(retemIrrf: false).toJson());
      expect(volta.retemIrrf, isFalse);
    });

    test('copyWith_ShouldDistinguirOmitidoDeNuloExplicito', () {
      final declarado = _tomador(retemIrrf: true);
      // Parâmetro omitido preserva o valor atual…
      expect(declarado.copyWith(razaoSocial: 'Outro').retemIrrf, isTrue);
      // …e `null` explícito devolve o cadastro a "não informado".
      expect(declarado.copyWith(retemIrrf: null).retemIrrf, isNull);
    });
  });

  group('Tomador.retemIrrfExibicao — default legal na tela', () {
    test('QuandoPjSemDeclaracao_ShouldExibirRetencaoDoArt714', () {
      expect(_tomador().retemIrrfExibicao, isTrue);
      expect(kRetemIrrfPadraoLegalPj, isTrue);
    });

    test('QuandoPfSemDeclaracao_ShouldExibirSemRetencao', () {
      final pf = Tomador(
        cnpj: '',
        razaoSocial: 'Maria',
        municipio: 'Sao Paulo',
        uf: 'SP',
        tipo: TipoTomador.cpf,
      );
      expect(pf.retemIrrfExibicao, isFalse);
    });

    test('QuandoRecusaExplicita_ShouldRespeitarADeclaracao', () {
      expect(_tomador(retemIrrf: false).retemIrrfExibicao, isFalse);
    });
  });

  group('Tomador.retencaoIrrfDivergeRegraGeral — derivado pelo backend', () {
    test('QuandoBackendMarcaDivergencia_ShouldChegarAoModelo', () {
      final t = Tomador.fromJson({
        'cnpj': '12345678000190',
        'razaoSocial': 'X',
        'municipio': 'Y',
        'uf': 'SP',
        'retemIrrf': false,
        'retencaoIrrfDivergeRegraGeral': true,
      });
      expect(t.retencaoIrrfDivergeRegraGeral, isTrue);
    });

    test('QuandoCampoAusente_ShouldAssumirSemDivergencia', () {
      final t = Tomador.fromJson({
        'cnpj': '12345678000190',
        'razaoSocial': 'X',
        'municipio': 'Y',
        'uf': 'SP',
      });
      expect(t.retencaoIrrfDivergeRegraGeral, isFalse);
    });
  });

  group('POST /servicos/tomadores', () {
    test('QuandoCadastroSemDeclaracao_ShouldOmitirRetemIrrf', () async {
      Map<String, dynamic>? corpo;
      final api = _service(MockClient((req) async {
        corpo = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"tomadorId":"tom-1"}', 201,
            headers: {'content-type': 'application/json'});
      }));

      await api.cadastrarTomador('cnpj-1', _tomador());

      expect(corpo, isNotNull);
      expect(corpo!.containsKey('retemIrrf'), isFalse,
          reason: 'omissão = default legal do art. 714 (D9)');
    });

    test('QuandoMedicoRecusaRetencao_ShouldEnviarFalseExplicito', () async {
      Map<String, dynamic>? corpo;
      final api = _service(MockClient((req) async {
        corpo = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"tomadorId":"tom-1"}', 201,
            headers: {'content-type': 'application/json'});
      }));

      await api.cadastrarTomador('cnpj-1', _tomador(retemIrrf: false));

      expect(corpo!['retemIrrf'], isFalse);
    });
  });

  group('mensagemDeErro — código de domínio do IRRF', () {
    test('QuandoAliquotaIrrfObrigatoria_ShouldUsarCopyPropria', () {
      final erro = ApiException(ApiError.from(http.Response(
        jsonEncode({
          'code': kCodigoAliquotaIrrfObrigatoria,
          'description': 'texto cru do backend',
        }),
        400,
      )));

      final mensagem = mensagemDeErro(erro);
      expect(mensagem, kMensagemAliquotaIrrfObrigatoria);
      // SEC-014: `description` do backend nunca vai à tela.
      expect(mensagem, isNot(contains('texto cru do backend')));
    });

    test('QuandoOutro400_ShouldManterMensagemPorStatus', () {
      final erro = ApiException(ApiError.from(http.Response(
        jsonEncode({'code': 'Tomador.AliquotaIrrf', 'description': 'x'}),
        400,
      )));
      expect(mensagemDeErro(erro),
          'Dados inválidos. Revise as informações e tente novamente.');
    });
  });
}
