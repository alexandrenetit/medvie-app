import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medvie/core/models/medico.dart';
import 'package:medvie/core/models/servico.dart';
import 'package:medvie/core/providers/servico_provider.dart';
import 'package:medvie/core/services/medvie_api_service.dart';

class _MockApi extends Mock implements MedvieApiService {}

const _cnpjProprioId = 'cnpj-001';

/// Tomador CNPJ que JÁ existe no backend (tem `id`). As retenções vêm do
/// cadastro do tomador — a UI/provider não infere alíquota (G7/F5).
Tomador _tomador({String id = 'tom-9'}) => Tomador(
      id: id,
      cnpj: '12345678000190',
      razaoSocial: 'Hospital Santa Casa LTDA',
      municipio: 'Sao Paulo',
      uf: 'SP',
      codigoIbge: '3550308',
      retemIss: true,
      aliquotaIss: 5.0,
      retemIrrf: true,
      aliquotaIrrf: 1.5,
    );

Future<Servico> _confirmar(
  ServicoProvider provider, {
  Tomador? tomador,
  TipoServico tipo = TipoServico.procedimentoCirurgico,
  double valor = 800.0,
  StatusServico status = StatusServico.pendente,
}) =>
    provider.confirmarAtendimentoCnpj(
      cnpjProprioId: _cnpjProprioId,
      tomador: tomador ?? _tomador(),
      tipoServico: tipo,
      descricao: 'Procedimento cirurgico ambulatorial',
      valor: valor,
      competencia: DateTime(2026, 6, 9),
      status: status,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('confirmarAtendimentoCnpj (F1.T1.4)', () {
    test('cria serviço CNPJ a partir da resposta; retenções vêm do tomador',
        () async {
      final api = _MockApi();
      Map<String, dynamic>? enviado;
      when(() => api.criarServico(any(), any())).thenAnswer((inv) async {
        enviado = inv.positionalArguments[1] as Map<String, dynamic>;
        return <String, dynamic>{'servicoId': 'serv-cnpj-1'};
      });
      final provider = ServicoProvider(api: api);

      final s = await _confirmar(provider);

      // Persistido com o servicoId do backend (não o Uuid local).
      expect(s.id, 'serv-cnpj-1');
      expect(s.tomadorId, 'tom-9');
      expect(s.tomadorTipo, TipoTomador.cnpj);
      expect(s.tomadorEhPf, isFalse);
      expect(s.tomadorCnpj, '12345678000190');
      expect(s.tomadorNome, 'Hospital Santa Casa LTDA');
      expect(s.status, StatusServico.pendente);

      // Retenções espelham o cadastro do tomador (sem inferência).
      expect(s.issRetido, isTrue);
      expect(s.aliquotaIss, 5.0);
      expect(s.retemIrrf, isTrue);
      expect(s.aliquotaIrrf, 1.5);

      // Lista local atualizada.
      expect(provider.servicos.length, 1);
      expect(provider.servicos.single.id, 'serv-cnpj-1');

      // Body: idempotência (requisicaoId) + vínculo de tomador CNPJ; não emite.
      expect(enviado!['cnpjProprioId'], isNot('')); // 1º arg posicional separado
      expect(enviado!['tomadorId'], 'tom-9');
      expect(enviado!['tomadorTipo'], 'CNPJ');
      expect(enviado!.containsKey('requisicaoId'), isTrue);
      verifyNever(
        () => api.emitirNota(
          servicoId: any(named: 'servicoId'),
          cnpjProprioId: any(named: 'cnpjProprioId'),
          tomadorId: any(named: 'tomadorId'),
        ),
      );
    });

    test('passa cnpjProprioId como 1º argumento posicional ao service',
        () async {
      final api = _MockApi();
      String? cnpjArg;
      when(() => api.criarServico(any(), any())).thenAnswer((inv) async {
        cnpjArg = inv.positionalArguments[0] as String;
        return <String, dynamic>{'servicoId': 'serv-cnpj-1'};
      });
      final provider = ServicoProvider(api: api);

      await _confirmar(provider);

      expect(cnpjArg, _cnpjProprioId);
    });

    test('idempotente por servicoId — não duplica na lista', () async {
      final api = _MockApi();
      when(() => api.criarServico(any(), any()))
          .thenAnswer((_) async => <String, dynamic>{'servicoId': 'serv-cnpj-1'});
      final provider = ServicoProvider(api: api);

      await _confirmar(provider);
      await _confirmar(provider);

      // Backend reusou a criação (mesmo servicoId) → substitui, não acumula.
      expect(provider.servicos.length, 1);
      expect(provider.servicos.single.id, 'serv-cnpj-1');
    });

    test('sem servicoId na resposta mantém o id local e adiciona à lista',
        () async {
      final api = _MockApi();
      when(() => api.criarServico(any(), any()))
          .thenAnswer((_) async => <String, dynamic>{});
      final provider = ServicoProvider(api: api);

      final s = await _confirmar(provider);

      expect(s.id, isNotEmpty);
      expect(provider.servicos.single.id, s.id);
    });

    test('tomador sem id é rejeitado e não chama o service', () async {
      final api = _MockApi();
      final provider = ServicoProvider(api: api);

      await expectLater(
        _confirmar(provider, tomador: _tomador(id: '')),
        throwsA(isA<Exception>()),
      );
      verifyNever(() => api.criarServico(any(), any()));
      expect(provider.servicos, isEmpty);
    });

    test('erro do service propaga e não adiciona serviço local', () async {
      final api = _MockApi();
      when(() => api.criarServico(any(), any()))
          .thenThrow(Exception('500 backend'));
      final provider = ServicoProvider(api: api);

      await expectLater(_confirmar(provider), throwsA(isA<Exception>()));
      expect(provider.servicos, isEmpty);
    });

    test('sem MedvieApiService injetado lança antes de qualquer chamada',
        () async {
      final provider = ServicoProvider();

      await expectLater(_confirmar(provider), throwsA(isA<Exception>()));
    });
  });
}
