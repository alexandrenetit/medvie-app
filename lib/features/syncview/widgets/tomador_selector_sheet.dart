// lib/features/syncview/widgets/tomador_selector_sheet.dart
//
// F2 — Seleção de tomador CNPJ (substitui o dropdown legado que não escala).
// Espelha o protótipo aprovado `prototipo_pf/medvie-atendimento-cnpj-v15.html`.
//
// T2.1: card resumo de altura fixa do tomador selecionado
// (sigla, razão social, CNPJ mono, tags de retenção) + botão "Trocar".
// T2.2: bottom sheet de busca/seleção — `showTomadorSelectorSheet`
// (handle, busca por razão/CNPJ, lista rolável `ListView.builder`, radio,
// empty state de "nenhum encontrado").
// T2.3 (este arquivo): estado vazio total (médico sem nenhum tomador) — esconde
// busca/rodapé e exibe CTA primário "Cadastrar primeiro tomador" (gancho
// `onCadastrar`; o fluxo de cadastro entra em F3). A11y entra em T2.4.

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

/// Filtra por razão social (substring case-insensitive) ou CNPJ (comparação
/// alfanumérica, ignorando máscara — CNPJ pode ser alfanumérico a partir de
/// jul/2026). Query vazia retorna a lista inteira.
List<Tomador> _filtrar(List<Tomador> todos, String query) {
  final q = query.trim();
  if (q.isEmpty) return todos;
  final qNome = q.toLowerCase();
  final qDoc = q.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
  return todos.where((t) {
    final nomeMatch = t.razaoSocial.toLowerCase().contains(qNome);
    final docMatch = qDoc.isNotEmpty &&
        t.cnpj
            .replaceAll(RegExp(r'[^0-9A-Za-z]'), '')
            .toUpperCase()
            .contains(qDoc);
    return nomeMatch || docMatch;
  }).toList();
}

// ─── Bottom sheet (T2.2) ─────────────────────────────────────────────────────

/// Abre o bottom sheet de seleção de tomador (busca + lista rolável + radio).
/// Resolve com o [Tomador] escolhido, ou `null` se fechado sem seleção.
///
/// [selecionadoId] marca a linha já selecionada. [onCadastrar] (opcional)
/// renderiza o rodapé "Cadastrar novo tomador" — o fluxo de cadastro entra
/// em F3 (T3.x); aqui é só o gancho de UI.
Future<Tomador?> showTomadorSelectorSheet({
  required BuildContext context,
  required List<Tomador> tomadores,
  String? selecionadoId,
  VoidCallback? onCadastrar,
}) {
  return showModalBottomSheet<Tomador>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.55),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _TomadorSelectorSheet(
      tomadores: tomadores,
      selecionadoId: selecionadoId,
      onCadastrar: onCadastrar,
    ),
  );
}

/// Corpo do sheet: mantém o estado da busca e devolve o tomador escolhido.
class _TomadorSelectorSheet extends StatefulWidget {
  final List<Tomador> tomadores;
  final String? selecionadoId;
  final VoidCallback? onCadastrar;

  const _TomadorSelectorSheet({
    required this.tomadores,
    required this.selecionadoId,
    required this.onCadastrar,
  });

  @override
  State<_TomadorSelectorSheet> createState() => _TomadorSelectorSheetState();
}

class _TomadorSelectorSheetState extends State<_TomadorSelectorSheet> {
  final TextEditingController _buscaController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Vazio total: médico sem nenhum tomador cadastrado (≠ busca sem match).
    // Esconde busca/rodapé e mostra só o CTA de cadastro (T2.3).
    final semTomadores = widget.tomadores.isEmpty;
    final filtrados =
        semTomadores ? const <Tomador>[] : _filtrar(widget.tomadores, _query);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(
              top: BorderSide(color: AppColors.border),
              left: BorderSide(color: AppColors.border),
              right: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              _SheetHead(onClose: () => Navigator.of(context).pop()),
              if (semTomadores)
                Flexible(child: _SheetEmptyTotal(onCadastrar: widget.onCadastrar))
              else ...[
                _SheetSearch(
                  controller: _buscaController,
                  onChanged: (v) => setState(() => _query = v),
                ),
                Flexible(
                  child: filtrados.isEmpty
                      ? const _SheetEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) {
                            final t = filtrados[i];
                            return Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                              child: _TomadorRow(
                                tomador: t,
                                selecionado: t.id == widget.selecionadoId,
                                onTap: () => Navigator.of(context).pop(t),
                              ),
                            );
                          },
                        ),
                ),
                if (widget.onCadastrar != null)
                  _SheetFoot(onCadastrar: widget.onCadastrar!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Alça do sheet (38×4).
class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Cabeçalho do sheet: título + botão fechar.
class _SheetHead extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetHead({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Selecionar tomador',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          Material(
            color: AppColors.text.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.close, size: 16, color: AppColors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de busca por razão social ou CNPJ.
class _SheetSearch extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SheetSearch({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
        cursorColor: AppColors.green,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.bg,
          hintText: 'Buscar por razão social ou CNPJ',
          hintStyle: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textFaint,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textFaint,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.green),
          ),
        ),
      ),
    );
  }
}

/// Linha de tomador no sheet: logo, razão/CNPJ/tags e radio de seleção.
class _TomadorRow extends StatelessWidget {
  final Tomador tomador;
  final bool selecionado;
  final VoidCallback onTap;

  const _TomadorRow({
    required this.tomador,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionado
          ? AppColors.green.withValues(alpha: 0.06)
          : AppColors.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selecionado
                  ? AppColors.green.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _Logo(sigla: _siglaFrom(tomador.razaoSocial), vazio: false),
              const SizedBox(width: 12),
              Expanded(child: _Info(tomador: tomador)),
              const SizedBox(width: 12),
              _RadioCircle(selecionado: selecionado),
            ],
          ),
        ),
      ),
    );
  }
}

/// Radio circular (22) — preenchido em verde com check quando selecionado.
class _RadioCircle extends StatelessWidget {
  final bool selecionado;

  const _RadioCircle({required this.selecionado});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selecionado ? AppColors.green : Colors.transparent,
        border: Border.all(
          color: selecionado ? AppColors.green : AppColors.border,
          width: 2,
        ),
      ),
      child: selecionado
          ? const Icon(Icons.check, size: 12, color: AppColors.bg)
          : null,
    );
  }
}

/// Estado vazio do sheet: nenhuma correspondência para a busca.
class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 28, 8, 28),
      child: Text(
        'Nenhum tomador encontrado.\nRevise a busca por razão social ou CNPJ.',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textFaint,
        ),
      ),
    );
  }
}

/// Estado vazio total: médico sem nenhum tomador cadastrado (T2.3). Ocupa o
/// corpo do sheet com ícone, mensagem e CTA primário de cadastro. Sem
/// [onCadastrar] (gancho ainda não ligado — F3), cai para texto informativo.
class _SheetEmptyTotal extends StatelessWidget {
  final VoidCallback? onCadastrar;

  const _SheetEmptyTotal({required this.onCadastrar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan.withValues(alpha: 0.10),
            ),
            child: const Icon(
              Icons.apartment_outlined,
              size: 26,
              color: AppColors.cyan,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum tomador cadastrado',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            onCadastrar != null
                ? 'Cadastre o primeiro hospital ou clínica para registrar atendimentos como Empresa / Convênio.'
                : 'Adicione hospitais ou clínicas nas configurações para registrar atendimentos como Empresa / Convênio.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textFaint,
            ),
          ),
          if (onCadastrar != null) ...[
            const SizedBox(height: 20),
            _CadastrarPrimaryButton(onTap: onCadastrar!),
          ],
        ],
      ),
    );
  }
}

/// CTA primário (verde preenchido) para cadastrar o primeiro tomador.
class _CadastrarPrimaryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CadastrarPrimaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cadastrar primeiro tomador',
      child: Material(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 18, color: AppColors.bg),
                const SizedBox(width: 8),
                Text(
                  'Cadastrar primeiro tomador',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rodapé do sheet: CTA para cadastrar novo tomador (gancho — fluxo em F3).
class _SheetFoot extends StatelessWidget {
  final VoidCallback onCadastrar;

  const _SheetFoot({required this.onCadastrar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCadastrar,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 18, color: AppColors.textMid),
                const SizedBox(width: 8),
                Text(
                  'Cadastrar novo tomador',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
