// test/features/syncview/proximo_plantao_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/servico.dart';
import 'package:medvie/features/syncview/widgets/proximo_plantao_card.dart';

Servico _servico({
  required String id,
  required TipoServico tipo,
  required DateTime data,
  required StatusServico status,
}) =>
    Servico(
      id: id,
      tipo: tipo,
      data: data,
      tomadorCnpj: '00000000000000',
      tomadorNome: 'Hosp. Teste',
      valor: 1000,
      status: status,
    );

void main() {
  final agora = DateTime.now();
  final futuro = DateTime(agora.year, agora.month, agora.day).add(
    const Duration(days: 2),
  );
  final maisFuturo = futuro.add(const Duration(days: 3));
  final passado = DateTime(agora.year, agora.month, agora.day).subtract(
    const Duration(days: 2),
  );

  group('ProximoPlantaoCard.proximo', () {
    test('lista vazia → null', () {
      expect(ProximoPlantaoCard.proximo(const []), isNull);
    });

    test('plantão pendente futuro → selecionado', () {
      final s = _servico(
        id: '1',
        tipo: TipoServico.plantao,
        data: futuro,
        status: StatusServico.pendente,
      );
      expect(ProximoPlantaoCard.proximo([s])?.id, '1');
    });

    test('plantão já convertido em NF (executado) → ignorado (não deriva de NF)',
        () {
      for (final status in [
        StatusServico.nfEmProcessamento,
        StatusServico.nfEmitida,
        StatusServico.aguardandoPagamento,
        StatusServico.pago,
      ]) {
        final s = _servico(
          id: 'nf',
          tipo: TipoServico.plantao,
          data: futuro,
          status: status,
        );
        expect(ProximoPlantaoCard.proximo([s]), isNull,
            reason: 'status $status deve ser excluído');
      }
    });

    test('plantão cancelado futuro → ignorado', () {
      final s = _servico(
        id: 'c',
        tipo: TipoServico.plantao,
        data: futuro,
        status: StatusServico.cancelado,
      );
      expect(ProximoPlantaoCard.proximo([s]), isNull);
    });

    test('plantão pendente no passado → ignorado', () {
      final s = _servico(
        id: 'p',
        tipo: TipoServico.plantao,
        data: passado,
        status: StatusServico.pendente,
      );
      expect(ProximoPlantaoCard.proximo([s]), isNull);
    });

    test('serviço não-plantão futuro → ignorado (nunca deriva de atendimento)',
        () {
      final s = _servico(
        id: 'consulta',
        tipo: TipoServico.consulta,
        data: futuro,
        status: StatusServico.pendente,
      );
      expect(ProximoPlantaoCard.proximo([s]), isNull);
    });

    test('vários plantões → retorna o de data mais próxima', () {
      final distante = _servico(
        id: 'distante',
        tipo: TipoServico.plantao,
        data: maisFuturo,
        status: StatusServico.pendente,
      );
      final proximo = _servico(
        id: 'proximo',
        tipo: TipoServico.plantao,
        data: futuro,
        status: StatusServico.pendente,
      );
      expect(ProximoPlantaoCard.proximo([distante, proximo])?.id, 'proximo');
    });
  });
}
