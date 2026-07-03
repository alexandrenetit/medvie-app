// lib/features/syncview/widgets/pendencia.dart

import '../../../core/models/nota_fiscal.dart';
import '../../../core/models/servico.dart';
import '../../../core/utils/formatters.dart';

/// Tipo de pendência acionável exibida em "Precisa de você".
enum PendenciaTipo { enderecoFiscal, notaRejeitada }

/// View-model de uma pendência acionável da SyncView (opção 1b).
///
/// Agrega, sem calcular nada fiscal, duas fontes já providas pelo backend:
/// - atendimentos com endereço fiscal incompleto (não emitidos);
/// - NFS-e rejeitadas pelo município.
///
/// PII: exibe apenas o nome do tomador; documento nunca aparece aqui e a
/// mensagem crua de rejeição do provider nunca é exposta.
class Pendencia {
  final PendenciaTipo tipo;

  /// ID do serviço ou da nota — usado para navegar ao fluxo de correção.
  final String referenciaId;
  final String titulo;
  final String subtitulo;
  final String acaoLabel;

  const Pendencia({
    required this.tipo,
    required this.referenciaId,
    required this.titulo,
    required this.subtitulo,
    required this.acaoLabel,
  });

  /// Monta a lista de pendências a partir dos dados dos providers.
  /// Endereço fiscal incompleto primeiro (bloqueia emissão), depois rejeições.
  static List<Pendencia> montar({
    required List<Servico> servicos,
    required List<NotaFiscal> notasRejeitadas,
  }) {
    final lista = <Pendencia>[];

    for (final s in servicos) {
      final incompleto =
          s.tomadorEnderecoFiscalStatus.trim().toLowerCase() == 'incompleto';
      if (s.status == StatusServico.pendente && incompleto) {
        lista.add(
          Pendencia(
            tipo: PendenciaTipo.enderecoFiscal,
            referenciaId: s.id,
            titulo: 'Completar endereço fiscal',
            subtitulo: _juntar([s.tomadorNome, s.tipo.label, s.valor.toBrl()]),
            acaoLabel: 'Resolver ›',
          ),
        );
      }
    }

    for (final n in notasRejeitadas) {
      lista.add(
        Pendencia(
          tipo: PendenciaTipo.notaRejeitada,
          referenciaId: n.id,
          titulo: 'NF rejeitada pelo município',
          subtitulo: _juntar([
            n.tomadorNome,
            n.tipoServico,
            n.valorBruto?.toBrl(),
          ]),
          acaoLabel: 'Corrigir ›',
        ),
      );
    }

    return lista;
  }

  /// Junta partes não-vazias com " · " (ignora null/branco).
  static String _juntar(List<String?> partes) => partes
      .map((p) => p?.trim() ?? '')
      .where((p) => p.isNotEmpty)
      .join(' · ');
}
