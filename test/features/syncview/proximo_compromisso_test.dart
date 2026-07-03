// test/features/syncview/proximo_compromisso_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:medvie/core/models/perfil_atuacao.dart';
import 'package:medvie/core/models/servico.dart';
import 'package:medvie/features/syncview/widgets/proximo_compromisso_card.dart';

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
      tomadorNome: 'Tomador Teste',
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

  group('ProximoCompromissoCard.focoDoPerfil', () {
    test('mapa perfil → tipo + título', () {
      expect(
        ProximoCompromissoCard.focoDoPerfil(PerfilAtuacao.plantonistaHospitalar),
        (tipo: TipoServico.plantao, titulo: 'Próximo plantão'),
      );
      expect(
        ProximoCompromissoCard.focoDoPerfil(PerfilAtuacao.medicoClinico),
        (tipo: TipoServico.consulta, titulo: 'Próxima consulta'),
      );
      expect(
        ProximoCompromissoCard.focoDoPerfil(PerfilAtuacao.cirurgiao),
        (tipo: TipoServico.procedimentoCirurgico, titulo: 'Próxima cirurgia'),
      );
      expect(
        ProximoCompromissoCard.focoDoPerfil(
          PerfilAtuacao.procedimentalistaAmbulatorial,
        ),
        (
          tipo: TipoServico.procedimentoCirurgico,
          titulo: 'Próximo procedimento',
        ),
      );
    });
  });

  group('ProximoCompromissoCard.proximo', () {
    test('lista vazia → null', () {
      expect(ProximoCompromissoCard.proximo(const [], TipoServico.plantao),
          isNull);
    });

    test('compromisso pendente futuro do foco → selecionado', () {
      final s = _servico(
        id: '1',
        tipo: TipoServico.consulta,
        data: futuro,
        status: StatusServico.pendente,
      );
      expect(
        ProximoCompromissoCard.proximo([s], TipoServico.consulta)?.id,
        '1',
      );
    });

    test('só considera o tipo do foco (plantonista não vê consulta e vice-versa)',
        () {
      final consulta = _servico(
        id: 'c',
        tipo: TipoServico.consulta,
        data: futuro,
        status: StatusServico.pendente,
      );
      final plantao = _servico(
        id: 'p',
        tipo: TipoServico.plantao,
        data: futuro,
        status: StatusServico.pendente,
      );
      // Foco plantão ignora a consulta.
      expect(
        ProximoCompromissoCard.proximo([consulta], TipoServico.plantao),
        isNull,
      );
      // Foco consulta ignora o plantão.
      expect(
        ProximoCompromissoCard.proximo([plantao], TipoServico.consulta),
        isNull,
      );
      // Entre os dois, cada foco pega o seu.
      expect(
        ProximoCompromissoCard.proximo([consulta, plantao], TipoServico.consulta)
            ?.id,
        'c',
      );
    });

    test('já convertido em NF (executado) → ignorado (não deriva de NF)', () {
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
        expect(
          ProximoCompromissoCard.proximo([s], TipoServico.plantao),
          isNull,
          reason: 'status $status deve ser excluído',
        );
      }
    });

    test('cancelado futuro → ignorado', () {
      final s = _servico(
        id: 'x',
        tipo: TipoServico.plantao,
        data: futuro,
        status: StatusServico.cancelado,
      );
      expect(
        ProximoCompromissoCard.proximo([s], TipoServico.plantao),
        isNull,
      );
    });

    test('pendente no passado → ignorado', () {
      final s = _servico(
        id: 'x',
        tipo: TipoServico.plantao,
        data: passado,
        status: StatusServico.pendente,
      );
      expect(
        ProximoCompromissoCard.proximo([s], TipoServico.plantao),
        isNull,
      );
    });

    test('vários do foco → retorna o de data mais próxima', () {
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
      expect(
        ProximoCompromissoCard.proximo([distante, proximo], TipoServico.plantao)
            ?.id,
        'proximo',
      );
    });
  });
}
