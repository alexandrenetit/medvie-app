// lib/features/syncview/widgets/tomador_selector_sheet.dart
//
// F2 — Seleção de tomador CNPJ (substitui o dropdown legado que não escala).
// Espelha o protótipo aprovado `prototipo_pf/medvie-atendimento-cnpj-v15.html`.
//
// T2.1 (este arquivo): card resumo de altura fixa do tomador selecionado
// (sigla, razão social, CNPJ mono, tags de retenção) + botão "Trocar".
// O bottom sheet de busca/seleção/cadastro entra nas tasks T2.2–T2.4.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/medico.dart';
import '../../../core/utils/formatters.dart';

/// Resumo de altura fixa do tomador selecionado: sigla, razão social, CNPJ
/// (mono) e tags de retenção, com botão "Trocar"/"Escolher". Sem tomador,
/// exibe estado vazio. A altura não cresce com N tomadores (G1 do plano).
///
/// Não gerencia estado nem a fonte de tomadores (vive no `OnboardingProvider`
/// — §3.A T0.2). O acionamento do sheet de seleção é delegado via [onTrocar].
class TomadorResumoCard extends StatelessWidget {
  /// Tomador atualmente selecionado; `null` exibe o estado vazio.
  final Tomador? selecionado;

  /// Total de tomadores cadastrados (exibido como contagem auxiliar).
  final int totalCadastrados;

  /// Aciona a troca/escolha de tomador (abre o sheet — T2.2).
  final VoidCallback onTrocar;

  const TomadorResumoCard({
    super.key,
    required this.selecionado,
    required this.totalCadastrados,
    required this.onTrocar,
  });

  @override
  Widget build(BuildContext context) {
    final t = selecionado;
    final vazio = t == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: vazio ? null : AppColors.green.withValues(alpha: 0.05),
            border: Border.all(
              color: vazio
                  ? AppColors.border
                  : AppColors.green.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              _Logo(
                sigla: vazio ? '?' : _siglaFrom(t.razaoSocial),
                vazio: vazio,
              ),
              const SizedBox(width: 12),
              Expanded(child: vazio ? const _InfoVazio() : _Info(tomador: t)),
              const SizedBox(width: 12),
              _TrocarButton(
                label: vazio ? 'Escolher' : 'Trocar',
                onTap: onTrocar,
              ),
            ],
          ),
        ),
        if (totalCadastrados > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text(
              _countText(totalCadastrados),
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textFaint,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

/// Quadrado 40×40 com a sigla do tomador (ou "?" no estado vazio).
class _Logo extends StatelessWidget {
  final String sigla;
  final bool vazio;

  const _Logo({required this.sigla, required this.vazio});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: vazio
            ? AppColors.text.withValues(alpha: 0.05)
            : AppColors.cyan.withValues(alpha: 0.10),
      ),
      child: Text(
        sigla,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: vazio ? AppColors.textFaint : AppColors.cyan,
        ),
      ),
    );
  }
}

/// Razão social, CNPJ (mono) e tags de retenção do tomador selecionado.
class _Info extends StatelessWidget {
  final Tomador tomador;

  const _Info({required this.tomador});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tomador.razaoSocial,
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
          'CNPJ ${tomador.cnpj.formatCnpj()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            letterSpacing: 0.3,
            color: AppColors.textFaint,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: _tagsRetencao(tomador),
        ),
      ],
    );
  }
}

/// Estado sem tomador selecionado.
class _InfoVazio extends StatelessWidget {
  const _InfoVazio();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nenhum tomador selecionado',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textMid,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Toque em escolher para selecionar',
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: AppColors.textFaint,
          ),
        ),
      ],
    );
  }
}

/// Botão pill "Trocar"/"Escolher".
class _TrocarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TrocarButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.text.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de tag de retenção (ISS/IRRF/sem retenção).
class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Tags de retenção a partir das flags do tomador. Sem ISS nem IRRF →
/// "Sem retenção". As alíquotas/retenções vêm do cadastro (backend), nunca
/// inferidas na UI (regra backend-verdade).
List<Widget> _tagsRetencao(Tomador t) {
  if (!t.retemIss && !t.retemIrrf) {
    return const [_TagChip(label: 'Sem retenção', color: AppColors.green)];
  }
  return [
    if (t.retemIss) const _TagChip(label: 'Retém ISS', color: AppColors.amber),
    if (t.retemIrrf)
      const _TagChip(label: 'Retém IRRF', color: AppColors.indigo),
  ];
}

/// Sigla de até 3 letras a partir das iniciais das palavras da razão social
/// (espelha a geração do protótipo v15). Fallback "TM".
String _siglaFrom(String razaoSocial) {
  final letras = razaoSocial.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ ]'), '');
  final iniciais = letras
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(3)
      .map((w) => w[0].toUpperCase())
      .join();
  return iniciais.isEmpty ? 'TM' : iniciais;
}

/// Texto de contagem: "N tomador(es) cadastrado(s)".
String _countText(int n) =>
    '$n ${n == 1 ? 'tomador cadastrado' : 'tomadores cadastrados'}';
