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
// `onCadastrar`; o fluxo de cadastro entra em F3).
// T2.4 (este arquivo): A11y — `_TomadorRow` anunciada como radio de grupo
// mutuamente exclusivo (`MergeSemantics` + `Semantics` checked/selected) e
// foco automático no campo de busca ao abrir o sheet.
// T3.1 (este arquivo): modo cadastro inline (lista ↔ form, botão voltar) —
// `_CadastroTomadorForm` (CNPJ alfanum 14-pos → lookup, razão/município do
// backend, e-mail financeiro, valor padrão, retenções ISS/IRRF). Lookup
// (T3.2) e persistência (T3.3) chegam via callbacks `onResolverCnpj` /
// `onSalvarTomador` — o widget não faz HTTP nem regra de negócio. Decisão F3:
// body do cadastro NÃO envia endereço fiscal (backend deriva do CNPJ;
// `enderecoFiscal` é null para tomador CNPJ recorrente) nem `aliquotaIrrf`
// (1,5% legal default no backend).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// [selecionadoId] marca a linha já selecionada.
///
/// Cadastro de tomador:
/// - [onResolverCnpj] + [onSalvarTomador] (ambos) habilitam o **cadastro
///   inline** (T3.1): a CTA "Cadastrar" alterna o sheet para o formulário, e
///   o salvar bem-sucedido resolve o sheet com o tomador persistido
///   (auto-seleção). O widget só chama esses callbacks — lookup (T3.2) e POST
///   (T3.3) vivem nos providers.
/// - [onCadastrar] (legado, Ramo B1): sem os callbacks inline, a CTA apenas
///   dispara este `VoidCallback` (ex.: navegar para tela de cadastro).
Future<Tomador?> showTomadorSelectorSheet({
  required BuildContext context,
  required List<Tomador> tomadores,
  String? selecionadoId,
  VoidCallback? onCadastrar,
  Future<Tomador?> Function(String cnpj)? onResolverCnpj,
  Future<Tomador?> Function(Tomador tomador)? onSalvarTomador,
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
      onResolverCnpj: onResolverCnpj,
      onSalvarTomador: onSalvarTomador,
    ),
  );
}

/// Corpo do sheet: mantém o estado da busca e devolve o tomador escolhido.
class _TomadorSelectorSheet extends StatefulWidget {
  final List<Tomador> tomadores;
  final String? selecionadoId;
  final VoidCallback? onCadastrar;
  final Future<Tomador?> Function(String cnpj)? onResolverCnpj;
  final Future<Tomador?> Function(Tomador tomador)? onSalvarTomador;

  const _TomadorSelectorSheet({
    required this.tomadores,
    required this.selecionadoId,
    required this.onCadastrar,
    required this.onResolverCnpj,
    required this.onSalvarTomador,
  });

  @override
  State<_TomadorSelectorSheet> createState() => _TomadorSelectorSheetState();
}

class _TomadorSelectorSheetState extends State<_TomadorSelectorSheet> {
  final TextEditingController _buscaController = TextEditingController();
  String _query = '';

  /// Alterna entre a lista (seleção) e o formulário de cadastro inline (T3.1).
  bool _modoCadastro = false;

  /// Cadastro inline disponível só quando o chamador fornece lookup + persist.
  bool get _podeCadastrarInline =>
      widget.onResolverCnpj != null && widget.onSalvarTomador != null;

  /// Ação da CTA "Cadastrar": entra no form inline quando possível; senão cai
  /// no gancho legado [widget.onCadastrar] (Ramo B1). `null` esconde a CTA.
  VoidCallback? get _acaoCadastrar {
    if (_podeCadastrarInline) {
      return () => setState(() => _modoCadastro = true);
    }
    return widget.onCadastrar;
  }

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
              _SheetHead(
                titulo: _modoCadastro ? 'Cadastrar tomador' : 'Selecionar tomador',
                onClose: () => Navigator.of(context).pop(),
                onVoltar:
                    _modoCadastro ? () => setState(() => _modoCadastro = false) : null,
              ),
              if (_modoCadastro)
                Flexible(
                  child: _CadastroTomadorForm(
                    onResolverCnpj: widget.onResolverCnpj!,
                    onSalvarTomador: widget.onSalvarTomador!,
                    onSalvo: (t) => Navigator.of(context).pop(t),
                  ),
                )
              else if (semTomadores)
                Flexible(child: _SheetEmptyTotal(onCadastrar: _acaoCadastrar))
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
                if (_acaoCadastrar != null)
                  _SheetFoot(onCadastrar: _acaoCadastrar!),
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

/// Cabeçalho do sheet: título + botão fechar. Em modo cadastro, [onVoltar]
/// (não nulo) exibe uma seta de retorno à lista antes do título.
class _SheetHead extends StatelessWidget {
  final String titulo;
  final VoidCallback onClose;
  final VoidCallback? onVoltar;

  const _SheetHead({
    required this.titulo,
    required this.onClose,
    this.onVoltar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          if (onVoltar != null) ...[
            Semantics(
              button: true,
              label: 'Voltar para a lista',
              child: Material(
                color: AppColors.text.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  onTap: onVoltar,
                  borderRadius: BorderRadius.circular(9),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 14, color: AppColors.textDim),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              titulo,
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
        // A11y (T2.4): foco automático ao abrir o sheet — leitor de tela e
        // teclado vão direto à busca, sem toque extra (espelha v15).
        autofocus: true,
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
    // A11y (T2.4): leitor de tela anuncia a linha como radio de grupo
    // mutuamente exclusivo, com estado selecionado/não. `MergeSemantics`
    // funde razão/CNPJ/tags num único nó focável (o `_RadioCircle` é
    // decorativo — sem texto, não polui).
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selecionado,
        selected: selecionado,
        child: Material(
          color: selecionado
              ? AppColors.green.withValues(alpha: 0.06)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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

// ─── Cadastro inline (T3.1) ──────────────────────────────────────────────────

/// Formulário de cadastro de tomador CNPJ dentro do sheet.
///
/// Fluxo: digitar CNPJ (alfanumérico, 14 posições — DV não exigido no app,
/// jul/2026) → [onResolverCnpj] busca os dados no backend (T3.2) → exibe razão
/// social/município (somente leitura) + campos editáveis (e-mail financeiro,
/// valor padrão, retenções) → [onSalvarTomador] persiste (T3.3) e, em sucesso,
/// [onSalvo] devolve o tomador persistido (auto-seleção). O widget não faz HTTP
/// nem regra fiscal — só orquestra os callbacks (backend = verdade).
class _CadastroTomadorForm extends StatefulWidget {
  final Future<Tomador?> Function(String cnpj) onResolverCnpj;
  final Future<Tomador?> Function(Tomador tomador) onSalvarTomador;
  final ValueChanged<Tomador> onSalvo;

  const _CadastroTomadorForm({
    required this.onResolverCnpj,
    required this.onSalvarTomador,
    required this.onSalvo,
  });

  @override
  State<_CadastroTomadorForm> createState() => _CadastroTomadorFormState();
}

class _CadastroTomadorFormState extends State<_CadastroTomadorForm> {
  final TextEditingController _cnpjCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _valorCtrl = TextEditingController();
  final TextEditingController _aliquotaCtrl = TextEditingController();

  /// Dados resolvidos pelo lookup (razão/município/UF/IBGE). `null` antes da
  /// busca — o restante do form só aparece após resolver.
  Tomador? _resolvido;
  bool _buscando = false;
  bool _salvando = false;
  String? _erro;
  bool _retemIss = false;
  bool _retemIrrf = false;

  /// Espelha o texto do CNPJ para reavaliar o estado do botão "Buscar" a cada
  /// digitação (rebuild via setState).
  String _cnpj = '';

  String get _cnpjDigitado =>
      _cnpj.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

  bool get _cnpjCompleto => _cnpjDigitado.length == 14;

  @override
  void dispose() {
    _cnpjCtrl.dispose();
    _emailCtrl.dispose();
    _valorCtrl.dispose();
    _aliquotaCtrl.dispose();
    super.dispose();
  }

  bool _emailValido(String email) {
    if (email.isEmpty) return true;
    return RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    ).hasMatch(email);
  }

  Future<void> _buscar() async {
    if (_buscando || !_cnpjCompleto) return;
    setState(() {
      _buscando = true;
      _erro = null;
    });
    try {
      final t = await widget.onResolverCnpj(_cnpjDigitado);
      if (!mounted) return;
      setState(() {
        _buscando = false;
        if (t == null) {
          _resolvido = null;
          _erro = 'CNPJ não encontrado na Receita Federal.';
        } else {
          _resolvido = t;
          _retemIss = t.retemIss;
          _retemIrrf = t.retemIrrf;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _resolvido = null;
        _erro = 'Falha ao consultar o CNPJ. Tente novamente.';
      });
    }
  }

  Future<void> _salvar() async {
    final base = _resolvido;
    if (base == null || _salvando) return;

    final email = _emailCtrl.text.trim();
    if (!_emailValido(email)) {
      setState(() => _erro = 'E-mail do financeiro inválido.');
      return;
    }

    double aliquotaIss = 0.0;
    if (_retemIss) {
      aliquotaIss =
          double.tryParse(_aliquotaCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
      if (aliquotaIss < 0 || aliquotaIss > 10) {
        setState(() => _erro = 'Alíquota ISS deve estar entre 0,00% e 10,00%.');
        return;
      }
    }

    final valorPadrao =
        double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

    final tomador = base.copyWith(
      emailFinanceiro: email.isEmpty ? null : email,
      valorPadrao: valorPadrao,
      retemIss: _retemIss,
      aliquotaIss: _retemIss ? aliquotaIss : 0.0,
      retemIrrf: _retemIrrf,
    );

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final persistido = await widget.onSalvarTomador(tomador);
      if (!mounted) return;
      if (persistido == null) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível salvar o tomador. Tente novamente.';
        });
        return;
      }
      widget.onSalvo(persistido);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível salvar o tomador. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvido = _resolvido;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── CNPJ + buscar ────────────────────────────────────────────────
          const _CampoLabel('CNPJ do tomador'),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _cnpjCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
                    LengthLimitingTextInputFormatter(14),
                    _UpperCaseTextFormatter(),
                  ],
                  onChanged: (v) => setState(() => _cnpj = v),
                  onSubmitted: (_) => _buscar(),
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 14, color: AppColors.text, letterSpacing: 0.5),
                  cursorColor: AppColors.green,
                  decoration: _inputDec(hint: '00000000000000'),
                ),
              ),
              const SizedBox(width: 10),
              _BotaoBuscar(
                habilitado: _cnpjCompleto && !_buscando,
                carregando: _buscando,
                onTap: () {
                  _buscar();
                },
              ),
            ],
          ),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(
              _erro!,
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.red),
            ),
          ],

          // ── Dados resolvidos + campos editáveis ──────────────────────────
          if (resolvido != null) ...[
            const SizedBox(height: 16),
            _ResumoResolvido(tomador: resolvido),
            const SizedBox(height: 18),
            const _CampoLabel('E-mail do financeiro (opcional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              cursorColor: AppColors.green,
              decoration: _inputDec(hint: 'financeiro@hospital.com.br'),
            ),
            const SizedBox(height: 14),
            const _CampoLabel('Valor padrão do serviço (opcional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _valorCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style:
                  GoogleFonts.jetBrainsMono(fontSize: 14, color: AppColors.text),
              cursorColor: AppColors.green,
              decoration: _inputDec(hint: 'Ex: 2500,00'),
            ),
            const SizedBox(height: 18),
            const _CampoLabel('Retenção fiscal'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _FormToggle(
                    label: 'Retém ISS?',
                    value: _retemIss,
                    onChanged: (v) => setState(() => _retemIss = v),
                  ),
                  if (_retemIss) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _aliquotaCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 14, color: AppColors.text),
                      cursorColor: AppColors.green,
                      decoration: _inputDec(hint: 'Alíquota ISS (%) — ex: 2,00'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),
                  _FormToggle(
                    label: 'Retém IRRF?',
                    sublabel: 'Alíquota legal: 1,5%',
                    value: _retemIrrf,
                    onChanged: (v) => setState(() => _retemIrrf = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _BotaoSalvar(
              carregando: _salvando,
              onTap: () {
                _salvar();
              },
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDec({required String hint}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bg,
        hintText: hint,
        hintStyle: GoogleFonts.outfit(fontSize: 13, color: AppColors.textFaint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      );
}

/// Rótulo de campo do formulário de cadastro.
class _CampoLabel extends StatelessWidget {
  final String texto;

  const _CampoLabel(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textDim,
      ),
    );
  }
}

/// Botão "Buscar" do CNPJ (com estado de carregamento).
class _BotaoBuscar extends StatelessWidget {
  final bool habilitado;
  final bool carregando;
  final VoidCallback onTap;

  const _BotaoBuscar({
    required this.habilitado,
    required this.carregando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buscar CNPJ',
      enabled: habilitado,
      child: Material(
        color: habilitado
            ? AppColors.green.withValues(alpha: 0.12)
            : AppColors.text.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: habilitado ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 56),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: habilitado
                    ? AppColors.green.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: carregando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.green)),
                  )
                : Icon(
                    Icons.search,
                    size: 20,
                    color: habilitado ? AppColors.green : AppColors.textFaint,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Card somente-leitura com a razão social e o município retornados pelo
/// lookup (backend = verdade; o usuário não edita esses campos).
class _ResumoResolvido extends StatelessWidget {
  final Tomador tomador;

  const _ResumoResolvido({required this.tomador});

  @override
  Widget build(BuildContext context) {
    final local = [tomador.municipio, tomador.uf]
        .where((s) => s.isNotEmpty)
        .join('/');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          _Logo(sigla: _siglaFrom(tomador.razaoSocial), vazio: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tomador.razaoSocial,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  local.isEmpty
                      ? tomador.cnpj.formatCnpj()
                      : '${tomador.cnpj.formatCnpj()}  ·  $local',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de toggle (label + sublabel opcional + Switch) do form de cadastro.
class _FormToggle extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FormToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.text),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.textFaint),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.green,
          inactiveThumbColor: AppColors.textDim,
          inactiveTrackColor: AppColors.textDim.withValues(alpha: 0.2),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

/// CTA primário (verde) para concluir o cadastro do tomador.
class _BotaoSalvar extends StatelessWidget {
  final bool carregando;
  final VoidCallback onTap;

  const _BotaoSalvar({required this.carregando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Salvar tomador',
      child: Material(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: carregando ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            alignment: Alignment.center,
            child: carregando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.bg)),
                  )
                : Text(
                    'Salvar tomador',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Força caixa-alta na entrada (CNPJ alfanumérico jul/2026 usa letras
/// maiúsculas).
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      TextEditingValue(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      );
}
