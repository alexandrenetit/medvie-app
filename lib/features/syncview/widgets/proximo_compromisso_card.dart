// lib/features/syncview/widgets/proximo_compromisso_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/perfil_atuacao.dart';
import '../../../core/models/servico.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/servico_provider.dart';
import '../../../core/utils/formatters.dart';

/// Card "Próximo compromisso" (opção 1b): mostra o próximo serviço **agendado**
/// do foco do perfil do médico.
///
/// O tipo e o título seguem o [PerfilAtuacao] (fonte: backend via
/// `OnboardingProvider`): plantonista vê plantão; clínico, consulta; cirurgião,
/// cirurgia; procedimentalista, procedimento. Fonte exclusiva: compromissos
/// futuros da Agenda ainda planejados (status pendente), nunca um serviço já
/// convertido em NF. Sem compromisso do foco a seção some (a tela mostra
/// "Últimos lançamentos" no lugar). A seleção é apresentação (filtro/ordenação
/// de uma lista já carregada), não regra de negócio. [onAbrirAgenda] abre a
/// aba Agenda.
class ProximoCompromissoCard extends StatelessWidget {
  final VoidCallback? onAbrirAgenda;

  const ProximoCompromissoCard({super.key, this.onAbrirAgenda});

  static const List<String> _diasSemana = [
    'SEG',
    'TER',
    'QUA',
    'QUI',
    'SEX',
    'SÁB',
    'DOM',
  ];

  /// Foco do perfil: tipo de serviço filtrado e título da seção. Decisão de
  /// produto (não regra fiscal). O enum de serviço não tem "procedimento
  /// ambulatorial" próprio → procedimentalista e cirurgião compartilham
  /// `procedimentoCirurgico`, diferenciados apenas pelo título.
  static ({TipoServico tipo, String titulo}) focoDoPerfil(
    PerfilAtuacao perfil,
  ) {
    switch (perfil) {
      case PerfilAtuacao.plantonistaHospitalar:
        return (tipo: TipoServico.plantao, titulo: 'Próximo plantão');
      case PerfilAtuacao.medicoClinico:
        return (tipo: TipoServico.consulta, titulo: 'Próxima consulta');
      case PerfilAtuacao.cirurgiao:
        return (
          tipo: TipoServico.procedimentoCirurgico,
          titulo: 'Próxima cirurgia',
        );
      case PerfilAtuacao.procedimentalistaAmbulatorial:
        return (
          tipo: TipoServico.procedimentoCirurgico,
          titulo: 'Próximo procedimento',
        );
    }
  }

  /// Próximo compromisso agendado do [foco]: mesmo tipo, ainda planejado (não
  /// cancelado e não convertido em NF — `foiExecutado` marca os que já viraram
  /// nota) e com data de hoje em diante. Ordena por data e devolve o primeiro.
  static Servico? proximo(List<Servico> servicos, TipoServico foco) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final futuros = servicos.where((s) {
      if (s.tipo != foco) return false;
      if (s.status == StatusServico.cancelado) return false;
      if (s.status.foiExecutado) return false;
      final d = DateTime(s.data.year, s.data.month, s.data.day);
      return !d.isBefore(hoje);
    }).toList()..sort((a, b) => a.data.compareTo(b.data));
    return futuros.isEmpty ? null : futuros.first;
  }

  @override
  Widget build(BuildContext context) {
    final perfil = context.watch<OnboardingProvider>().perfilAtuacao;
    final foco = focoDoPerfil(perfil);
    final servicos = context.watch<ServicoProvider>().servicos;
    final compromisso = proximo(servicos, foco.tipo);

    // Sem compromisso futuro do foco: seção inteira some (a tela decide o que
    // exibir — normalmente "Últimos lançamentos").
    if (compromisso == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Inset horizontal de 4px do design (margin: 0 4px 8px).
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              foco.titulo,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMid,
              ),
            ),
          ),
          _buildCard(compromisso),
        ],
      ),
    );
  }

  Widget _buildCard(Servico s) {
    final duracao = s.duracaoFormatada;
    final linha1 = duracao == null
        ? s.tomadorNome
        : '${s.tomadorNome} · $duracao';
    // Descrição do design ("plantão noturno"): usa a observação registrada
    // pelo médico quando houver; sem observação, cai no rótulo do tipo.
    final descricao = s.observacao.trim().isNotEmpty
        ? s.observacao.trim()
        : s.tipo.label;
    final horario = s.horarioFormatado;
    final linha2 = horario == null ? descricao : '$horario · $descricao';

    return GestureDetector(
      onTap: onAbrirAgenda,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.indigo.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            _buildBadge(s),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linha1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    linha2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              s.valor.toBrl(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(Servico s) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.indigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _relLabel(s.data),
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.indigo,
            ),
          ),
          Text(
            _hora(s),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  String _relLabel(DateTime data) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final d = DateTime(data.year, data.month, data.day);
    final diff = d.difference(hoje).inDays;
    if (diff == 0) return 'HOJE';
    if (diff > 0 && diff < 7) return _diasSemana[data.weekday - 1];
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }

  String _hora(Servico s) {
    final hi = s.horaInicio;
    if (hi == null) return '--';
    return '${hi.hour}h';
  }
}
