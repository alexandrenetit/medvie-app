// lib/features/syncview/widgets/preview_fiscal_cnpj_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';

/// Preview fiscal do atendimento Empresa/Convênio (CNPJ).
///
/// Diferente do PF, ISS/IRRF aqui **dependem do tomador** (retido ou não) —
/// mas o valor retido em R\$ só é conhecido no envio (alíquota por
/// município/competência, item do `Servico` do tomador). A UI exibe
/// "a definir no envio" ou "Não retém" sem inferir alíquota local. IBS/CBS
/// da reforma vêm do backend (`previewFiscalAtendimento`) e aparecem como
/// "calculado no envio" até a F5.T5.2 ligar o debounce.
///
/// Widget presentational puro: recebe os valores já calculados (ou 0 quando
/// pendentes). Não chama provider nem backend.
class PreviewFiscalCnpjCard extends StatelessWidget {
  /// Valor bruto do serviço em R\$.
  final double bruto;

  /// Tomador declara retenção de ISS no cadastro.
  final bool retemIss;

  /// Tomador declara retenção de IRRF no cadastro.
  final bool retemIrrf;

  /// IBS estimado pelo backend (0 até T5.2 ligar o debounce).
  final double ibs;

  /// CBS estimado pelo backend (0 até T5.2 ligar o debounce).
  final double cbs;

  /// Líquido estimado pelo backend (na F5.T5.1 = bruto, sem retenção
  /// definida; em T5.2 passa a refletir IBS/CBS).
  final double liquido;

  /// `true` quando os valores de IBS/CBS/líquido vieram do backend e podem
  /// ser exibidos como "cálculo oficial". `false` (default na T5.1) →
  /// placeholders "calculado no envio".
  final bool backendCalculado;

  /// `true` quando o toggle "Emitir agora?" está ligado E o backend já
  /// respondeu (F6.T6.1). Pílula muda para "✓ Pronto para emitir".
  final bool prontoParaEmitir;

  /// Ressalva de escopo vinda do backend (G-E/A4, `SimularNotaRessalvas`).
  /// Vazia = contrato pré-A4 ou preview ainda não calculado; nesse caso o card
  /// mantém a frase local de fallback.
  final String ressalvaEscopo;

  /// `true` quando o preview foi pedido COM `tomadorId` — só então ISS/IRRF/CSRF
  /// abaixo são resultado de avaliação. `false` mantém o comportamento anterior
  /// ("a definir no envio"): zero por falta de avaliação não é zero apurado.
  final bool retencoesAvaliadas;

  /// ISS/IRRF/CSRF retidos, em R\$, avaliados pelo backend a partir do cadastro
  /// do tomador. Só são exibidos quando [retencoesAvaliadas] — e é a mesma conta
  /// que produziu o [liquido], por isso a coluna fecha.
  final double issRetido;
  final double irrfRetido;
  final double csrfRetido;

  const PreviewFiscalCnpjCard({
    super.key,
    required this.bruto,
    required this.retemIss,
    required this.retemIrrf,
    this.ibs = 0,
    this.cbs = 0,
    required this.liquido,
    this.backendCalculado = false,
    this.prontoParaEmitir = false,
    this.ressalvaEscopo = '',
    this.retencoesAvaliadas = false,
    this.issRetido = 0,
    this.irrfRetido = 0,
    this.csrfRetido = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final issTexto = _textoRetencao(retemIss, issRetido, fmt);
    final irrfTexto = _textoRetencao(retemIrrf, irrfRetido, fmt);
    final ibsTexto = backendCalculado ? fmt.format(ibs) : 'calculado no envio';
    final cbsTexto = backendCalculado ? fmt.format(cbs) : 'calculado no envio';

    return Semantics(
      container: true,
      label: 'Preview fiscal do atendimento',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _linha('Valor do serviço', fmt.format(bruto)),
            _linha('ISS retido', issTexto, muted: !retemIss),
            _linha('IRRF retido', irrfTexto, muted: !retemIrrf),
            // CSRF não tem flag no cadastro (decorre do tipo de tomador): só
            // aparece quando o backend avaliou e retornou valor — senão a linha
            // seria um zero mudo.
            if (retencoesAvaliadas && csrfRetido > 0)
              _linha('PIS/COFINS/CSLL retidos', fmt.format(csrfRetido)),
            _linha('IBS', ibsTexto, tag: 'REFORMA', muted: !backendCalculado),
            _linha('CBS', cbsTexto, tag: 'REFORMA', muted: !backendCalculado),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // Com retenções avaliadas o valor abaixo já está líquido
                  // delas — chamar isso de "Valor da NFS-e" seria falso (a nota
                  // é emitida pelo bruto).
                  retencoesAvaliadas ? 'Líquido a receber' : 'Valor da NFS-e',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  fmt.format(liquido),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _statusIndicator(),
            const SizedBox(height: 8),
            // Ressalva de escopo canônica (G-E/A4): o texto vem pronto do
            // backend, que é quem sabe se as retenções foram avaliadas e qual a
            // janela do Split na competência. A frase local abaixo é só
            // fallback para contrato pré-A4 — manter as duas diria a mesma
            // coisa duas vezes, com a versão local dizendo menos.
            Text(
              ressalvaEscopo.isNotEmpty
                  ? ressalvaEscopo
                  : 'Retenções e IBS/CBS são definidos no envio. A UI não infere '
                      'alíquota — o cálculo oficial vem do backend.',
              key: const ValueKey('preview_ressalva_escopo'),
              style: const TextStyle(
                fontSize: 10,
                height: 1.35,
                color: AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sem avaliação, o card nunca mostra R\$ — "a definir no envio" é o único
  /// texto honesto para um valor que o backend não calculou. Com avaliação, o
  /// valor exibido é o mesmo que entrou no líquido.
  String _textoRetencao(bool retem, double valor, NumberFormat fmt) {
    if (!retem) return 'Não retém';
    if (!retencoesAvaliadas || !backendCalculado) return 'a definir no envio';
    return fmt.format(valor);
  }

  Widget _linha(
    String label,
    String valor, {
    String? tag,
    bool muted = false,
  }) {
    final cor = muted ? AppColors.textFaint : AppColors.textMid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: cor)),
              if (tag != null) ...[
                const SizedBox(width: 6),
                _reformaTag(tag),
              ],
            ],
          ),
          Text(
            valor,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: cor),
          ),
        ],
      ),
    );
  }

  Widget _reformaTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.cyan.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.cyan,
          ),
        ),
      );

  Widget _statusIndicator() {
    final String texto;
    final Color cor;
    if (prontoParaEmitir && backendCalculado && bruto > 0) {
      // Toggle "Emitir agora?" + backend respondeu: confirmar emissão.
      texto = '✓ Pronto para emitir';
      cor = AppColors.green;
    } else if (bruto <= 0) {
      texto = 'Informe o valor';
      cor = AppColors.amber;
    } else if (backendCalculado) {
      texto = 'Cálculo oficial do backend';
      cor = AppColors.green;
    } else {
      texto = 'Cálculo oficial no envio';
      cor = AppColors.cyan;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('preview-cnpj-status'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cor.withValues(alpha: 0.30)),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cor,
          ),
        ),
      ),
    );
  }
}
